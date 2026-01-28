import 'package:flutter/material.dart';

import 'package:zuwad/core/utils/gender_helper.dart';
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
            const Icon(Icons.brightness_low_outlined,
                color: Color(0xFFD4AF37), size: 28),
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
                color: Color.fromARGB(100, 0, 0, 0),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Row 1: Stats
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.format_list_numbered_rounded,
                      'عدد الحصص',
                      '${student.lessonsNumber ?? 0} حصص',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.timer_rounded,
                      'مدة الحصة',
                      '${student.lessonDuration ?? 0} دقيقة',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      Icons.hourglass_bottom_rounded,
                      'حصص متبقية',
                      '${student.remainingLessons ?? 0} حصص',
                      isHighlighted: false,
                    ),
                  ],
                ),
              ),

              // Combined Teacher and Price Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Right Side: Price (In RTL, first child is Right)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'سعر الباقة',
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 14,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${student.amount ?? 0} ${student.currency ?? "SAR"}',
                              style: const TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Left Side: Teacher (In RTL, last child is Left)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFD4AF37), width: 1),
                            image: DecorationImage(
                              image: AssetImage(
                                GenderHelper.getTeacherImage(
                                    student.teacherGender),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              GenderHelper.getTeacherTitle(
                                  student.teacherGender),
                              style: const TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              student.teacherName?.split(' ').first ??
                                  'غير محدد',
                              style: const TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
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
                context: context,
                label: student.teacherGender == 'أنثى'
                    ? 'تبديل المعلمة'
                    : 'تبديل المعلم',
                onTap: onChangeTeacher,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'الغاء التجديد',
                onTap: onCancelRenewal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context: context,
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
            color: isHighlighted ? const Color(0xFFD4AF37) : Color(0xFFD4AF37),
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
      height: 70,
      width: 2,
      color: const Color(0xFF820c22),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? textColor,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (gradient != null) {
      return Container(
        height: isDesktop ? 50 : 36, // Increased height for desktop
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
            padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 16 : 8, horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Qatar',
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 15 : 12, // Increased font size
              color: textColor ?? Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return SizedBox(
      height: isDesktop ? 50 : 36, // Increased height for desktop
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              EdgeInsets.symmetric(vertical: isDesktop ? 16 : 8, horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Qatar',
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 15 : 12, // Increased font size
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
