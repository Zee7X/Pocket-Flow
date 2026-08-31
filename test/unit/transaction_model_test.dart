import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';

void main() {
  group('TransactionModel isUpcoming Tests', () {
    test('returns false for past dates', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final tx = TransactionModel(
        id: 'tx-past',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 50000,
        transactionDate: pastDate,
        createdAt: DateTime.now(),
      );

      expect(tx.isUpcoming, isFalse);
    });

    test('returns false for today date', () {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final tx = TransactionModel(
        id: 'tx-today',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 50000,
        transactionDate: todayDate,
        createdAt: DateTime.now(),
      );

      expect(tx.isUpcoming, isFalse);
    });

    test('returns true for future dates (tomorrow and beyond)', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final txTomorrow = TransactionModel(
        id: 'tx-tomorrow',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 50000,
        transactionDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        createdAt: DateTime.now(),
      );

      final nextMonth = DateTime.now().add(const Duration(days: 45));
      final txNextMonth = TransactionModel(
        id: 'tx-next-month',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 150000,
        transactionDate: DateTime(nextMonth.year, nextMonth.month, nextMonth.day),
        createdAt: DateTime.now(),
      );

      expect(txTomorrow.isUpcoming, isTrue);
      expect(txNextMonth.isUpcoming, isTrue);
    });
  });
}
