import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/formatters/currency_input_formatter.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../domain/salary_entry.dart';
import 'providers/salary_allocation_provider.dart';
import 'widgets/allocation_preview_sheet.dart';

class SalaryAllocationPage extends ConsumerStatefulWidget {
  const SalaryAllocationPage({super.key});

  @override
  ConsumerState<SalaryAllocationPage> createState() =>
      _SalaryAllocationPageState();
}

class _SalaryAllocationPageState extends ConsumerState<SalaryAllocationPage> {
  final _formKey = GlobalKey<FormState>();
  final _salaryCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(salaryHistoryProvider);
    final actionState = ref.watch(salaryAllocationActionProvider);
    final isLoading = actionState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alokasi Gaji',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.pastelBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Atur Aturan & Kategori',
            onPressed: () => context.push(AppRoutes.categoriesRules),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 800,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Input Gaji Hero Card ───────────────────────────────────
                _buildSalaryInputCard(isLoading),

                const SizedBox(height: 16),

                // ── Shortcut Hint Banner ──────────────────────────────────
                InkWell(
                  onTap: () => context.push(AppRoutes.categoriesRules),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.borderLightSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded,
                              size: 16, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingin Budget Terbagi Otomatis?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDarkPrimary,
                                ),
                              ),
                              Text(
                                'Gunakan Template Onboarding atau atur target per kategori.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppTheme.textDarkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Riwayat Alokasi Gaji ───────────────────────────────────
                Text(
                  'Riwayat Gajian & Alokasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                _buildHistoryList(historyAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryInputCard(bool isLoading) {
    return CloudPulseCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input Gajian Masuk',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDarkPrimary,
                        ),
                      ),
                      Text(
                        'Simulasikan & kunci alokasi budget bulanan',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.textDarkSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Salary Amount Input
            TextFormField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: AppTheme.monoCurrency(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Nominal Gaji Bersih (Take Home Pay)',
                hintText: 'misal: 8.500.000',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nominal gaji wajib diisi';
                final amount = CurrencyInputFormatter.parse(v);
                if (amount <= 0) {
                  return 'Masukkan nominal yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Period Selection (Month & Year)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    items: List.generate(12, (i) => i + 1).map((m) {
                      const months = [
                        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
                      ];
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          months[m - 1],
                          style: GoogleFonts.dmSans(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Tahun'),
                    items: [2024, 2025, 2026, 2027].map((y) {
                      return DropdownMenuItem(
                        value: y,
                        child: Text(
                          '$y',
                          style: GoogleFonts.dmSans(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Date Received Picker
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Gajian Diterima',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(
                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _previewAllocation,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calculate_rounded, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Preview Alokasi Otomatis',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(AsyncValue<List<SalaryEntry>> historyAsync) {
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (history) {
        if (history.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'Belum Ada Riwayat',
            description:
                'Alokasi gajian yang kamu masukkan akan tercatat rapi di sini.',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final entry = history[i];
            final periodStr = DateFormat('MMMM yyyy')
                .format(DateTime(entry.periodYear, entry.periodMonth));

            return CloudPulseCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.pastelBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Diterima: ${DateFormat('dd MMM yyyy').format(entry.salaryDate)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textDarkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      entry.amount.toRupiah,
                      style: AppTheme.monoCurrency(
                        color: AppTheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _previewAllocation() async {
    if (!_formKey.currentState!.validate()) return;

    final totalSalary = CurrencyInputFormatter.parse(_salaryCtrl.text);

    final result = await ref
        .read(salaryAllocationActionProvider.notifier)
        .preview(
          salaryAmount: totalSalary,
          salaryDate: _selectedDate,
          periodMonth: _selectedMonth,
          periodYear: _selectedYear,
        );

    if (result != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        builder: (_) => AllocationPreviewSheet(
          result: result,
          onConfirm: () async {
            Navigator.pop(context);
            await ref
                .read(salaryAllocationActionProvider.notifier)
                .execute(
                  salaryAmount: totalSalary,
                  salaryDate: _selectedDate,
                  periodMonth: _selectedMonth,
                  periodYear: _selectedYear,
                );
            if (mounted) {
              AppTheme.showSuccessSnackBar(
                context,
                'Alokasi gaji berhasil dikunci & diterapkan!',
              );
            }
          },
        ),
      );
    }
  }
}
