// lib/features/smart/presentation/widgets/draft_editor_sheet.dart
//
// Satu form ringkas untuk meninjau / mengoreksi transaksi hasil deteksi
// (notifikasi, AI, struk) sebelum disimpan.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/ui.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/widgets/pickers.dart';
import '../../domain/quick_text_parser.dart';

Future<DraftTransaction?> showDraftEditor(
  BuildContext context, {
  required DraftTransaction draft,
  String title = 'Tinjau transaksi',
  String? subtitle,
  String confirmLabel = 'Simpan',
}) {
  return showAppModal<DraftTransaction>(
    context: context,
    builder: (_) => DraftEditorSheet(
      draft: draft,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
    ),
  );
}

class DraftEditorSheet extends ConsumerStatefulWidget {
  final DraftTransaction draft;
  final String title;
  final String? subtitle;
  final String confirmLabel;

  /// Bila diisi, form dipakai di dalam modal lain (tanpa membuka modal baru):
  /// hasil dikirim lewat callback, bukan Navigator.pop.
  final ValueChanged<DraftTransaction>? onSubmit;
  final VoidCallback? onCancel;

  const DraftEditorSheet({
    super.key,
    required this.draft,
    required this.title,
    this.subtitle,
    this.confirmLabel = 'Simpan',
    this.onSubmit,
    this.onCancel,
  });

  @override
  ConsumerState<DraftEditorSheet> createState() => _DraftEditorSheetState();
}

class _DraftEditorSheetState extends ConsumerState<DraftEditorSheet> {
  late TransactionType _type = widget.draft.type;
  late final _amount = TextEditingController(
    text: CurrencyInputFormatter.format(widget.draft.amount),
  );
  late final _merchant = TextEditingController(
    text: widget.draft.merchant ?? widget.draft.note ?? '',
  );
  late String? _categoryId = widget.draft.categoryId;
  late String? _walletId = widget.draft.walletId;
  late String? _toWalletId = widget.draft.toWalletId;
  late DateTime _date = widget.draft.date;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = CurrencyInputFormatter.parse(_amount.text);
    if (amount <= 0) return;
    final merchant = _merchant.text.trim();
    final result = DraftTransaction(
      type: _type,
      amount: amount,
      merchant: merchant.isEmpty ? null : merchant,
      note: merchant.isEmpty ? null : merchant,
      date: _date,
      providerKey: widget.draft.providerKey,
      toProviderKey: widget.draft.toProviderKey,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      walletId: _walletId,
      toWalletId: _type == TransactionType.transfer ? _toWalletId : null,
    );
    if (widget.onSubmit != null) {
      widget.onSubmit!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == TransactionType.transfer;
    return AppModalScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      showCloseButton: widget.onCancel == null,
      actions: [
        widget.onCancel != null
            ? OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Kembali'),
              )
            : AppModalScaffold.cancelButton(context),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: transactionTypeAccent(_type),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<TransactionType>(
            items: const [
              (TransactionType.expense, 'Keluar'),
              (TransactionType.income, 'Masuk'),
              (TransactionType.transfer, 'Transfer'),
            ],
            value: _type,
            activeColor: transactionTypeActiveColor,
            onChanged: (t) => setState(() {
              if (t != _type) _categoryId = null;
              _type = t;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 22),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchant,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: isTransfer ? 'Keterangan' : 'Merchant / catatan',
              hintText: 'mis. Kopi Kenangan',
            ),
          ),
          if (!isTransfer) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Kategori'),
            CategoryPicker(
              type: _type,
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: 18),
          AppFieldLabel(
            isTransfer
                ? 'Dari dompet'
                : (_type == TransactionType.income
                      ? 'Masuk ke dompet'
                      : 'Dibayar dari'),
          ),
          WalletPicker(
            value: _walletId,
            onChanged: (v) => setState(() => _walletId = v),
          ),
          if (isTransfer) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Ke dompet'),
            WalletPicker(
              value: _toWalletId,
              excludeId: _walletId,
              onChanged: (v) => setState(() => _toWalletId = v),
            ),
          ],
          const SizedBox(height: 18),
          const AppFieldLabel('Tanggal'),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
      ),
    );
  }
}
