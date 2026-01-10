import 'package:flutter/material.dart';

class SettingsBottomActions extends StatelessWidget {
  final VoidCallback onTransactions;
  final VoidCallback onPostponePayment;
  final VoidCallback onPayFees;

  const SettingsBottomActions({
    super.key,
    required this.onTransactions,
    required this.onPostponePayment,
    required this.onPayFees,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'سجل المعاملات',
            onTransactions,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            context,
            'طلب تأجيل الدفع',
            onPostponePayment,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            context,
            'تسديد الرسوم',
            onPayFees,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32), // Green
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Qatar',
          fontSize: 12, // Adjusted for space
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
