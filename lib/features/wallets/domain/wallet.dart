// lib/features/wallets/domain/wallet.dart
import 'package:flutter/material.dart';

enum WalletKind {
  cash,
  bank,
  ewallet,
  credit,
  paylater,
  other;

  static WalletKind fromString(String? v) {
    for (final k in values) {
      if (k.name == v) return k;
    }
    return WalletKind.other;
  }

  String get label => switch (this) {
    WalletKind.cash => 'Tunai',
    WalletKind.bank => 'Rekening Bank',
    WalletKind.ewallet => 'E-Wallet',
    WalletKind.credit => 'Kartu Kredit',
    WalletKind.paylater => 'Paylater',
    WalletKind.other => 'Lainnya',
  };

  IconData get icon => switch (this) {
    WalletKind.cash => Icons.payments_outlined,
    WalletKind.bank => Icons.account_balance_outlined,
    WalletKind.ewallet => Icons.account_balance_wallet_outlined,
    WalletKind.credit => Icons.credit_card_outlined,
    WalletKind.paylater => Icons.schedule_outlined,
    WalletKind.other => Icons.wallet_outlined,
  };

  /// Kartu kredit & paylater: saldo negatif berarti tagihan.
  bool get isLiability =>
      this == WalletKind.credit || this == WalletKind.paylater;
}

class Wallet {
  final String id;
  final String userId;
  final String name;
  final WalletKind kind;
  final String? providerKey;
  final int initialBalance;
  final String? color;
  final bool isArchived;
  final int sortOrder;

  /// Saldo berjalan dari view pf_wallet_balances.
  final int balance;

  const Wallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    this.providerKey,
    this.initialBalance = 0,
    this.color,
    this.isArchived = false,
    this.sortOrder = 0,
    this.balance = 0,
  });

  Color get displayColor {
    final c = color;
    if (c != null && c.startsWith('#') && c.length == 7) {
      return Color(int.parse('FF${c.substring(1)}', radix: 16));
    }
    return const Color(0xFF475569);
  }

  factory Wallet.fromJson(Map<String, dynamic> json, {int? balance}) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      kind: WalletKind.fromString(json['kind'] as String?),
      providerKey: json['provider_key'] as String?,
      initialBalance: (json['initial_balance'] as num?)?.toInt() ?? 0,
      color: json['color'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      balance: balance ?? (json['initial_balance'] as num?)?.toInt() ?? 0,
    );
  }

  Wallet copyWith({int? balance}) => Wallet(
    id: id,
    userId: userId,
    name: name,
    kind: kind,
    providerKey: providerKey,
    initialBalance: initialBalance,
    color: color,
    isArchived: isArchived,
    sortOrder: sortOrder,
    balance: balance ?? this.balance,
  );
}

String colorToHex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
