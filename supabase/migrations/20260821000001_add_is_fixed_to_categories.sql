-- Migration: Add is_fixed column to pf_categories
-- is_fixed = true  → biaya tetap (kos, listrik, cicilan) — tidak perlu daily limit
-- is_fixed = false → biaya variabel (makan, transport) — tampil "maks hari ini"

ALTER TABLE pf_categories
  ADD COLUMN IF NOT EXISTS is_fixed BOOLEAN NOT NULL DEFAULT false;

-- Auto-mark well-known fixed-cost default categories
UPDATE pf_categories
SET is_fixed = true
WHERE is_default = true
  AND lower(name) IN (
    'sewa', 'kos', 'sewa kos', 'kontrakan',
    'listrik', 'air', 'pdam',
    'internet', 'wifi',
    'cicilan', 'kpr', 'kredit'
  );
