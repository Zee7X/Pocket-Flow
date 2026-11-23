// supabase/functions/ai-parse/index.ts
//
// Edge Function: ubah teks bebas / teks struk / foto struk menjadi daftar
// transaksi terstruktur memakai Gemini API (free tier Google AI Studio).
//
// Kunci API disimpan sebagai secret di Supabase, TIDAK di aplikasi:
//   supabase secrets set GEMINI_API_KEY=xxxx
//   supabase secrets set GEMINI_MODEL=gemini-3.5-flash-lite   (opsional)
//   supabase functions deploy ai-parse
//
// Fungsi ini hanya bisa dipanggil pengguna yang login (JWT Supabase
// diverifikasi otomatis oleh platform, verify_jwt = true).

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const MAX_TEXT = 6000;
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Mode = "text" | "receipt_text" | "receipt_image";

interface NamedRef {
  id: string;
  name: string;
  type?: string;
}

interface RequestBody {
  mode: Mode;
  text?: string;
  image_base64?: string;
  mime_type?: string;
  categories?: NamedRef[];
  wallets?: NamedRef[];
  today?: string;
}

const responseSchema = {
  type: "OBJECT",
  properties: {
    transactions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          type: { type: "STRING", enum: ["expense", "income", "transfer"] },
          amount: { type: "INTEGER" },
          merchant: { type: "STRING", nullable: true },
          note: { type: "STRING", nullable: true },
          category_id: { type: "STRING", nullable: true },
          wallet_id: { type: "STRING", nullable: true },
          to_wallet_id: { type: "STRING", nullable: true },
          date: { type: "STRING", description: "YYYY-MM-DD" },
        },
        required: ["type", "amount", "date"],
      },
    },
  },
  required: ["transactions"],
};

function buildPrompt(body: RequestBody): string {
  const cats = (body.categories ?? [])
    .slice(0, 80)
    .map((c) => `- ${c.id} | ${c.name} | ${c.type ?? "expense"}`)
    .join("\n");
  const wallets = (body.wallets ?? [])
    .slice(0, 40)
    .map((w) => `- ${w.id} | ${w.name}`)
    .join("\n");
  const today = body.today ?? new Date().toISOString().slice(0, 10);

  const task = body.mode === "text"
    ? `Ekstrak SEMUA transaksi dari catatan pengguna berikut (bisa lebih dari satu). Catatan bisa berupa ketikan atau hasil suara, bahasa Indonesia informal (contoh: "25rb" = 25000, "1,5jt" = 1500000, "kemarin" = sehari sebelum hari ini).`
    : `Ini struk belanja. Ambil SATU transaksi pengeluaran dengan nominal TOTAL AKHIR yang dibayar (bukan subtotal, bukan uang tunai, bukan kembalian). merchant = nama toko. note = ringkasan singkat isi belanja (maks 6 kata).`;

  return `${task}

Hari ini: ${today}. Mata uang: Rupiah, amount berupa bilangan bulat tanpa desimal.
Aturan:
- type: "expense" (uang keluar), "income" (uang masuk), "transfer" (pindah antar dompet milik sendiri, mis. top up e-wallet dari rekening sendiri).
- category_id: pilih id dari daftar kategori yang tipenya cocok, atau null bila tidak yakin. Jangan mengarang id.
- wallet_id: dompet sumber (expense/transfer) atau tujuan (income) dari daftar dompet bila disebut, selain itu null.
- to_wallet_id: hanya untuk transfer.
- Abaikan teks yang bukan transaksi.

Kategori (id | nama | tipe):
${cats || "- (belum ada)"}

Dompet (id | nama):
${wallets || "- (belum ada)"}`;
}

function jwtRole(req: Request): string | null {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    return typeof payload.role === "string" ? payload.role : null;
  } catch {
    return null;
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!GEMINI_API_KEY) return json({ error: "ai_not_configured" }, 503);

  // verify_jwt memastikan token sah; di sini kita tolak anon key supaya
  // kuota AI hanya dipakai pengguna yang sudah login.
  if (jwtRole(req) !== "authenticated") return json({ error: "login_required" }, 401);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (!["text", "receipt_text", "receipt_image"].includes(body.mode)) {
    return json({ error: "invalid_mode" }, 400);
  }

  const parts: unknown[] = [{ text: buildPrompt(body) }];
  if (body.mode === "receipt_image") {
    const b64 = body.image_base64 ?? "";
    if (!b64 || b64.length * 0.75 > MAX_IMAGE_BYTES) {
      return json({ error: "invalid_image" }, 400);
    }
    const mime = body.mime_type ?? "image/jpeg";
    if (!/^image\/(jpeg|png|webp|heic)$/.test(mime)) {
      return json({ error: "invalid_mime" }, 400);
    }
    parts.push({ inline_data: { mime_type: mime, data: b64 } });
  } else {
    const text = (body.text ?? "").slice(0, MAX_TEXT).trim();
    if (!text) return json({ error: "empty_text" }, 400);
    parts.push({ text: `\n---\n${text}\n---` });
  }

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API_KEY,
    },
    body: JSON.stringify({
      contents: [{ role: "user", parts }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
        responseSchema,
      },
    }),
  });

  if (res.status === 429) return json({ error: "rate_limited" }, 429);
  if (!res.ok) {
    console.error("gemini error", res.status, await res.text());
    return json({ error: "ai_failed" }, 502);
  }

  const data = await res.json();
  const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: { transactions?: Record<string, unknown>[] };
  try {
    parsed = JSON.parse(raw);
  } catch {
    return json({ error: "ai_bad_output" }, 502);
  }

  // Validasi ulang keluaran model sebelum dikirim ke aplikasi.
  const catIds = new Set((body.categories ?? []).map((c) => c.id));
  const walletIds = new Set((body.wallets ?? []).map((w) => w.id));
  const pick = (v: unknown, allowed: Set<string>) =>
    typeof v === "string" && allowed.has(v) ? v : null;

  const transactions = (parsed.transactions ?? [])
    .filter((t) => Number.isFinite(Number(t.amount)) && Number(t.amount) > 0)
    .slice(0, 20)
    .map((t) => ({
      type: ["expense", "income", "transfer"].includes(String(t.type))
        ? String(t.type)
        : "expense",
      amount: Math.round(Number(t.amount)),
      merchant: typeof t.merchant === "string" ? t.merchant.slice(0, 80) : null,
      note: typeof t.note === "string" ? t.note.slice(0, 120) : null,
      category_id: pick(t.category_id, catIds),
      wallet_id: pick(t.wallet_id, walletIds),
      to_wallet_id: pick(t.to_wallet_id, walletIds),
      date: /^\d{4}-\d{2}-\d{2}$/.test(String(t.date))
        ? String(t.date)
        : (body.today ?? new Date().toISOString().slice(0, 10)),
    }));

  return json({ transactions, model: GEMINI_MODEL });
});
