import 'package:flutter/material.dart';

class SettingsSubscriptionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> familyMembers;

  const SettingsSubscriptionsCard({
    super.key,
    required this.familyMembers,
  });

  @override
  Widget build(BuildContext context) {
    if (familyMembers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Row(
          children: [
            Icon(Icons.brightness_low_outlined,
                color: Color(0xFFD4AF37), size: 28),
            SizedBox(width: 8),
            Text(
              'إشتراكات الطلاب',
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

        // Table Card
        Container(
          width: double.infinity,
          color: Colors.transparent,
          child: Column(
            children: [
              // Header Row
              _buildRow(
                isHeader: true,
                col1: 'اسم الطالب',
                col2: 'المادة',
                col3: 'المتبقي',
                col4: 'المبلغ',
              ),
              const SizedBox(height: 6),

              // Data Rows
              ...familyMembers.map((member) {
                final amount = member['amount']?.toString() ?? '0';
                final currency = member['currency'] ?? 'SAR';
                final lessonsName = member['lessons_name'] ?? '-';
                final remaining =
                    member['remaining_lessons']?.toString() ?? '0';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildRow(
                    isHeader: false,
                    col1: member['name'] ?? '',
                    col2: lessonsName,
                    col3: '$remaining حصص',
                    col4: '$amount $currency',
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow({
    required bool isHeader,
    required String col1,
    required String col2,
    required String col3,
    required String col4,
  }) {
    final textStyle = TextStyle(
      fontFamily: 'Qatar',
      fontWeight: FontWeight.bold,
      color: isHeader ? Colors.black : Colors.black,
      fontSize: 12,
    );

    final nameTextStyle = TextStyle(
      fontFamily: 'Qatar',
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontSize: isHeader ? 14 : 12,
    );
    final headerTextStyle = TextStyle(
      fontFamily: 'Qatar',
      fontWeight: FontWeight.bold,
      color: Colors.black,
      fontSize: 14,
    );

    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          // Layer 1: Background (Student Name) - Spans Full Width
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Right Side (RTL Start): Student Name - Visible
                  Expanded(
                    flex: 4,
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        col1,
                        style: nameTextStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Left Side (RTL End): Empty - Covered by Layer 2
                  const Expanded(
                    flex: 8,
                    child: SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // Layer 2: Foreground (Details) - Covers Left Side
          Positioned.fill(
            child: Row(
              children: [
                // Right Side: Transparent Spacer to show Name below
                const Expanded(
                  flex: 4,
                  child: SizedBox(),
                ),
                // Left Side: White Details Box
                Expanded(
                  flex: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              col2,
                              style: isHeader ? headerTextStyle : textStyle,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              col3,
                              style: isHeader ? headerTextStyle : textStyle,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              col4,
                              style: isHeader ? headerTextStyle : textStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
