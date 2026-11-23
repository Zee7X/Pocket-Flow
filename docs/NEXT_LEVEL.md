# PocketFlow Next Level: Panduan Setup

Dokumen ini menjelaskan fitur baru dan langkah untuk menyambungkannya ke
Supabase milikmu. Semua langkah bisa dilakukan dari dashboard Supabase di
browser, tanpa Supabase CLI.

## Isi rilis

| Fitur | Android | iOS | Web |
|---|---|---|---|
| Deteksi transaksi dari notifikasi (GoPay, OVO, DANA, ShopeePay, bank, SMS bank) | Otomatis | Tidak bisa (dibatasi iOS) | – |
| Tempel teks notifikasi / SMS | Ya | Ya | Ya |
| Deep link Shortcuts / Tasker `pocketflow://app/capture?...` | Ya | Ya | – |
| Catat pintar: ketik bebas, suara, scan struk (AI) | Ya | Ya | Ya (struk dikirim ke AI) |
| Import Money Manager, Money Lover, Wallet, CSV/XLSX | Ya | Ya | Ya |
| Kategori otomatis yang belajar | Ya | Ya | Ya |
| Peringatan budget 80% / 100% | Notifikasi + snackbar | Notifikasi + snackbar | Snackbar |
| Sisa aman hari ini + widget layar utama | Widget Android | Di dashboard (widget iOS belum) | Dashboard |
| Multi-dompet & transfer antar dompet | Ya | Ya | Ya |
| Langganan & tagihan rutin + pengingat + deteksi otomatis | Ya | Ya | Tanpa pengingat |
| Scan struk OCR di perangkat (ML Kit) | Ya | Ya | – |
| Insight bulanan | Ya | Ya | Ya |
| Patungan / split bill | Ya | Ya | Ya |
| Offline: antrean transaksi + cache daftar | Ya | Ya | Ya |

## 1. Jalankan migrasi database (wajib)

Fitur baru memakai tabel dan kolom baru. Tanpa migrasi, menyimpan transaksi
akan gagal karena kolom `wallet_id`, `merchant`, dan lainnya belum ada.

1. Buka <https://supabase.com/dashboard> → pilih project PocketFlow.
2. Menu **SQL Editor** → **New query**.
3. Salin seluruh isi `supabase/migrations/20261123000001_pf_next_level.sql`,
   tempel, lalu **Run**.
4. Cek di **Table Editor**: harus ada `pf_wallets`, `pf_pending_transactions`,
   `pf_merchant_rules`, `pf_recurring_bills`, `pf_splits`,
   `pf_split_participants`, dan view `pf_wallet_balances`.

Migrasi ini aman dijalankan ulang (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`)
dan tidak mengubah atau menghapus data lama. Semua tabel baru memakai RLS
`user_id = auth.uid()`.

Bila memakai Supabase CLI: `supabase db push`.

## 2. Aktifkan AI gratis (opsional, disarankan)

AI memakai **Gemini API free tier** dari Google AI Studio. Kunci API disimpan
di server Supabase (Edge Function), tidak pernah ada di aplikasi.

Tanpa langkah ini, Catat Pintar tetap jalan memakai pembaca lokal (aturan
bahasa Indonesia seperti "25rb", "1,5jt", "kemarin", "pakai gopay"). AI
menambah ketepatan untuk kalimat bebas dan foto struk.

1. Buat API key gratis di <https://aistudio.google.com/apikey> (cukup akun
   Google, tanpa kartu kredit).
2. Dashboard Supabase → **Edge Functions** → **Deploy a new function** →
   **Via Editor**. Nama: `ai-parse`. Tempel isi
   `supabase/functions/ai-parse/index.ts` → **Deploy**.
3. **Edge Functions → Secrets** → tambah:
   - `GEMINI_API_KEY` = key dari langkah 1
   - `GEMINI_MODEL` = `gemini-3.5-flash-lite` (opsional; ini nilai default)
4. Pastikan **Verify JWT** untuk fungsi ini aktif (default), supaya hanya
   pengguna yang login yang bisa memakainya.

Dengan CLI:

```bash
supabase functions deploy ai-parse
supabase secrets set GEMINI_API_KEY=xxxx
```

Batas free tier dihitung per project Google, bukan per pengguna aplikasi.
Bila kuota harian habis, aplikasi otomatis kembali ke pembaca lokal dan
menampilkan pesan "Kuota AI gratis hari ini habis".

Suara diubah ke teks di perangkat (speech-to-text bawaan Android/iOS/Chrome),
jadi tidak memakai kuota AI. Struk di Android/iOS dibaca dulu dengan OCR ML
Kit di perangkat; yang dikirim ke AI hanya teksnya. Di web, foto struk
dikirim langsung ke AI.

## 3. Jalankan aplikasi

Butuh Flutter **3.38** (Dart 3.10) atau lebih baru.

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

### Mode preview tanpa Supabase

Untuk melihat tampilan dengan data contoh, tanpa login dan tanpa backend:

```bash
flutter run -d chrome -t lib/demo/demo_main.dart
```

Data contoh hanya ada di memori. AI di mode ini selalu memakai pembaca lokal.

## 4. Deteksi notifikasi di Android

1. Buka **Lainnya → Deteksi dari notifikasi → Aktifkan deteksi**.
2. Baca penjelasan izin, lalu aktifkan **PocketFlow** di halaman
   *Akses notifikasi* Android.
3. Di Xiaomi, Oppo, Vivo, Realme, Huawei: matikan optimasi baterai untuk
   PocketFlow dan aktifkan *Autostart*. Tombolnya ada di halaman yang sama.

Cara kerja dan dampak baterai:

- `PaymentNotificationListener` (Kotlin) dipanggil Android hanya saat ada
  notifikasi baru. Tidak ada polling atau service yang berjalan terus.
- Layanan cuma memeriksa nama paket dan memastikan teks memuat "Rp", lalu
  menyimpan teksnya ke antrean lokal. Mesin Flutter tidak dinyalakan.
- Saat aplikasi dibuka, Dart membaca antrean, mem-parsing, menghapus teks
  mentah, dan hanya menyimpan hasilnya (nominal, merchant, waktu, aplikasi
  asal) ke tabel `pf_pending_transactions`.
- Promo, OTP, transaksi gagal, dan SMS dari nomor pribadi diabaikan.
- Top up dari bank ke e-wallet (dua notifikasi) digabung jadi satu transfer
  antar dompet, bukan pengeluaran + pemasukan.

Pengaturan **Catat otomatis tanpa ditinjau** (default mati) langsung
menyimpan transaksi dari merchant yang kategorinya sudah pernah kamu
tentukan. Sisanya tetap masuk **Perlu Ditinjau**.

**Penting sebelum rilis Play Store:** Google Play meminta *prominent
disclosure* sebelum izin akses notifikasi diminta (sudah ada di aplikasi)
dan penjelasan penggunaan data di formulir Data Safety. Parser juga perlu
dicoba dengan notifikasi asli dari HP kamu; contoh di
`test/unit/notification_parser_test.dart` disusun dari format umum, belum dari
notifikasi asli setiap aplikasi.

## 5. iPhone

iOS tidak mengizinkan aplikasi membaca notifikasi aplikasi lain. Alternatif
yang tersedia:

- **Scan struk / screenshot bukti bayar** (tombol + → Scan struk).
- **Tempel teks** notifikasi di halaman Perlu Ditinjau.
- **Shortcuts**: buat Personal Automation (mis. pemicu *Transaction* untuk
  Apple Pay) dengan aksi *Open URL*:
  `pocketflow://app/capture?amount=25000&merchant=Kopi&type=expense&wallet=gopay`

Catatan build iOS: deployment target dinaikkan ke iOS 15.5 karena Google ML
Kit. Jalankan `cd ios && pod install` setelah `flutter pub get`. ML Kit belum
mendukung simulator Apple Silicon, jadi uji di iPhone asli. Widget layar utama
iOS dan Share Extension butuh target baru di Xcode dan belum dibuat.

## 6. Import dari aplikasi lain

**Lainnya → Import dari aplikasi lain**, lalu pilih file:

- **Money Manager (Realbyte)**: More → Backup → Export data to Excel (.xlsx).
  Transfer antar akun diimpor sebagai transfer (sisi Transfer-In dilewati).
- **Money Lover**: Tools → Export CSV (pemisah koma, titik koma, atau tab).
  Nominal negatif dibaca sebagai pengeluaran.
- **Wallet by BudgetBakers / lainnya**: CSV atau XLSX dengan kolom tanggal
  dan nominal. Kolom lain bisa dipetakan manual.

Kategori dan dompet dari file bisa dipetakan ke yang sudah ada atau dibuat
otomatis. Import aman diulang: setiap baris punya `external_ref` unik
sehingga baris yang sudah pernah masuk dilewati. File `.xls` lama perlu
disimpan ulang sebagai `.xlsx` atau `.csv`.

## Perubahan perilaku yang perlu diketahui

- Dashboard tidak lagi memanggil `cleanupPhantomSavingsAndRecalibrate()` saat
  dibuka. Fungsi itu menghapus **semua** transaksi tabungan bernominal tepat
  Rp150.000 setiap kali dashboard dimuat. Sekarang dashboard hanya
  menyamakan `spent_amount` budget (`recalibrateRecentBudgets()`), tanpa
  menghapus data. Fungsi lama masih ada di repository bila memang
  dibutuhkan sekali jalan.
- Hapus transaksi cicilan sebelumnya membaca kolom `total_amount` dan
  `is_paid` yang tidak ada di `pf_debts` (sebenarnya `initial_amount` dan
  `status`), sehingga sisa utang tidak pernah dikembalikan dan semua
  pembayaran bernominal sama ikut terhapus. Sekarang hanya satu pembayaran
  dengan nominal dan tanggal yang sama yang dihapus, dan sisa utang
  dikembalikan dengan benar.
- Metode pembayaran kini benar-benar tersimpan (`payment_method`), diisi
  dari jenis dompet yang dipilih.
- Format ringkas rupiah memakai koma desimal: `Rp1,5jt`.
