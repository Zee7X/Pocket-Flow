// lib/features/debts_savings/domain/savings_goal.dart
enum GoalType {
  emergencyFund,
  saving,
  purchase,
  other;

  static GoalType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'emergency_fund':
        return GoalType.emergencyFund;
      case 'purchase':
        return GoalType.purchase;
      case 'saving':
      case 'custom_savings':
        return GoalType.saving;
      default:
        return GoalType.other;
    }
  }

  String toDbString() {
    switch (this) {
      case GoalType.emergencyFund:
        return 'emergency_fund';
      case GoalType.purchase:
        return 'purchase';
      case GoalType.saving:
        return 'saving';
      case GoalType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case GoalType.emergencyFund:
        return 'Dana Darurat';
      case GoalType.purchase:
        return 'Target Pembelian';
      case GoalType.saving:
        return 'Tabungan Impian';
      case GoalType.other:
        return 'Lainnya';
    }
  }
}

class SavingsGoal {
  final String id;
  final String userId;
  final String name;
  final GoalType goalType;
  final int targetAmount;
  final int currentAmount;
  final DateTime? targetDate;
  final String? icon;
  final String? color;
  final bool isCompleted;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.goalType,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.icon,
    this.color,
    this.isCompleted = false,
    required this.createdAt,
  });

  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get remainingToTarget => (targetAmount - currentAmount) > 0 ? (targetAmount - currentAmount) : 0;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final cur = (json['current_amount'] as num?)?.toInt() ?? 0;
    final target = (json['target_amount'] as num).toInt();
    final isDone = cur >= target && target > 0;

    return SavingsGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      goalType: GoalType.fromString(json['goal_type'] as String? ?? 'saving'),
      targetAmount: target,
      currentAmount: cur,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      icon: null,
      color: null,
      isCompleted: isDone,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'goal_type': goalType.toDbString(),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'is_active': true,
      if (targetDate != null)
        'target_date': targetDate!.toIso8601String().split('T').first,
    };
  }
}
