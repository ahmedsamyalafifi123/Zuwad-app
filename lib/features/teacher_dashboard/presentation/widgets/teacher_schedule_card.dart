import 'package:flutter/material.dart';
import '../../../student_dashboard/domain/models/schedule.dart';
import '../pages/teacher_schedules_page.dart';
import '../../domain/models/teacher_report.dart';

class TeacherScheduleCard extends StatelessWidget {
  final int studentId;
  final String studentName;
  final String? studentMId;
  final Schedule schedule;
  final String lessonDuration;
  final bool hasReport;
  final bool canAddReport;
  final LessonStatus lessonStatus;
  final TeacherReport? existingReport;
  final VoidCallback? onAddReport;

  const TeacherScheduleCard({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentMId,
    required this.schedule,
    required this.lessonDuration,
    this.hasReport = false,
    this.canAddReport = false,
    this.lessonStatus = LessonStatus.upcoming,
    this.existingReport,
    this.onAddReport,
  });

  void _showReportDetails(BuildContext context, TeacherReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ReportDetailsPage(
          report: report,
          studentName: studentName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (schedule.isPostponed) {
      statusColor = Colors.orange;
      statusText = 'مؤجل';
      statusIcon = Icons.event_busy;
    } else if (schedule.isTrial) {
      statusColor = Colors.blue;
      statusText = 'تجريبي';
      statusIcon = Icons.science;
    } else if (hasReport) {
      statusColor = Colors.green;
      statusText = 'مكتمل';
      statusIcon = Icons.check_circle;
    } else if (lessonStatus == LessonStatus.inProgress) {
      statusColor = const Color(0xFFD4AF37);
      statusText = 'جاري';
      statusIcon = Icons.access_time;
    } else if (lessonStatus == LessonStatus.ended) {
      statusColor = Colors.red;
      statusText = 'انتهى';
      statusIcon = Icons.timer_off;
    } else {
      statusColor = Colors.grey;
      statusText = 'قادم';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 230, 230, 230),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(140, 0, 0, 0),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (studentMId != null && studentMId!.isNotEmpty)
                        Text(
                          studentMId!,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    schedule.day,
                    style: const TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    schedule.hour,
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.timelapse,
                    size: 18,
                    color: Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$lessonDuration دقيقة',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (canAddReport && !hasReport && onAddReport != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddReport,
                  icon: const Icon(Icons.add_task, color: Colors.white),
                  label: const Text(
                    'إضافة تقرير',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF820c22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (hasReport && existingReport != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReportDetails(context, existingReport!),
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  label: const Text(
                    'عرض التقرير',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportDetailsPage extends StatelessWidget {
  final TeacherReport report;
  final String studentName;

  const _ReportDetailsPage({
    required this.report,
    required this.studentName,
  });

  int _calculateRating() {
    final evaluation = report.evaluation.toLowerCase().trim();

    if (evaluation.contains('ماهر')) return 5;
    if (evaluation.contains('محترف')) return 4;
    if (evaluation.contains('رائع')) return 3;
    if (evaluation.contains('متميز')) return 2;
    if (evaluation.contains('مجتهد')) return 1;

    if (evaluation.contains('ممتاز') || evaluation.contains('excellent'))
      return 5;
    if (evaluation.contains('جيد جدا') || evaluation.contains('very good'))
      return 4;
    if (evaluation.contains('جيد') || evaluation.contains('good')) return 3;
    if (evaluation.contains('مقبول') || evaluation.contains('fair')) return 2;
    if (evaluation.contains('ضعيف') || evaluation.contains('weak')) return 1;

    if (report.grade > 0) {
      if (report.grade <= 5) return report.grade;
      if (report.grade <= 10) return (report.grade / 2).ceil();
      if (report.grade <= 100) return (report.grade / 20).ceil();
    }

    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final int rating = _calculateRating();

    return Scaffold(
      backgroundColor: const Color(0xFF8b0628),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 234, 234, 234),
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
                  const Text(
                    'تقرير الدرس',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF8B0628), size: 28),
                      onPressed: () => Navigator.pop(context),
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
                  _buildSessionHeader(),
                  const SizedBox(height: 24),
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
                  _buildSectionHeader('ما تم إنجازه', Icons.access_time),
                  const SizedBox(height: 16),
                  _buildLabelAndField('الحضور', report.attendance),
                  _buildLabelAndField('التقييم', report.evaluation),
                  if (report.grade > 0)
                    _buildLabelAndField('الدرجة', '${report.grade}'),
                  _buildLabelAndField('التسميع', report.tasmii),
                  _buildLabelAndField('التحفيظ', report.tahfiz),
                  _buildLabelAndField('المراجعة', report.mourajah),
                  const Divider(
                      color: Colors.white30, thickness: 1, height: 30),
                  _buildSectionHeader('الإنجاز القادم', Icons.calendar_month),
                  const SizedBox(height: 16),
                  _buildLabelAndField('التسميع', report.nextTasmii),
                  _buildLabelAndField('المراجعة', report.nextMourajah),
                  if (report.notes.isNotEmpty)
                    _buildLabelAndField('ملاحظات', report.notes),
                  const Divider(
                      color: Colors.white30, thickness: 1, height: 30),
                  if (report.zoomImageUrl.isNotEmpty) ...[
                    _buildSectionHeader('من حصتنا', Icons.image),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
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
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
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
        Positioned(
          top: -15,
          right: 30,
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
          color: const Color(0xFFF6C302),
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
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(87, 0, 0, 0),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              if (index < rating) {
                return Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(Icons.star, size: 20, color: Colors.black),
                    Icon(Icons.star, size: 14, color: Color(0xFFF6C302)),
                  ],
                );
              }
              return const Icon(
                Icons.star,
                size: 16,
                color: Color(0xFF820c22),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelAndField(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 100,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white, width: 1.5),
                  bottom: BorderSide(color: Colors.white, width: 1.5),
                  right: BorderSide(color: Colors.white, width: 1.5),
                ),
                borderRadius: BorderRadius.only(
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
                alignment: Alignment.centerRight,
                child: Text(
                  value,
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
}
