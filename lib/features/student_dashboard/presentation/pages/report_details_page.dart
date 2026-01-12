import 'package:flutter/material.dart';

import '../../domain/models/student_report.dart';
import 'package:zuwad/core/utils/gender_helper.dart';
import '../widgets/islamic_bottom_nav_bar.dart';

class ReportDetailsPage extends StatelessWidget {
  final StudentReport report;
  final String teacherGender;

  const ReportDetailsPage({
    super.key,
    required this.report,
    this.teacherGender = 'ذكر',
  });

  // Calculate rating based on evaluation string or grade
  int _calculateRating() {
    // Try to map evaluation text
    final evaluation = report.evaluation.toLowerCase().trim();
    if (evaluation.contains('ممتاز') || evaluation.contains('excellent')) {
      return 5;
    }
    if (evaluation.contains('جيد جدا') || evaluation.contains('very good')) {
      return 4;
    }
    if (evaluation.contains('جيد') || evaluation.contains('good')) return 3;
    if (evaluation.contains('مقبول') ||
        evaluation.contains('fair') ||
        evaluation.contains('acceptable')) {
      return 2;
    }
    if (evaluation.contains('ضعيف') ||
        evaluation.contains('weak') ||
        evaluation.contains('poor')) {
      return 1;
    }

    // Fallback to grade if available (assuming 10 or 100 scale?)
    // If grade is 0, default to 5 stars for positive UX or 0?
    // Let's default to 5 if unknown or maybe 0.
    if (report.grade > 0) {
      if (report.grade <= 5) return report.grade;
      if (report.grade <= 10) return (report.grade / 2).ceil();
      if (report.grade <= 100) return (report.grade / 20).ceil();
    }

    return 5; // Default to 5 stars if no negative info
  }

  @override
  Widget build(BuildContext context) {
    // Determine overall rating to use for all categories
    final int rating = _calculateRating();

    return Scaffold(
      backgroundColor: const Color(0xFF8b0628), // Deep Red Background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255), // Warm cream white
                Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(85, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center: Title
                  const Text(
                    'تقرير اليوم',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Right: Back Button instead of Page Icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF8B0628), size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Left: Avatar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26D4AF37),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                        image: DecorationImage(
                          image: AssetImage(
                            GenderHelper.getTeacherImage(teacherGender),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Session Number Header
                  _buildSessionHeader(),

                  const SizedBox(height: 24),

                  // Evaluation Section
                  _buildSectionHeader('التقييم والأداء', Icons.star),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStarColumn('التجويد', rating),
                      _buildStarColumn('المراجعة', rating),
                      _buildStarColumn('الحفظ', rating),
                    ],
                  ),
                  const Divider(
                      color: Colors.white30, thickness: 1, height: 30),

                  // Achievements Section
                  _buildSectionHeader('ما تم إنجازه', Icons.access_time),
                  const SizedBox(height: 16),
                  _buildLabelAndField('التسميع', report.tasmii),
                  _buildLabelAndField('التحفيظ', report.tahfiz),
                  _buildLabelAndField('المراجعة', report.mourajah),
                  const Divider(
                      color: Colors.white30, thickness: 1, height: 30),

                  // Next Achievement Section
                  _buildSectionHeader('الإنجاز القادم', Icons.calendar_month),
                  const SizedBox(height: 16),
                  _buildLabelAndField('التسميع', report.nextTasmii),
                  _buildLabelAndField('المراجعة', report.nextMourajah),
                  // Moved Notes here
                  if (report.notes.isNotEmpty)
                    _buildLabelAndField('ملاحظات', report.notes),

                  const Divider(
                      color: Colors.white30, thickness: 1, height: 30),

                  // Image Section "From Our Class"
                  if (report.zoomImageUrl.isNotEmpty) ...[
                    _buildSectionHeader('من حصتنا', Icons.image),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200, // Good height for image
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                        image: DecorationImage(
                          image: NetworkImage(report.zoomImageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // "Go to Top" Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white60),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_upward,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'اذهب للأعلى',
                                style: TextStyle(
                                  fontFamily: 'Qatar',
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add enough bottom padding to clear the floating nav bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: IslamicBottomNavBar(
        currentIndex: 1, // Achievements tab index (Index 1 based on map)
        onTap: (index) {
          Navigator.pop(context); // Return to dashboard
        },
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Main Pill
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'تقرير الحصة رقم ${report.sessionNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        // Folder Icon (Positioned Top Right relative to pill, or floating)
        // Image shows a folder icon floating on the top-left (RTL: top-right visually?)
        // Let's place it at the top-left of the container due to RTL text.
        // Folder Icon (Positioned Top Right relative to pill, or floating)
        Positioned(
          top: -15,
          right: 30, // RTL: Icon on Right
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: const Icon(
              Icons.folder_copy,
              size: 40,
              color: Color(0xFFF6C302),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6C302), // Gold
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF6C302).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // White Star/Icon badge (Right in RTL = First child)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: const Color(0xFFF6C302)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Qatar',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarColumn(String label, int rating) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Qatar',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              // RTL: index 0 is rightmost? No, Row lays out LTR by default unless localized.
              // Assuming Directionality is RTL in app.
              return Icon(
                Icons.star,
                size: 14,
                // Color filled for rating, grey/outlined for rest
                // Assuming rating 5 means 5 filled.
                color: index < rating
                    ? const Color(0xFFA01A36)
                    : const Color(0xFFD4AF37),
                // Wait, image shows RED stars on WHITE background?
                // The image shows filled red stars (dark red) and maybe yellow outlines?
                // Let's use the dark red from the background for filled stars.
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelAndField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label Section (Right in RTL - Physical Right)
            Container(
              width: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                // Border on Top, Right, Bottom only. Left open.
                border: const Border(
                  top: BorderSide(color: Colors.white, width: 1.5),
                  bottom: BorderSide(color: Colors.white, width: 1.5),
                  right: BorderSide(color: Colors.white, width: 1.5),
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Qatar',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // No spacing to ensure seamless connection

            // Value Section (Left in RTL - Physical Left)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                alignment: Alignment.centerRight, // RTL Text Alignment
                child: Text(
                  _getDisplayValue(value),
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayValue(String value) {
    return value.trim().isEmpty ? '' : value;
  }
}
