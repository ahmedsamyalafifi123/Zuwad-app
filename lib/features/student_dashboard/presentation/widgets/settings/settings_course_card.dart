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
                      '${student.remainingLessons ?? 0}',
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
              child: _buildActionButton(
                label: 'تبديل المعلمة',
                onTap: onChangeTeacher,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                label: 'الغاء التجديد',
                onTap: onCancelRenewal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                label: 'تعديل الباقة',
                onTap: onEditPackage,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Lighter Gold
                    Color(0xFFD4AF37), // Gold
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                textColor: Colors.black,
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

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? textColor,
  }) {
    if (gradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: textColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Qatar',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: textColor ?? Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Qatar',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
