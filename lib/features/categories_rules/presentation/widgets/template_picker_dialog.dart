// lib/features/categories_rules/presentation/widgets/template_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../providers/categories_rules_provider.dart';

class TemplatePickerDialog extends ConsumerWidget {
  const TemplatePickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDarkAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: ListTile(
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
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppTheme.primary),
                    onTap: () async {
                      Navigator.pop(context);
                      await ref
                          .read(categoriesProvider.notifier)
                          .applyTemplate(group.key);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Template "${group.name}" berhasil diterapkan!',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
