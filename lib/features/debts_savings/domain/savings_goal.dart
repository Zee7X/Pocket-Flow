// lib/features/debts_savings/domain/savings_goal.dart
enum GoalType {
  emergencyFund,
  customSavings,
  investment;

  static GoalType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'emergency_fund':
        return GoalType.emergencyFund;
      case 'investment':
        return GoalType.investment;
      case 'custom_savings':
      default:
        return GoalType.customSavings;
    }
  }

  String toDbString() {
    switch (this) {
      case GoalType.emergencyFund:
        return 'emergency_fund';
      case GoalType.investment:
        return 'investment';
      case GoalType.customSavings:
        return 'custom_savings';
    }
  }

  String get displayName {
    switch (this) {
      case GoalType.emergencyFund:
        return 'Dana Darurat';
      case GoalType.investment:
        return 'Investasi';
      case GoalType.customSavings:
        return 'Tabungan Khusus';
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
  int get remainingToTarget => targetAmount - currentAmount;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      goalType: GoalType.fromString(json['goal_type'] as String? ?? 'custom_savings'),
      targetAmount: (json['target_amount'] as num).toInt(),
      currentAmount: (json['current_amount'] as num?)?.toInt() ?? 0,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
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
      if (targetDate != null)
        'target_date': targetDate!.toIso8601String().split('T').first,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      'is_completed': isCompleted,
    };
  }
}
