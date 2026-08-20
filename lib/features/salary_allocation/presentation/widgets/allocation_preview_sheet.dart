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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hasil Preview Alokasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
              Text(
                result.salaryAmount.toRupiah,
                style: AppTheme.monoCurrency(
                  color: AppTheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bulan ${result.periodMonth}/${result.periodYear}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textDarkSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Warnings if any
          if (result.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.warnings.map((w) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.message,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Breakdown list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: result.allocations.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final alloc = result.allocations[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alloc.ruleName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                          Text(
                            alloc.allocationType.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.textDarkMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        alloc.allocatedAmount.toRupiah,
                        style: AppTheme.monoCurrency(
                          color: alloc.allocatedAmount > 0
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textDarkMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Remaining summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightAlt,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sisa Belum Teralokasi:',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textDarkSecondary,
                  ),
                ),
                Text(
                  result.remaining.toRupiah,
                  style: AppTheme.monoCurrency(
                    color: result.remaining > 0 ? AppTheme.success : AppTheme.textDarkMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          ElevatedButton(
            onPressed: isApplying ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: isApplying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Terapkan & Buat Budget Bulanan'),
          ),
        ],
      ),
    );
  }
}
