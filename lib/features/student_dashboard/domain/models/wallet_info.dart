/// Wallet information for a student's family.
class WalletInfo {
  final int? familyId;
  final double balance;
  final double pendingBalance;
  final String currency;
  final List<WalletTransaction> transactions;

  WalletInfo({
    this.familyId,
    required this.balance,
    required this.pendingBalance,
    required this.currency,
    this.transactions = const [],
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    List<WalletTransaction> transactionsList = [];
    if (json['transactions'] != null) {
      transactionsList = (json['transactions'] as List)
          .map((t) => WalletTransaction.fromJson(t))
          .toList();
    }

    return WalletInfo(
      familyId: json['family_id'],
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      pendingBalance:
          double.tryParse(json['pending_balance']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'EGP',
      transactions: transactionsList,
    );
  }
}

/// A single wallet transaction record.
class WalletTransaction {
  final int id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final String? studentName;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.studentName,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? 0,
      type: json['type']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      studentName: json['student_name']?.toString(),
    );
  }

  /// Get Arabic label for transaction type
  String get typeLabel {
    final typeLower = type.toLowerCase();
    switch (typeLower) {
      case 'add':
      case 'deposit':
      case 'credit':
        return 'إيداع';
      case 'deduct':
      case 'deduction':
      case 'withdrawal':
      case 'debit':
        return 'خصم';
      case 'lesson':
        return 'درس';
      case 'refund':
        return 'استرداد';
      default:
        // Check if type contains Arabic indicators
        if (type.contains('إضافة') || type.contains('إيداع')) {
          return 'إيداع';
        }
        if (type.contains('خصم') || type.contains('سحب')) {
          return 'خصم';
        }
        return type.isNotEmpty ? type : 'معاملة';
    }
  }

  /// Returns true if transaction is positive (credit/add)
  bool get isCredit {
    final typeLower = type.toLowerCase();
    // Check type first
    if (typeLower == 'add' ||
        typeLower == 'deposit' ||
        typeLower == 'credit' ||
        typeLower == 'refund') {
      return true;
    }
    if (typeLower == 'deduct' ||
        typeLower == 'deduction' ||
        typeLower == 'withdrawal' ||
        typeLower == 'debit' ||
        typeLower == 'lesson') {
      return false;
    }
    // Check Arabic keywords in type
    if (type.contains('إضافة') ||
        type.contains('إيداع') ||
        type.contains('استرداد')) {
      return true;
    }
    // Check description for credit indicators
    if (description.contains('إضافة') ||
        description.contains('إيداع') ||
        description.contains('رصيد')) {
      return true;
    }
    // Default: check if amount is positive in description context
    return false;
  }
}
