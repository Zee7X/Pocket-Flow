# Flexible Finance Planner — Project Plan

## 1. Project Overview

Personal Finance Planner adalah aplikasi mobile budgeting yang dapat digunakan banyak user untuk mengatur pemasukan yang nominalnya bisa berubah setiap bulan.

Aplikasi tidak hanya mencatat pengeluaran, tetapi membagi pemasukan otomatis ke beberapa pos berdasarkan kategori, prioritas, target, dan aturan yang dapat dikonfigurasi masing-masing user.

Contoh:

```text
Gaji masuk: Rp5.500.000

↓ Auto Allocation

Utang          Rp2.000.000
Kos              Rp850.000
WiFi             Rp170.000
Kuota             Rp40.000
Bensin           Rp100.000
Vape             Rp150.000
Toiletries       Rp100.000
Makan            Rp850.000
Dana Darurat     Rp620.000
Tabungan         Rp372.000
Fun Money        Rp248.000
```

Target utama aplikasi:

> Setiap menerima pemasukan, aplikasi membantu user menentukan: "Uang ini sebaiknya dibagi ke mana?" berdasarkan aturan milik user sendiri.

---

## 2. Main Goals

### MVP Goals

- Mendukung banyak user dengan konfigurasi keuangan masing-masing.
- Mencatat pemasukan bulanan yang nominalnya bisa berubah.
- Membagi pemasukan otomatis berdasarkan allocation rules milik masing-masing user.
- Semua kategori, nominal, persentase, prioritas, target, dan tipe alokasi dapat diedit user.
- Mencatat pemasukan dan pengeluaran.
- Menampilkan budget per kategori.
- Menghitung sisa budget.
- Menghitung safe spending per hari.
- Melacak utang.
- Melacak dana darurat.
- Melacak tabungan.
- Memberikan reminder lokal.
- Menampilkan dashboard kondisi keuangan bulan berjalan.

### Non-Goals untuk MVP

Belum perlu:

- Integrasi bank.
- OCR struk.
- AI assistant.
- Multi-user family finance.
- Payment gateway.
- Sinkronisasi e-wallet otomatis.
- Firebase Cloud Messaging.
- Web dashboard.
- Export PDF.
- Investment tracker.

Semua fitur tersebut bisa masuk fase berikutnya.

---


## 2.1 Product Principles

### Configuration over Hardcode

Semua aturan keuangan harus berasal dari database/configuration milik user.

Contoh yang **tidak boleh**:

```dart
const rent = 850000;
const food = 850000;
const emergencyPercent = 50;
```

Yang benar:

```text
Flutter
  ↓
Load user allocation rules
  ↓
Allocation Engine
  ↓
Generate budget
```

### Multi-User by Design

Walaupun versi awal mungkin digunakan sendiri, schema dan authorization harus sejak awal mendukung banyak user.

Setiap resource wajib terkait ke `user_id`.

### Template, Not Assumption

Aplikasi boleh memberikan template kategori supaya onboarding cepat, tetapi template hanya default dan harus bisa diubah sepenuhnya.

---

## 3. Tech Stack

### Mobile

- Flutter
- Dart
- Riverpod
- GoRouter
- Freezed / json_serializable jika diperlukan

### Backend

- Supabase
  - PostgreSQL
  - Supabase Auth
  - Row Level Security
  - RPC / PostgreSQL Functions
  - Edge Functions jika diperlukan

### Local Storage

Pilihan:

- Drift
- SQLite

Untuk MVP sederhana bisa mulai Supabase-first.

Jika offline-first menjadi kebutuhan penting, tambahkan Drift.

### Notification

MVP:

- `flutter_local_notifications`
- timezone package

Future:

- Firebase Cloud Messaging

### Optional Supporting Packages

```yaml
dependencies:
  flutter_riverpod:
  go_router:
  supabase_flutter:
  intl:
  flutter_local_notifications:
  timezone:
  uuid:
  freezed_annotation:
  json_annotation:
```

---

## 4. Suggested Architecture

```text
Flutter App
│
├── Presentation
│   ├── Pages
│   ├── Widgets
│   └── Riverpod Providers
│
├── Domain
│   ├── Entities
│   ├── Use Cases
│   └── Repository Interfaces
│
├── Data
│   ├── Supabase Data Sources
│   ├── Repository Implementations
│   └── Models
│
└── Supabase
    ├── Auth
    ├── PostgreSQL
    ├── RLS
    ├── RPC Functions
    └── Edge Functions
```

Untuk personal project, jangan terlalu memaksakan Clean Architecture penuh jika membuat development lambat.

Struktur feature-first lebih disarankan.

---

## 5. Flutter Folder Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
│
├── core/
│   ├── constants/
│   ├── database/
│   ├── extensions/
│   ├── notifications/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── dashboard/
│   ├── salary/
│   ├── allocation/
│   ├── transactions/
│   ├── budgets/
│   ├── categories/
│   ├── debts/
│   ├── emergency_fund/
│   ├── savings/
│   └── settings/
│
├── main.dart
└── bootstrap.dart
```

---

## 6. Core Features

### 6.1 Dashboard

Dashboard menjadi halaman utama.

Informasi yang ditampilkan:

```text
Agustus 2026

Gaji
Rp5.300.000

Sisa uang bulan ini
Rp1.240.000

Safe Spending Today
Rp41.333

Budget Makan
Rp420.000 / Rp850.000

Utang
Rp34.000.000 / Rp38.000.000

Dana Darurat
Rp1.200.000 / Rp3.000.000
```

Widget dashboard:

- Current balance
- Monthly salary
- Total expenses
- Remaining budget
- Safe spending today
- Debt progress
- Emergency fund progress
- Savings progress
- Recent transactions

---

## 7. Salary Flow

### User Flow

```text
Home
  ↓
Terima Gaji
  ↓
Input Rp5.300.000
  ↓
Preview Allocation
  ↓
Apply Budget
  ↓
Monthly Budget Created
```

Form:

```text
Salary Amount
[ Rp5.300.000 ]

Salary Date
[ 25 Aug 2026 ]

Period
[ August 2026 ]

[ Preview Allocation ]
```

---

## 8. Allocation Engine

Allocation engine merupakan fitur utama aplikasi.

### Rule Types

#### Fixed

Nominal selalu sama.

Contoh:

```text
Kos = Rp850.000
WiFi = Rp170.000
Utang = Rp2.000.000
```

#### Capped

Mendapat budget sampai nominal tertentu.

Contoh:

```text
Makan max Rp850.000
```

#### Percentage

Mengambil persentase dari uang yang tersisa.

Contoh:

```text
Dana Darurat = 50%
Tabungan = 30%
Fun Money = 20%
```

#### Remaining

Mendapat semua uang yang masih tersisa.

---

## 9. Allocation Priority

Contoh urutan:

```text
Priority 1
Kebutuhan wajib

↓
Priority 2
Kebutuhan hidup

↓
Priority 3
Dana darurat

↓
Priority 4
Tabungan

↓
Priority 5
Fun money
```

Contoh initial rules / template onboarding:

| Category | Type | Amount / Percentage | Priority |
|---|---|---:|---:|
| Tempat Tinggal | Fixed | user input | 1 |
| Cicilan / Utang | Fixed | user input | 1 |
| Internet | Fixed | user input | 1 |
| Transportasi | Capped / Fixed | user input | 2 |
| Makan | Capped | user input | 2 |
| Dana Darurat | Percentage | user input | 3 |
| Tabungan | Percentage | user input | 4 |
| Hiburan | Percentage | user input | 5 |

Semua nilai di atas hanya contoh template. User dapat:

- menambah kategori;
- menghapus kategori;
- mengubah nama kategori;
- mengubah icon;
- mengubah tipe alokasi;
- mengubah nominal;
- mengubah persentase;
- mengubah prioritas;
- mengaktifkan / menonaktifkan rule;
- menentukan maksimum / minimum alokasi;
- mengatur rule khusus untuk extra income.

---


## 9.1 User-Configurable Allocation Rules

Tidak ada kebutuhan yang boleh hardcoded di aplikasi.

Setiap user memiliki allocation rules sendiri.

Contoh:

```text
User A
Kos          Fixed       Rp850.000
Makan        Capped      Rp900.000
Darurat      Percentage  50%
Tabungan     Percentage  30%
Hiburan      Percentage  20%
```

User B bisa memiliki struktur yang sama sekali berbeda:

```text
User B
KPR          Fixed       Rp3.500.000
Orang Tua    Fixed       Rp1.000.000
Transport    Capped      Rp600.000
Investasi    Percentage  40%
Darurat      Percentage  40%
Hiburan      Percentage  20%
```

UI edit rule minimal:

```text
Rule Name
[ Makan ]

Allocation Type
[ Capped ▼ ]

Amount
[ Rp900.000 ]

Priority
[ 2 ]

Minimum Amount
[ optional ]

Maximum Amount
[ optional ]

[✓] Required
[✓] Active

[ Save ]
```

Untuk percentage:

```text
Rule Name
[ Dana Darurat ]

Allocation Type
[ Percentage ▼ ]

Percentage
[ 40 % ]

Calculated From
[ Remaining Income ▼ ]

Priority
[ 3 ]
```

Persentase tidak harus selalu dihitung dari total pemasukan.

Pilihan basis persentase:

```text
total_income
remaining_income
extra_income
custom_base
```

Contoh:

```text
Dana Darurat
40% dari remaining_income
```

atau:

```text
Sedekah
2.5% dari total_income
```

atau:

```text
Investasi
50% dari extra_income
```

### Validation

Allocation engine harus melakukan validasi:

- total percentage pada scope yang sama tidak melebihi 100%, kecuali mode proportional scaling diaktifkan;
- fixed allocation tidak boleh bernilai negatif;
- maximum amount tidak boleh lebih kecil dari minimum amount;
- priority harus valid;
- rule inactive tidak ikut dihitung;
- user dapat menerima warning jika total kebutuhan melebihi pemasukan.

## 10. Extra Salary Rule

Baseline income ditentukan masing-masing user.

Contoh:

```text
User A baseline income = Rp5.000.000
User B baseline income = Rp8.000.000
```

Baseline bersifat opsional dan editable.

Jika gaji lebih tinggi:

```text
Actual Salary
-
Baseline Salary
=
Extra Salary
```

Contoh:

```text
Rp5.500.000
-
Rp5.000.000
=
Rp500.000 extra
```

Optional allocation:

```text
60% Extra Debt Payment
30% Savings
10% Fun Money
```

Contoh:

```text
Rp500.000

Rp300.000 → Extra Debt
Rp150.000 → Savings
Rp50.000  → Fun Money
```

Fitur ini bisa dibuat configurable.

---

## 11. Safe Spending Today

Formula dasar:

```text
Remaining Spendable Budget
──────────────────────────
Remaining Days Until Salary
```

Contoh:

```text
Rp840.000
─────────
21 hari

= Rp40.000 / hari
```

Yang termasuk spendable:

- makan
- fun money
- optional daily expenses

Yang tidak termasuk:

- kos
- cicilan utang
- tabungan
- dana darurat
- tagihan fixed

---

## 12. Database Design

### profiles

```text
id
name
default_salary
salary_day
currency
created_at
updated_at
```

---

### categories

```text
id
user_id
name
icon
type
is_required
is_active
created_at
```

Type:

```text
income
expense
saving
debt
```

---


### user_finance_settings

```text
id
user_id
currency
salary_day
baseline_income
default_emergency_target
extra_income_strategy
allow_overallocation
created_at
updated_at
```

Semua nilai bersifat per-user dan editable.

---

### salary_entries

```text
id
user_id
amount
salary_date
period_month
period_year
created_at
```

---

### allocation_rules

```text
id
user_id
category_id
name
allocation_type
fixed_amount
percentage
percentage_base
min_amount
max_amount
priority
is_required
is_active
metadata
created_at
updated_at
```

Possible `allocation_type`:

```text
fixed
percentage
capped
remaining
proportional
```

Possible `percentage_base`:

```text
total_income
remaining_income
extra_income
custom_base
```

`metadata` dapat digunakan untuk rule tambahan tanpa harus sering mengubah schema.

---

### monthly_budgets

```text
id
user_id
category_id
salary_entry_id
period_month
period_year
allocated_amount
spent_amount
created_at
updated_at
```

---

### transactions

```text
id
user_id
category_id
monthly_budget_id
type
amount
note
transaction_date
created_at
updated_at
```

Type:

```text
income
expense
transfer
```

---

### debts

```text
id
user_id
name
initial_amount
remaining_amount
minimum_payment
start_date
target_date
status
created_at
updated_at
```

Status:

```text
active
paid
paused
```

---

### debt_payments

```text
id
user_id
debt_id
amount
payment_date
note
created_at
```

---

### savings_goals

```text
id
user_id
name
target_amount
current_amount
goal_type
target_date
created_at
updated_at
```

Goal types:

```text
emergency_fund
saving
purchase
other
```

---

## 13. Transaction Flow

Tambah pengeluaran:

```text
+
↓
Expense
↓
Makan
↓
Rp13.000
↓
Save
```

Setelah save:

```text
Budget Makan

Before
Rp850.000

Expense
Rp13.000

Remaining
Rp837.000
```

---

## 14. Debt Tracking

Initial:

```text
Total Debt
Rp38.000.000

Monthly Payment
Rp2.000.000
```

Dashboard:

```text
Debt Progress

Rp8.000.000 paid
Rp30.000.000 remaining

████░░░░░░░░░░░░
21%
```

Estimate:

```text
remaining_amount / planned_monthly_payment
```

Contoh:

```text
Rp30.000.000 / Rp2.000.000

= 15 months remaining
```

Extra payment harus ikut memperbarui estimasi.

---

## 15. Emergency Fund

Initial target:

```text
Target 1
Rp1.000.000

Target 2
Rp3.000.000

Target 3
3–6 months essential expenses
```

Progress:

```text
Emergency Fund

Rp1.200.000
───────────
Rp3.000.000

40%
```

Dana darurat dapat memiliki withdrawal.

Contoh:

```text
Motor rusak
- Rp400.000
```

History tetap tersimpan.

---

## 16. Notifications

### MVP Local Notifications

Reminder:

- Gajian.
- Bayar kos.
- Bayar WiFi.
- Bayar cicilan.
- Catat pengeluaran.
- Weekly spending summary.

Contoh:

```text
"Budget makan minggu ini tersisa Rp180.000."
```

### Future FCM

Gunakan Firebase Cloud Messaging jika membutuhkan server-triggered notification.

Contoh:

- server mendeteksi overspending
- scheduled backend job
- multiple devices
- remote notification

---

## 17. Authentication

Karena awalnya personal app:

### Option A — Supabase Auth

Gunakan:

```text
Email + Password
```

Recommended.

Keuntungan:

- data siap multi-device
- RLS mudah
- future-proof

### Option B — No Auth

Tidak direkomendasikan jika database langsung online.

---

## 18. Supabase RLS

Setiap tabel milik user harus menggunakan Row Level Security.

Concept:

```sql
user_id = auth.uid()
```

User hanya dapat membaca dan mengubah data miliknya sendiri.

Tables requiring RLS:

- profiles
- categories
- salary_entries
- allocation_rules
- monthly_budgets
- transactions
- debts
- debt_payments
- savings_goals

---

## 19. Allocation RPC

Recommended:

```text
allocate_salary()
```

Input:

```text
salary_amount
salary_date
month
year
```

Responsibilities:

1. Create salary entry.
2. Load active allocation rules.
3. Sort by priority.
4. Allocate fixed expenses.
5. Allocate capped categories.
6. Calculate remaining money.
7. Allocate percentage categories.
8. Create monthly budgets.
9. Return preview/result.

Important:

All operations should run atomically.

Either:

```text
ALL SUCCESS
```

or:

```text
ROLLBACK
```

---

## 20. Suggested Screens

### Bottom Navigation

```text
Dashboard
Transactions
Budget
Debt
Settings
```

### Screens

#### Dashboard

Overview keuangan.

#### Transactions

- Transaction list
- Add expense
- Add income
- Filter
- Search

#### Budget

- Monthly budget
- Category usage
- Allocation preview

#### Debt

- Debt balance
- Payment history
- Estimated payoff

#### Settings

- Allocation rules
- Categories
- Salary day / income cycle
- Baseline income
- Emergency target
- Extra income strategy
- Percentage calculation basis
- Priority ordering
- Minimum / maximum allocation
- Notification settings

---

## 21. MVP UI Flow

```text
Login
  ↓
Dashboard
  ↓
First Setup
  ↓
Set Salary Day
  ↓
Set Allocation Rules
  ↓
Receive Salary
  ↓
Preview Allocation
  ↓
Apply
  ↓
Track Expenses
```

---

## 22. Development Phases

### Phase 0 — Setup

- [ ] Create Flutter project.
- [ ] Create Supabase project.
- [ ] Setup Supabase Flutter.
- [ ] Setup Riverpod.
- [ ] Setup GoRouter.
- [ ] Setup environment configuration.
- [ ] Create basic theme.
- [ ] Setup Git repository.

---

### Phase 1 — Authentication

- [ ] Login.
- [ ] Register.
- [ ] Logout.
- [ ] Session persistence.
- [ ] Create profile.
- [ ] Add RLS.

Definition of Done:

> User dapat login dan hanya dapat mengakses datanya sendiri.

---

### Phase 2 — Categories & Allocation Rules

- [ ] Category CRUD.
- [ ] Allocation rule CRUD.
- [ ] Fixed allocation.
- [ ] Percentage allocation.
- [ ] Capped allocation.
- [ ] Priority sorting.
- [ ] Default rules seed.

Definition of Done:

> User dapat mengatur bagaimana gajinya dibagi.

---

### Phase 3 — Salary Allocation

- [ ] Add salary.
- [ ] Preview allocation.
- [ ] Apply allocation.
- [ ] Store monthly budget.
- [ ] Handle fluctuating salary.
- [ ] Validate insufficient salary.
- [ ] Support extra salary rule.

Definition of Done:

> Input gaji Rp5.000.000 / Rp5.300.000 / Rp5.500.000 menghasilkan pembagian otomatis yang valid.

---

### Phase 4 — Transactions

- [ ] Add expense.
- [ ] Add income.
- [ ] Edit transaction.
- [ ] Delete transaction.
- [ ] Transaction list.
- [ ] Filter by category.
- [ ] Update spent budget automatically.

Definition of Done:

> Pengeluaran Rp13.000 untuk makan langsung mengurangi sisa budget makan.

---

### Phase 5 — Dashboard

- [ ] Total salary.
- [ ] Remaining money.
- [ ] Monthly expenses.
- [ ] Budget progress.
- [ ] Safe Spending Today.
- [ ] Recent transactions.
- [ ] Debt progress.
- [ ] Emergency fund progress.

Definition of Done:

> Membuka app langsung memberi gambaran kondisi keuangan tanpa harus membuka menu lain.

---

### Phase 6 — Debt

- [ ] Create debt.
- [ ] Debt payment.
- [ ] Remaining debt.
- [ ] Payment history.
- [ ] Payoff estimation.
- [ ] Extra payment.

Definition of Done:

> User dapat mengetahui berapa utang tersisa dan estimasi bulan lunas.

---

### Phase 7 — Savings & Emergency Fund

- [ ] Saving goals.
- [ ] Deposit.
- [ ] Withdrawal.
- [ ] Emergency fund target.
- [ ] Progress indicator.

Definition of Done:

> Dana darurat dan tabungan tidak tercampur dengan uang belanja.

---

### Phase 8 — Notifications

- [ ] Setup local notifications.
- [ ] Salary reminder.
- [ ] Debt payment reminder.
- [ ] Kos reminder.
- [ ] WiFi reminder.
- [ ] Weekly budget reminder.

Definition of Done:

> Reminder tetap berjalan tanpa backend notification.

---

### Phase 9 — Polish

- [ ] Error handling.
- [ ] Loading state.
- [ ] Empty state.
- [ ] Currency formatter.
- [ ] Date formatter.
- [ ] Dark mode.
- [ ] Unit tests.
- [ ] Allocation engine tests.

---

## 23. Allocation Engine Tests

Important test cases:

### Case 1

```text
Salary = Rp5.000.000
```

Expected:

- all required fixed expenses allocated
- remaining money >= 0
- percentage allocations sum correctly

### Case 2

```text
Salary = Rp5.300.000
```

Expected:

- fixed lifestyle expenses stay unchanged
- extra money increases flexible allocations

### Case 3

```text
Salary = Rp5.500.000
```

Expected:

- no automatic lifestyle inflation
- extra salary follows configured rule

### Case 4

```text
Salary = Rp4.000.000
```

Expected:

- priority 1 is allocated first
- low-priority categories are reduced
- app displays insufficient income warning

### Case 5

```text
Salary < mandatory expenses
```

Expected:

```text
WARNING

Income tidak cukup untuk memenuhi seluruh kebutuhan wajib.

Shortage:
RpXXX.XXX
```

---

## 24. Business Rules

### Rule 1

Rule `fixed` mempertahankan nominal yang dikonfigurasi user dan tidak otomatis naik hanya karena pemasukan naik.

### Rule 2

Dana darurat bukan bagian dari spendable balance.

### Rule 3

Tabungan bukan bagian dari spendable balance.

### Rule 4

Extra income tidak otomatis menaikkan lifestyle budget.

### Rule 5

Payment utang harus mengurangi `remaining_amount`.

### Rule 6

Transaction harus memiliki category.

### Rule 7

Allocated budget tidak boleh melebihi available salary.

### Rule 8

Saldo tidak boleh menggunakan floating point.

Gunakan integer.

```dart
final amount = 13000;
```

Bukan:

```dart
final amount = 13000.50;
```

Untuk Rupiah integer sudah cukup.

---

## 25. Recommended Money Model

Simpan semua Rupiah sebagai integer.

```text
Rp13.000

Database:
13000
```

Jangan simpan:

```text
"Rp13.000"
```

Formatting dilakukan di UI.

---

## 26. Future Features

Setelah MVP stabil:

### V1.1

- Monthly history.
- Financial report.
- Spending chart.
- Category trend.
- Budget rollover.
- Custom salary cycle.

### V1.2

- Firebase FCM.
- Recurring transaction auto-create.
- Export CSV.
- Backup.
- Biometric lock.

### V2

- AI financial summary.
- Telegram / Discord input.
- Receipt scanning.
- Bank integration.
- Multiple wallet/account.
- Cashflow forecasting.
- Web dashboard.

---

## 27. Possible Discord Integration

Future architecture:

```text
Discord
   ↓
Bot
   ↓
Supabase Edge Function
   ↓
Supabase
```

Command:

```text
/spend makan 13000
```

Response:

```text
Expense recorded

Makan
Rp13.000

Remaining:
Rp437.000

Safe spending:
Rp29.133/day
```

---

## 28. Recommended MVP Scope

Untuk menghindari project berhenti di tengah, MVP cukup:

```text
1. Login
2. Salary input
3. Allocation rules
4. Auto allocation
5. Transactions
6. Dashboard
7. Debt tracking
8. Emergency fund
9. Local reminder
```

Jangan mulai dari:

```text
AI
Firebase
Discord bot
OCR
Bank integration
Charts kompleks
Offline sync kompleks
```

Selesaikan core money flow terlebih dahulu.

---

## 29. First Release Definition

Versi `0.1.0` dianggap selesai jika:

- [ ] Bisa login.
- [ ] Bisa input gaji.
- [ ] Gaji otomatis terbagi.
- [ ] Bisa melihat preview sebelum apply.
- [ ] Bisa input pengeluaran.
- [ ] Budget otomatis berkurang.
- [ ] Safe spending otomatis berubah.
- [ ] Utang dapat dicatat.
- [ ] Pembayaran utang dapat dicatat.
- [ ] Dana darurat dapat ditambah / dikurangi.
- [ ] Dashboard menampilkan kondisi bulan berjalan.
- [ ] Data aman dengan RLS.
- [ ] Reminder lokal berjalan.

---

## 30. Onboarding & Budget Templates

Aplikasi tidak boleh mengasumsikan kategori atau nominal tertentu milik user.

Saat onboarding, user dapat memilih:

```text
[ Start from Scratch ]
[ Basic Employee Template ]
[ Student Template ]
[ Freelancer Template ]
[ Family Template ]
```

Contoh `Basic Employee Template`:

```text
Tempat Tinggal
Makan
Transportasi
Internet
Cicilan
Dana Darurat
Tabungan
Hiburan
```

Template hanya membuat kategori dan rule awal.

Setelah template dipilih, user wajib dapat mengedit semuanya:

```text
Nama kategori
Nominal
Persentase
Priority
Allocation type
Minimum
Maximum
Required / Optional
Active / Inactive
```

Contoh hasil setelah user menyesuaikan:

```text
Income
Rp5.300.000

User-defined rules:

Kos
Rp850.000

Utang
Rp2.000.000

Makan
Rp900.000

Dana Darurat
40% remaining income

Tabungan
35% remaining income

Hiburan
25% remaining income
```

Tidak ada angka tersebut yang ditulis permanen di source code.

Seed/template hanya digunakan sebagai default UX agar onboarding cepat.

---

## 31. Success Metric

Project dianggap berhasil bukan ketika fiturnya banyak.

Project berhasil jika setiap user dapat mengatur sistem keuangannya sendiri dan aplikasi bisa membantu menjawab pertanyaan ini dalam beberapa detik:

1. Berapa uang saya sekarang?
2. Ke mana pemasukan bulan ini sudah dialokasikan?
3. Bulan ini saya masih boleh menghabiskan berapa?
4. Hari ini aman menghabiskan berapa?
5. Target keuangan, utang, dana darurat, dan tabungan saya sudah sejauh mana?

---

## 32. Recommended First Coding Order

```text
Supabase Schema
    ↓
RLS
    ↓
Auth
    ↓
Categories
    ↓
Allocation Rules
    ↓
Salary Allocation
    ↓
Monthly Budget
    ↓
Transactions
    ↓
Dashboard
    ↓
Debt
    ↓
Emergency Fund
    ↓
Notifications
```

Fokus pertama:

> Jangan mulai dari UI dashboard.

Pastikan terlebih dahulu `allocation engine` dan model database benar karena itu merupakan inti aplikasi.

---

## 33. Project Working Name

Temporary options:

```text
PayPlan
Gajiku
FlowMoney
SalaryFlow
PocketFlow
BagiGaji
```

Nama dapat diganti kapan saja dan tidak perlu menjadi blocker untuk development.
