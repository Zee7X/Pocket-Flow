-- =============================================================================
-- PocketFlow Migration: Next Level
-- =============================================================================
-- 1. pf_wallets               : dompet / rekening (GoPay, BCA, Tunai, ...)
-- 2. pf_transactions (alter)  : dompet, merchant, sumber, dedupe
-- 3. pf_wallet_balances       : view saldo per dompet
-- 4. pf_pending_transactions  : inbox "Perlu Ditinjau" hasil deteksi otomatis
-- 5. pf_merchant_rules        : kategori otomatis yang belajar dari koreksi
-- 6. pf_recurring_bills       : langganan & tagihan rutin
-- 7. pf_splits + participants : patungan / split bill
--
-- Semua tabel memakai RLS user_id = auth.uid(). Aman dijalankan ulang.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. pf_wallets
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_wallets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    kind            TEXT NOT NULL DEFAULT 'ewallet'
                    CHECK (kind IN ('cash', 'bank', 'ewallet', 'credit', 'paylater', 'other')),
    provider_key    TEXT,
    initial_balance BIGINT NOT NULL DEFAULT 0,
    color           TEXT,
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_wallets IS 'PocketFlow: Dompet/rekening pengguna';
COMMENT ON COLUMN public.pf_wallets.provider_key IS 'Kunci penyedia (gopay, ovo, dana, bca, ...) untuk mencocokkan notifikasi';

CREATE INDEX IF NOT EXISTS idx_pf_wallets_user ON public.pf_wallets (user_id, is_archived, sort_order);

DROP TRIGGER IF EXISTS pf_wallets_updated_at ON public.pf_wallets;
CREATE TRIGGER pf_wallets_updated_at
    BEFORE UPDATE ON public.pf_wallets
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

-- -----------------------------------------------------------------------------
-- 2. pf_transactions: kolom tambahan
-- -----------------------------------------------------------------------------
ALTER TABLE public.pf_transactions
    ADD COLUMN IF NOT EXISTS wallet_id      UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS to_wallet_id   UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS merchant       TEXT,
    ADD COLUMN IF NOT EXISTS source         TEXT NOT NULL DEFAULT 'manual',
    ADD COLUMN IF NOT EXISTS external_ref   TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'pf_transactions_source_check'
    ) THEN
        ALTER TABLE public.pf_transactions
            ADD CONSTRAINT pf_transactions_source_check
            CHECK (source IN ('manual', 'notification', 'ocr', 'shortcut', 'paste', 'ai', 'import', 'recurring', 'split', 'offline'));
    END IF;
END $$;

COMMENT ON COLUMN public.pf_transactions.external_ref IS 'Hash dedupe dari sumber otomatis (notifikasi/OCR). Unik per user.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pf_transactions_user_external_ref
    ON public.pf_transactions (user_id, external_ref)
    WHERE external_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pf_transactions_wallet ON public.pf_transactions (wallet_id);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_to_wallet ON public.pf_transactions (to_wallet_id);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_user_merchant ON public.pf_transactions (user_id, merchant);

-- -----------------------------------------------------------------------------
-- 3. View saldo dompet
-- income  : + ke wallet_id
-- expense : - dari wallet_id
-- transfer: - dari wallet_id, + ke to_wallet_id
-- Hanya transaksi sampai hari ini (transaksi terjadwal belum mengurangi saldo).
-- security_invoker = true supaya RLS tabel dasar tetap berlaku.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.pf_wallet_balances
WITH (security_invoker = true) AS
SELECT
    w.id AS wallet_id,
    w.user_id,
    w.initial_balance
      + COALESCE((
          SELECT SUM(
              CASE
                  WHEN t.type = 'income'   AND t.wallet_id = w.id    THEN t.amount
                  WHEN t.type = 'expense'  AND t.wallet_id = w.id    THEN -t.amount
                  WHEN t.type = 'transfer' AND t.wallet_id = w.id    THEN -t.amount
                  WHEN t.type = 'transfer' AND t.to_wallet_id = w.id THEN t.amount
                  ELSE 0
              END)
          FROM public.pf_transactions t
          WHERE (t.wallet_id = w.id OR t.to_wallet_id = w.id)
            AND t.transaction_date <= CURRENT_DATE
      ), 0) AS balance
FROM public.pf_wallets w;

-- -----------------------------------------------------------------------------
-- 4. pf_pending_transactions (inbox "Perlu Ditinjau")
-- Teks asli notifikasi TIDAK disimpan; hanya hasil parsing.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_pending_transactions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    source                TEXT NOT NULL
                          CHECK (source IN ('notification', 'ocr', 'shortcut', 'paste', 'ai')),
    source_app            TEXT,
    provider_key          TEXT,
    type                  TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    amount                BIGINT NOT NULL CHECK (amount > 0),
    merchant              TEXT,
    occurred_at           TIMESTAMPTZ NOT NULL,
    suggested_category_id UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    suggested_wallet_id   UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    to_wallet_id          UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    confidence            NUMERIC(3,2) NOT NULL DEFAULT 0.5,
    dedupe_hash           TEXT NOT NULL,
    status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'confirmed', 'dismissed')),
    transaction_id        UUID REFERENCES public.pf_transactions(id) ON DELETE SET NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, dedupe_hash)
);

COMMENT ON TABLE public.pf_pending_transactions IS 'PocketFlow: Transaksi terdeteksi otomatis yang menunggu konfirmasi';

CREATE INDEX IF NOT EXISTS idx_pf_pending_user_status
    ON public.pf_pending_transactions (user_id, status, occurred_at DESC);

DROP TRIGGER IF EXISTS pf_pending_transactions_updated_at ON public.pf_pending_transactions;
CREATE TRIGGER pf_pending_transactions_updated_at
    BEFORE UPDATE ON public.pf_pending_transactions
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

-- -----------------------------------------------------------------------------
-- 5. pf_merchant_rules (kategori otomatis yang belajar)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_merchant_rules (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    merchant_key TEXT NOT NULL,
    category_id  UUID REFERENCES public.pf_categories(id) ON DELETE CASCADE,
    wallet_id    UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    hits         INT NOT NULL DEFAULT 1,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, merchant_key)
);

COMMENT ON TABLE public.pf_merchant_rules IS 'PocketFlow: Merchant -> kategori, dipelajari dari koreksi pengguna';

DROP TRIGGER IF EXISTS pf_merchant_rules_updated_at ON public.pf_merchant_rules;
CREATE TRIGGER pf_merchant_rules_updated_at
    BEFORE UPDATE ON public.pf_merchant_rules
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

-- -----------------------------------------------------------------------------
-- 6. pf_recurring_bills (langganan & tagihan rutin)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_recurring_bills (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    amount             BIGINT NOT NULL CHECK (amount > 0),
    category_id        UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    wallet_id          UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    debt_id            UUID REFERENCES public.pf_debts(id) ON DELETE SET NULL,
    cadence            TEXT NOT NULL DEFAULT 'monthly'
                       CHECK (cadence IN ('weekly', 'monthly', 'yearly')),
    next_due_date      DATE NOT NULL,
    remind_days_before SMALLINT NOT NULL DEFAULT 2 CHECK (remind_days_before BETWEEN 0 AND 14),
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    merchant_key       TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_recurring_bills IS 'PocketFlow: Langganan, tagihan, dan cicilan rutin';

CREATE INDEX IF NOT EXISTS idx_pf_recurring_bills_user_due
    ON public.pf_recurring_bills (user_id, is_active, next_due_date);

DROP TRIGGER IF EXISTS pf_recurring_bills_updated_at ON public.pf_recurring_bills;
CREATE TRIGGER pf_recurring_bills_updated_at
    BEFORE UPDATE ON public.pf_recurring_bills
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

-- -----------------------------------------------------------------------------
-- 7. pf_splits + pf_split_participants (patungan)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_splits (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title          TEXT NOT NULL,
    total_amount   BIGINT NOT NULL CHECK (total_amount > 0),
    my_share       BIGINT NOT NULL DEFAULT 0 CHECK (my_share >= 0),
    split_date     DATE NOT NULL,
    wallet_id      UUID REFERENCES public.pf_wallets(id) ON DELETE SET NULL,
    category_id    UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    transaction_id UUID REFERENCES public.pf_transactions(id) ON DELETE SET NULL,
    note           TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pf_split_participants (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    split_id                UUID NOT NULL REFERENCES public.pf_splits(id) ON DELETE CASCADE,
    name                    TEXT NOT NULL,
    share_amount            BIGINT NOT NULL CHECK (share_amount > 0),
    is_settled              BOOLEAN NOT NULL DEFAULT FALSE,
    settled_at              TIMESTAMPTZ,
    settled_transaction_id  UUID REFERENCES public.pf_transactions(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_splits IS 'PocketFlow: Tagihan patungan yang ditalangi pengguna';
COMMENT ON TABLE public.pf_split_participants IS 'PocketFlow: Piutang per teman dalam patungan';

CREATE INDEX IF NOT EXISTS idx_pf_splits_user_date ON public.pf_splits (user_id, split_date DESC);
CREATE INDEX IF NOT EXISTS idx_pf_split_participants_split ON public.pf_split_participants (split_id);

DROP TRIGGER IF EXISTS pf_splits_updated_at ON public.pf_splits;
CREATE TRIGGER pf_splits_updated_at
    BEFORE UPDATE ON public.pf_splits
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'pf_wallets', 'pf_pending_transactions', 'pf_merchant_rules',
        'pf_recurring_bills', 'pf_splits', 'pf_split_participants'
    ] LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
        EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (user_id = auth.uid())',
                       t || '_select_own', t);

        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_insert_own', t);
        EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (user_id = auth.uid())',
                       t || '_insert_own', t);

        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_update_own', t);
        EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid())',
                       t || '_update_own', t);

        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_delete_own', t);
        EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE USING (user_id = auth.uid())',
                       t || '_delete_own', t);
    END LOOP;
END $$;

GRANT SELECT ON public.pf_wallet_balances TO authenticated;
