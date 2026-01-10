import 'package:flutter/material.dart';

import '../../../domain/models/wallet_info.dart';

class SettingsFinancialCard extends StatelessWidget {
  final WalletInfo walletInfo;
  final double dueAmount;
  final double totalAmount;

  const SettingsFinancialCard({
    super.key,
    required this.walletInfo,
    this.dueAmount = 0.0,
    this.totalAmount = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Row(
          children: [
            Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 24),
            SizedBox(width: 8),
            Text(
              'الحسابات والأرصدة',
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(25, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Row 1: Stats
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.monetization_on_outlined,
                      'إجمالي الاشتراكات',
                      '$totalAmount ${walletInfo.currency}',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.account_balance_wallet_outlined,
                      'الرصيد المتبقي',
                      '${walletInfo.pendingBalance} ${walletInfo.currency}',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.account_balance_rounded,
                      'الرصيد الحالي',
                      '${walletInfo.balance} ${walletInfo.currency}',
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // Row 2: Due Amount
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المبلغ المستحق',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$dueAmount ${walletInfo.currency}',
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red, // Red for due amount
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.monetization_on_outlined,
                          color: Colors.red,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value,
      {bool isHighlighted = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              color: isHighlighted ? const Color(0xFFD4AF37) : Colors.grey[400],
              size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Qatar',
              fontSize: 10, // Smaller font for longer labels
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Qatar',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlighted
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[200],
    );
  }
}
