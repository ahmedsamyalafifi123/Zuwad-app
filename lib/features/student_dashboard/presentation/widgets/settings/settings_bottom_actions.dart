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
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            label: 'سجل المعاملات',
            onTap: onTransactions,
            isDesktop: isDesktop,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'طلب تأجيل الدفع',
            onTap: onPostponePayment,
            isDesktop: isDesktop,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'تسديد الرسوم',
            onTap: onPayFees,
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(255, 57, 189, 64), // Green 400
                Color.fromARGB(255, 48, 126, 52), // Green 600
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    required bool isDesktop,
  }) {
    if (gradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 16 : 8, horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: 'Qatar',
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 1.5),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding:
            EdgeInsets.symmetric(vertical: isDesktop ? 16 : 8, horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontFamily: 'Qatar',
          fontSize: isDesktop ? 14 : 12, // Adjusted for space
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
