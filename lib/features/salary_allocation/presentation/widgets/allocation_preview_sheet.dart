// lib/features/salary_allocation/presentation/widgets/allocation_preview_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../domain/salary_allocation_result.dart';

class AllocationPreviewSheet extends StatelessWidget {
  final SalaryAllocationResult result;
  final VoidCallback onConfirm;
  final bool isApplying;

  const AllocationPreviewSheet({
    super.key,
    required this.result,
    required this.onConfirm,
    this.isApplying = false,
  });

  String _formatWarningMessage(AllocationWarning w) {
    if (w.message.contains('No remaining income') ||
        w.code == 'INSUFFICIENT_FUNDS') {
      return 'Gaji tidak mencukupi untuk pos wajib: ${w.ruleName ?? "Aturan Wajib"} (teralokasi Rp 0)';
    }
    if (w.message.contains('Insufficient income') || w.code == 'SHORTFALL') {
      final shortfallText =
          w.shortfall != null ? ' (kurang ${w.shortfall!.toRupiah})' : '';
      return 'Gaji tidak cukup untuk pos wajib: ${w.ruleName ?? ""}$shortfallText';
    }
    return w.message;
  }

  @override
  Widget build(BuildContext context) {
    final hasDeficit = result.warnings.isNotEmpty;
    final allocatedPct = result.salaryAmount > 0
        ? ((result.totalAllocated / result.salaryAmount) * 100).clamp(0, 100)
        : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil Preview Alokasi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Periode: Bulan ${result.periodMonth}/${result.periodYear}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.textDarkSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  result.salaryAmount.toRupiah,
                  style: AppTheme.monoCurrency(
                    fontSize: 14,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── 3-Column Financial Summary Card ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightAlt,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.borderLightSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Total Allocated
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Terencana',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.textDarkSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.totalAllocated.toRupiah,
                            style: AppTheme.monoCurrency(
                              fontSize: 13,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppTheme.borderLight,
                    ),
                    const SizedBox(width: 12),
                    // Remaining
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDeficit ? 'Defisit / Status' : 'Sisa Uang Bebas',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: hasDeficit
                                  ? AppTheme.danger
                                  : AppTheme.textDarkSecondary,
                              fontWeight:
                                  hasDeficit ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasDeficit
                                ? 'Uang Kurang'
                                : result.remaining.toRupiah,
                            style: AppTheme.monoCurrency(
                              fontSize: 13,
                              color: hasDeficit
                                  ? AppTheme.danger
                                  : (result.remaining > 0
                                      ? AppTheme.success
                                      : AppTheme.textDarkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: allocatedPct / 100.0,
                    minHeight: 6,
                    backgroundColor: AppTheme.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hasDeficit ? AppTheme.danger : AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${allocatedPct.toStringAsFixed(0)}% Terencana',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.textDarkMuted,
                      ),
                    ),
                    Text(
                      hasDeficit
                          ? 'Perlu Penyesuaian'
                          : '${(100 - allocatedPct).toStringAsFixed(0)}% Sisa Bebas',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: hasDeficit ? AppTheme.danger : AppTheme.textDarkMuted,
                        fontWeight:
                            hasDeficit ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Warnings / Deficit Banner
          if (result.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // soft pastel red
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AppTheme.danger),
                      const SizedBox(width: 6),
                      Text(
                        'Peringatan Defisit Kebutuhan Wajib',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...result.warnings.map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• ${_formatWarningMessage(w)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF991B1B),
                          height: 1.3,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    'Saran: Turunkan batas pos fleksibel atau sesuaikan nominal aturan wajib Anda.',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: const Color(0xFFB91C1C),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Breakdown list title
          Text(
            'Rincian Pembagian per Pos:',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDarkSecondary,
            ),
          ),
          const SizedBox(height: 6),

          // Breakdown list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: result.allocations.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (ctx, i) {
                final alloc = result.allocations[i];
                final isZero = alloc.allocatedAmount == 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alloc.ruleName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isZero
                                  ? AppTheme.danger
                                  : AppTheme.textDarkPrimary,
                            ),
                          ),
                          Text(
                            alloc.allocationType.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: AppTheme.textDarkMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        alloc.allocatedAmount.toRupiah,
                        style: AppTheme.monoCurrency(
                          color: isZero
                              ? AppTheme.danger
                              : AppTheme.textDarkPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Confirm button
          ElevatedButton(
            onPressed: isApplying ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasDeficit ? AppTheme.warning : AppTheme.primary,
              minimumSize: const Size(double.infinity, 46),
            ),
            child: isApplying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    hasDeficit
                        ? 'Tetap Kunci & Terapkan Budget'
                        : 'Terapkan & Buat Budget Bulanan',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
