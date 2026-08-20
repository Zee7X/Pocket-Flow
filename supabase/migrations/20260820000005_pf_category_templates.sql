-- =============================================================================
-- PocketFlow Migration 005: Category Templates (Seed Data)
-- =============================================================================
-- System onboarding templates. Structure only — NO hardcoded amounts.
-- All amounts, percentages = 0. Users fill real values during onboarding.
-- =============================================================================

-- Template 1: Basic Employee (Karyawan)
INSERT INTO public.pf_category_templates
    (template_key, template_name, item_name, item_icon, item_color, item_type, allocation_type, percentage_base, priority, is_required, is_spendable, sort_order, description)
VALUES
-- Priority 1: Mandatory fixed expenses
('basic_employee', 'Karyawan / Basic Employee', 'Tempat Tinggal',   '🏠', '#6366F1', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 1,  'Sewa kos / kost, kontrakan, atau cicilan rumah'),
('basic_employee', 'Karyawan / Basic Employee', 'Cicilan / Utang',  '💳', '#EF4444', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 2,  'Cicilan pinjaman, KPR, atau utang lainnya'),
('basic_employee', 'Karyawan / Basic Employee', 'Internet / WiFi',  '📡', '#3B82F6', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 3,  'Tagihan internet bulanan'),
-- Priority 2: Variable necessities
('basic_employee', 'Karyawan / Basic Employee', 'Transportasi',     '🚗', '#F59E0B', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  4,  'Bensin, transportasi umum, atau parkir'),
('basic_employee', 'Karyawan / Basic Employee', 'Makan',            '🍽️', '#10B981', 'expense', 'capped',     'remaining_income', 2,  TRUE,  TRUE,  5,  'Kebutuhan makan dan minum sehari-hari'),
('basic_employee', 'Karyawan / Basic Employee', 'Kebutuhan Pribadi','🧴', '#8B5CF6', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  6,  'Toiletries, kebutuhan personal lainnya'),
-- Priority 3: Emergency fund
('basic_employee', 'Karyawan / Basic Employee', 'Dana Darurat',     '🛡️', '#06B6D4', 'saving',  'percentage', 'remaining_income', 3,  FALSE, FALSE, 7,  'Dana cadangan untuk keadaan darurat'),
-- Priority 4: Savings
('basic_employee', 'Karyawan / Basic Employee', 'Tabungan',         '💰', '#84CC16', 'saving',  'percentage', 'remaining_income', 4,  FALSE, FALSE, 8,  'Tabungan jangka pendek atau panjang'),
-- Priority 5: Discretionary
('basic_employee', 'Karyawan / Basic Employee', 'Hiburan',          '🎮', '#F43F5E', 'expense', 'percentage', 'remaining_income', 5,  FALSE, TRUE,  9,  'Hiburan, hobi, fun money');

-- Template 2: Student (Mahasiswa)
INSERT INTO public.pf_category_templates
    (template_key, template_name, item_name, item_icon, item_color, item_type, allocation_type, percentage_base, priority, is_required, is_spendable, sort_order, description)
VALUES
('student', 'Mahasiswa / Student', 'Kos / Tempat Tinggal', '🏠', '#6366F1', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 1,  'Biaya kos atau tempat tinggal'),
('student', 'Mahasiswa / Student', 'Kuota / Internet',     '📱', '#3B82F6', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 2,  'Kuota internet atau WiFi'),
('student', 'Mahasiswa / Student', 'Makan',                '🍽️', '#10B981', 'expense', 'capped',     'remaining_income', 2,  TRUE,  TRUE,  3,  'Kebutuhan makan sehari-hari'),
('student', 'Mahasiswa / Student', 'Transportasi',         '🚌', '#F59E0B', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  4,  'Transportasi kuliah atau sehari-hari'),
('student', 'Mahasiswa / Student', 'Kebutuhan Kuliah',     '📚', '#8B5CF6', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  5,  'Buku, alat tulis, atau keperluan kuliah'),
('student', 'Mahasiswa / Student', 'Dana Darurat',         '🛡️', '#06B6D4', 'saving',  'percentage', 'remaining_income', 3,  FALSE, FALSE, 6,  'Dana cadangan darurat'),
('student', 'Mahasiswa / Student', 'Tabungan',             '💰', '#84CC16', 'saving',  'percentage', 'remaining_income', 4,  FALSE, FALSE, 7,  'Tabungan masa depan'),
('student', 'Mahasiswa / Student', 'Hiburan / Sosial',     '🎉', '#F43F5E', 'expense', 'percentage', 'remaining_income', 5,  FALSE, TRUE,  8,  'Nongkrong, hiburan, atau keperluan sosial');

-- Template 3: Freelancer
INSERT INTO public.pf_category_templates
    (template_key, template_name, item_name, item_icon, item_color, item_type, allocation_type, percentage_base, priority, is_required, is_spendable, sort_order, description)
VALUES
('freelancer', 'Freelancer', 'Tempat Tinggal',    '🏠', '#6366F1', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 1,  'Sewa atau cicilan tempat tinggal'),
('freelancer', 'Freelancer', 'Internet',           '📡', '#3B82F6', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 2,  'Koneksi internet untuk bekerja'),
('freelancer', 'Freelancer', 'Software / Tools',  '💻', '#8B5CF6', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 3,  'Langganan software atau tools kerja'),
('freelancer', 'Freelancer', 'Makan',              '🍽️', '#10B981', 'expense', 'capped',     'remaining_income', 2,  TRUE,  TRUE,  4,  'Kebutuhan makan sehari-hari'),
('freelancer', 'Freelancer', 'Transportasi',       '🚗', '#F59E0B', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  5,  'Transportasi dan mobilitas'),
('freelancer', 'Freelancer', 'Pajak / Admin',      '📋', '#EF4444', 'expense', 'percentage', 'total_income',     2,  FALSE, FALSE, 6,  'Estimasi pajak penghasilan atau biaya admin'),
('freelancer', 'Freelancer', 'Dana Darurat',       '🛡️', '#06B6D4', 'saving',  'percentage', 'remaining_income', 3,  FALSE, FALSE, 7,  'Dana cadangan (penting untuk freelancer)'),
('freelancer', 'Freelancer', 'Tabungan',           '💰', '#84CC16', 'saving',  'percentage', 'remaining_income', 4,  FALSE, FALSE, 8,  'Tabungan dan investasi'),
('freelancer', 'Freelancer', 'Hiburan',            '🎮', '#F43F5E', 'expense', 'percentage', 'remaining_income', 5,  FALSE, TRUE,  9,  'Hiburan dan kebutuhan personal');

-- Template 4: Family (Keluarga)
INSERT INTO public.pf_category_templates
    (template_key, template_name, item_name, item_icon, item_color, item_type, allocation_type, percentage_base, priority, is_required, is_spendable, sort_order, description)
VALUES
('family', 'Keluarga / Family', 'Cicilan Rumah / KPR',   '🏡', '#6366F1', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 1,  'Cicilan KPR atau sewa rumah keluarga'),
('family', 'Keluarga / Family', 'Tagihan Listrik / Air', '💡', '#F59E0B', 'expense', 'fixed',      'remaining_income', 1,  TRUE,  FALSE, 2,  'Tagihan listrik, air, dan utilitas'),
('family', 'Keluarga / Family', 'Internet',              '📡', '#3B82F6', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 3,  'Tagihan internet keluarga'),
('family', 'Keluarga / Family', 'Cicilan / Utang',       '💳', '#EF4444', 'expense', 'fixed',      'remaining_income', 1,  FALSE, FALSE, 4,  'Cicilan atau utang lainnya'),
('family', 'Keluarga / Family', 'Makan Keluarga',        '🍽️', '#10B981', 'expense', 'capped',     'remaining_income', 2,  TRUE,  TRUE,  5,  'Kebutuhan pangan seluruh keluarga'),
('family', 'Keluarga / Family', 'Transportasi',          '🚗', '#84CC16', 'expense', 'capped',     'remaining_income', 2,  FALSE, TRUE,  6,  'Bahan bakar dan transportasi keluarga'),
('family', 'Keluarga / Family', 'Pendidikan Anak',       '🎓', '#8B5CF6', 'expense', 'fixed',      'remaining_income', 2,  FALSE, FALSE, 7,  'SPP, les, atau biaya pendidikan anak'),
('family', 'Keluarga / Family', 'Kesehatan',             '⚕️', '#06B6D4', 'expense', 'capped',     'remaining_income', 2,  FALSE, FALSE, 8,  'Premi asuransi, obat, atau biaya kesehatan'),
('family', 'Keluarga / Family', 'Dana Darurat',          '🛡️', '#F43F5E', 'saving',  'percentage', 'remaining_income', 3,  FALSE, FALSE, 9,  'Dana cadangan keluarga'),
('family', 'Keluarga / Family', 'Tabungan',              '💰', '#84CC16', 'saving',  'percentage', 'remaining_income', 4,  FALSE, FALSE, 10, 'Tabungan keluarga dan masa depan'),
('family', 'Keluarga / Family', 'Hiburan Keluarga',      '🎪', '#F59E0B', 'expense', 'percentage', 'remaining_income', 5,  FALSE, TRUE,  11, 'Rekreasi dan hiburan bersama keluarga');
