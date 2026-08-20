// lib/features/salary_allocation/presentation/salary_allocation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../domain/salary_entry.dart';
import 'providers/salary_allocation_provider.dart';
import 'widgets/allocation_preview_sheet.dart';

class SalaryAllocationPage extends ConsumerStatefulWidget {
  const SalaryAllocationPage({super.key});

  @override
  ConsumerState<SalaryAllocationPage> createState() => _SalaryAllocationPageState();
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
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
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

                const SizedBox(height: 28),

                // ── Riwayat Alokasi Gaji ───────────────────────────────────
                Text(
                  'Riwayat Gajian & Alokasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
      hasGlow: true,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Input Gajian Masuk',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              style: AppTheme.monoCurrency(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Jumlah Gaji / Penghasilan',
                hintText: '5000000',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final clean = v?.replaceAll('.', '').replaceAll(',', '') ?? '';
                final val = int.tryParse(clean);
                if (val == null || val <= 0) return 'Masukkan nominal gaji > 0';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Date picker & Period selector
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: GoogleFonts.dmSans(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: const BorderSide(color: AppTheme.borderDark),
                      foregroundColor: AppTheme.textDarkPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: isLoading ? null : _previewAllocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Preview Alokasi Otomatis'),
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
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'Belum Ada Riwayat',
            description: 'Penghasilan yang dialokasikan akan dicatat di sini.',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final entry = entries[i];
            return CloudPulseCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: AppTheme.success, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gaji ${_getMonthName(entry.periodMonth)} ${entry.periodYear}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy').format(entry.salaryDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    entry.amount.toRupiah,
                    style: AppTheme.monoCurrency(
                      color: AppTheme.primary,
                      fontSize: 15,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }

  Future<void> _previewAllocation() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_salaryCtrl.text.replaceAll('.', '').replaceAll(',', ''));

    final result = await ref.read(salaryAllocationActionProvider.notifier).preview(
          salaryAmount: amount,
          salaryDate: _selectedDate,
          periodMonth: _selectedMonth,
          periodYear: _selectedYear,
        );

    if (result != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AllocationPreviewSheet(
          result: result,
          onConfirm: () async {
            Navigator.pop(ctx);
            final execResult = await ref
                .read(salaryAllocationActionProvider.notifier)
                .execute(
                  salaryAmount: amount,
                  salaryDate: _selectedDate,
                  periodMonth: _selectedMonth,
                  periodYear: _selectedYear,
                );
            if (execResult != null && mounted) {
              _salaryCtrl.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Gaji berhasil dialokasikan ke budget bulanan!'),
                ),
              );
            }
          },
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[month - 1];
  }
}
