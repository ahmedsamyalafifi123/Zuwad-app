import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

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
            Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 24),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: const Color(0xFFEEEEEE),
                ),
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF9F9F9)),
                  columns: const [
                    DataColumn(
                        label: Text('الطالب',
                            style: TextStyle(
                                fontFamily: 'Qatar',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    DataColumn(
                        label: Text('المادة',
                            style: TextStyle(
                                fontFamily: 'Qatar',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    DataColumn(
                        label: Text('المتبقي',
                            style: TextStyle(
                                fontFamily: 'Qatar',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    DataColumn(
                        label: Text('القيمة',
                            style: TextStyle(
                                fontFamily: 'Qatar',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                  ],
                  rows: familyMembers.map((member) {
                    final amount = member['amount']?.toString() ?? '0';
                    final currency = member['currency'] ?? 'SAR';
                    final lessonsName = member['lessons_name'] ?? '-';
                    // Note: 'remaining_lessons' might not be in the simple family list response
                    // We might need to fetch it or use placeholder if not available.
                    // Assuming API returns basic info. Using '0' as placeholder if missing.
                    final remaining =
                        member['remaining_lessons']?.toString() ?? '-';

                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFD4AF37), width: 1),
                            ),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: member['profile_image_url'] !=
                                      null
                                  ? NetworkImage(member['profile_image_url'])
                                  : null,
                              child: member['profile_image_url'] == null
                                  ? const Icon(Icons.person,
                                      size: 12, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(member['name'] ?? '',
                              style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ],
                      )),
                      DataCell(Text(lessonsName,
                          style: const TextStyle(fontFamily: 'Qatar'))),
                      DataCell(Text(remaining,
                          style: const TextStyle(fontFamily: 'Qatar'))),
                      DataCell(Text('$amount $currency',
                          style: const TextStyle(
                              fontFamily: 'Qatar',
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
