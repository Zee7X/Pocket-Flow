// lib/core/widgets/period_picker.dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/date_id.dart';
import 'app_modal.dart';
import 'ui.dart';

typedef Period = ({int month, int year});

/// Pemilih bulan: tahun dengan tombol panah, lalu grid 12 bulan.
/// Satu ketukan pada bulan langsung memilih dan menutup.
Future<Period?> showPeriodPicker(BuildContext context, Period current) {
  return showAppModal<Period>(
    context: context,
    builder: (_) => _PeriodPicker(current: current),
  );
}

class _PeriodPicker extends StatefulWidget {
  final Period current;
  const _PeriodPicker({required this.current});

  @override
  State<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<_PeriodPicker> {
  late int _year = widget.current.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AppModalScaffold(
      title: 'Pilih bulan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Tahun sebelumnya',
                onPressed: _year > 2015 ? () => setState(() => _year--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: Ui.title(size: 18),
                ),
              ),
              IconButton(
                tooltip: 'Tahun berikutnya',
                onPressed: _year < now.year + 2
                    ? () => setState(() => _year++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              for (var m = 1; m <= 12; m++)
                _MonthCell(
                  label: kMonthsShortId[m - 1],
                  selected:
                      m == widget.current.month && _year == widget.current.year,
                  isNow: m == now.month && _year == now.year,
                  onTap: () =>
                      Navigator.of(context).pop((month: m, year: _year)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((month: now.month, year: now.year)),
            child: const Text('Kembali ke bulan ini'),
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isNow;
  final VoidCallback onTap;
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.isNow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? AppTheme.primary
              : (isNow ? AppTheme.primary.withValues(alpha: 0.5) : Ui.border),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: Ui.body(
              size: 14,
              color: selected ? Colors.white : AppTheme.textDarkPrimary,
              weight: selected || isNow ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
