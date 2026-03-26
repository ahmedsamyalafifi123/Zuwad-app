import 'package:flutter/material.dart';
import '../../../student_dashboard/domain/models/schedule.dart';

class TeacherScheduleCard extends StatelessWidget {
  final int studentId;
  final String studentName;
  final String? studentMId;
  final Schedule schedule;
  final String lessonDuration;
  final bool hasReport;
  final bool canAddReport;
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
    this.onAddReport,
  });

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
    } else if (canAddReport) {
      statusColor = const Color(0xFFD4AF37);
      statusText = 'جاري';
      statusIcon = Icons.access_time;
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
          ],
        ),
      ),
    );
  }
}
