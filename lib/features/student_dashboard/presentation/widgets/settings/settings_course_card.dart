import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../auth/domain/models/student.dart';

class SettingsCourseCard extends StatelessWidget {
  final Student student;
  final VoidCallback onEditPackage;
  final VoidCallback onCancelRenewal;
  final VoidCallback onChangeTeacher;

  const SettingsCourseCard({
    super.key,
    required this.student,
    required this.onEditPackage,
    required this.onCancelRenewal,
    required this.onChangeTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 24),
            const SizedBox(width: 8),
            Text(
              student.displayLessonName,
              style: const TextStyle(
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
                      Icons.format_list_numbered_rounded,
                      'عدد الحصص',
                      '${student.lessonsNumber ?? 0}',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.timer_rounded,
                      'المدة',
                      '${student.lessonDuration ?? 0} دقيقة',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.hourglass_bottom_rounded,
                      'المتبقي',
                      '0', // Placeholder or calculation
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // Row 2: Teacher
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFD4AF37), width: 1),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.grey, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المعلم',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            student.teacherName ?? 'غير محدد',
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // Row 3: Price
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سعر الباقة',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${student.amount ?? 0} ${student.currency ?? "SAR"}',
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppTheme.primaryColor,
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

        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onEditPackage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'تعديل الباقة',
                  style: TextStyle(
                      fontFamily: 'Qatar', fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onCancelRenewal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x80FFFFFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'الغاء التجديد',
                  style: TextStyle(fontFamily: 'Qatar'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onChangeTeacher,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x80FFFFFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'تبديل المعلمة',
                  style: TextStyle(fontFamily: 'Qatar'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value,
      {bool isHighlighted = false}) {
    return Column(
      children: [
        Icon(icon,
            color: isHighlighted ? const Color(0xFFD4AF37) : Colors.grey[400],
            size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Qatar',
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Qatar',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlighted
                ? const Color(0xFFD4AF37)
                : const Color(0xFF333333),
          ),
        ),
      ],
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
