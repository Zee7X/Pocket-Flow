// lib/features/categories_rules/presentation/widgets/template_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../providers/categories_rules_provider.dart';

class TemplatePickerDialog extends ConsumerStatefulWidget {
  const TemplatePickerDialog({super.key});

  @override
  ConsumerState<TemplatePickerDialog> createState() =>
      _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends ConsumerState<TemplatePickerDialog> {
  String? _applyingKey;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(categoryTemplatesProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      title: Text(
        'Pilih Template Onboarding',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDarkPrimary,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error memuat template: $e'),
          data: (groups) {
            return ListView.separated(
              shrinkWrap: true,
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final group = groups[i];
                final isApplying = _applyingKey == group.key;

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDarkAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: isApplying ? AppTheme.primary : AppTheme.borderDark,
                    ),
                  ),
                  child: ListTile(
                    enabled: _applyingKey == null,
                    title: Text(
                      group.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textDarkPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${group.items.length} kategori bawaan (bisa diedit kapan saja)',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.textDarkSecondary,
                      ),
                    ),
                    trailing: isApplying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                    onTap: () => _apply(group.key, group.name),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applyingKey == null ? () => Navigator.pop(context) : null,
          child: const Text('Batal'),
        ),
      ],
    );
  }

  Future<void> _apply(String key, String name) async {
    setState(() => _applyingKey = key);
    try {
      await ref.read(categoriesProvider.notifier).applyTemplate(key);
      if (!mounted) return;
      Navigator.pop(context);
      AppTheme.showSuccessSnackBar(
        context,
        'Template "$name" berhasil diterapkan!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _applyingKey = null);
      AppTheme.showErrorSnackBar(
        context,
        'Gagal menerapkan template: $e',
      );
    }
  }
}
