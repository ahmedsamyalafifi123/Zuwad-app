import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/models/teacher.dart';
import '../../domain/models/teacher_schedule.dart';
import '../../data/repositories/teacher_schedule_repository.dart';
import '../../data/repositories/teacher_report_repository.dart';
import '../widgets/teacher_schedule_card.dart';
import '../widgets/report_form_dialog.dart';
import '../../../student_dashboard/domain/models/schedule.dart';

class TeacherSchedulesPage extends StatefulWidget {
  final Teacher teacher;

  const TeacherSchedulesPage({super.key, required this.teacher});

  @override
  State<TeacherSchedulesPage> createState() => _TeacherSchedulesPageState();
}

class _TeacherSchedulesPageState extends State<TeacherSchedulesPage> {
  final TeacherScheduleRepository _scheduleRepo = TeacherScheduleRepository();
  final TeacherReportRepository _reportRepo = TeacherReportRepository();

  List<TeacherSchedule> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedules = await _scheduleRepo.getTeacherSchedules(
        widget.teacher.id,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading schedules: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في تحميل الجداول';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onAddReport(
    int studentId,
    String studentName,
    String date,
    String time,
    int lessonDuration,
  ) async {
    final sessionNumber = await _reportRepo.getSessionNumber(studentId, 'حضور');

    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportFormDialog(
        studentId: studentId,
        studentName: studentName,
        date: date,
        time: time,
        lessonDuration: lessonDuration,
        sessionNumber: sessionNumber,
        getSessionNumber: _reportRepo.getSessionNumber,
        onSubmit: ({
          required int studentId,
          required int teacherId,
          required String date,
          required String time,
          required String attendance,
          required int lessonDuration,
          int? sessionNumber,
          String? evaluation,
          int? grade,
          String? tasmii,
          String? tahfiz,
          String? mourajah,
          String? nextTasmii,
          String? nextMourajah,
          String? notes,
        }) async {
          await _reportRepo.createReport(
            studentId: studentId,
            teacherId: widget.teacher.id,
            date: date,
            time: time,
            attendance: attendance,
            lessonDuration: lessonDuration,
            sessionNumber: sessionNumber,
            evaluation: evaluation,
            grade: grade,
            tasmii: tasmii,
            tahfiz: tahfiz,
            mourajah: mourajah,
            nextTasmii: nextTasmii,
            nextMourajah: nextMourajah,
            notes: notes,
          );
        },
      ),
    );

    if (result == true) {
      _loadSchedules(forceRefresh: true);
    }
  }

  bool _canAddReport(Schedule schedule) {
    try {
      final now = DateTime.now();

      // Parse time from schedule (e.g., "2:00 PM")
      final timeParts = schedule.hour.trim().split(' ');
      if (timeParts.length != 2) return false;

      final hourMinute = timeParts[0].split(':');
      if (hourMinute.length != 2) return false;

      int hour = int.tryParse(hourMinute[0]) ?? 0;
      final int minute = int.tryParse(hourMinute[1]) ?? 0;
      final String ampm = timeParts[1].toUpperCase();

      // Convert to 24-hour format
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;

      // Get day of week from schedule
      final dayMap = {
        'الأحد': DateTime.sunday,
        'الاثنين': DateTime.monday,
        'الثلاثاء': DateTime.tuesday,
        'الأربعاء': DateTime.wednesday,
        'الخميس': DateTime.thursday,
        'الجمعة': DateTime.friday,
        'السبت': DateTime.saturday,
      };

      final scheduledDay = dayMap[schedule.day];
      if (scheduledDay == null) return false;

      // Check if today matches the scheduled day
      if (now.weekday != scheduledDay) return false;

      // Check if current time is within lesson window (15 min before until end)
      final scheduledTime =
          DateTime(now.year, now.month, now.day, hour, minute);
      final lessonEnd = scheduledTime.add(const Duration(minutes: 30));

      // Can add report from 15 min before lesson until lesson ends
      final windowStart = scheduledTime.subtract(const Duration(minutes: 15));

      return now.isAfter(windowStart) &&
          now.isBefore(lessonEnd.add(const Duration(minutes: 60)));
    } catch (e) {
      if (kDebugMode) {
        print('Error checking report window: $e');
      }
      return false;
    }
  }

  String _getDateForSchedule(Schedule schedule) {
    if (schedule.isPostponed && schedule.postponedDate != null) {
      return schedule.postponedDate!;
    }

    // Calculate next occurrence of this day
    final now = DateTime.now();
    final dayMap = {
      'الأحد': DateTime.sunday,
      'الاثنين': DateTime.monday,
      'الثلاثاء': DateTime.tuesday,
      'الأربعاء': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'الجمعة': DateTime.friday,
      'السبت': DateTime.saturday,
    };

    final scheduledDay = dayMap[schedule.day];
    if (scheduledDay == null) return '';

    int daysUntil = (scheduledDay - now.weekday) % 7;
    if (daysUntil < 0) daysUntil += 7;

    final nextLesson = now.add(Duration(days: daysUntil));
    return '${nextLesson.year}-${nextLesson.month.toString().padLeft(2, '0')}-${nextLesson.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD4AF37),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadSchedules(forceRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                  ),
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد جداول',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لم يتم العثور على جداول للطلاب',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter schedules for today and tomorrow only
    final now = DateTime.now();
    final tomorrowWeekday = (now.weekday % 7) + 1;

    // Map Dart weekday to Arabic day name for comparison
    final weekdayToArabic = {
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
    };

    final todayName = weekdayToArabic[now.weekday]!;
    final tomorrowName = weekdayToArabic[tomorrowWeekday]!;

    final List<Map<String, dynamic>> filteredSchedules = [];
    for (final schedule in _schedules) {
      for (final slot in schedule.schedules) {
        // Include only today's and tomorrow's schedules
        if (slot.day == todayName || slot.day == tomorrowName) {
          filteredSchedules.add({
            'teacherSchedule': schedule,
            'schedule': slot,
          });
        }
      }
    }

    // Sort by day (today first, then tomorrow) then by time
    filteredSchedules.sort((a, b) {
      final scheduleA = a['schedule'] as Schedule;
      final scheduleB = b['schedule'] as Schedule;

      // Today's schedules first
      final isTodayA = scheduleA.day == todayName;
      final isTodayB = scheduleB.day == todayName;

      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;

      // Same day, sort by time
      return scheduleA.hour.compareTo(scheduleB.hour);
    });

    // Calculate padding matching student dashboard
    final topPadding = MediaQuery.of(context).padding.top + 20.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    if (filteredSchedules.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد دروس اليوم أو غداً',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF8b0628),
        child: RefreshIndicator(
          onRefresh: () => _loadSchedules(forceRefresh: true),
          color: const Color(0xFFD4AF37),
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(8.0, topPadding, 8.0, bottomPadding),
            itemCount: filteredSchedules.length,
            itemBuilder: (context, index) {
              final item = filteredSchedules[index];
              final teacherSchedule =
                  item['teacherSchedule'] as TeacherSchedule;
              final schedule = item['schedule'] as Schedule;

              final canAddReport = _canAddReport(schedule);
              final date = _getDateForSchedule(schedule);

              return TeacherScheduleCard(
                studentId: teacherSchedule.studentId,
                studentName: teacherSchedule.studentName,
                studentMId: teacherSchedule.studentMId,
                schedule: schedule,
                lessonDuration: teacherSchedule.lessonDuration,
                canAddReport: canAddReport,
                hasReport: false,
                onAddReport: canAddReport
                    ? () => _onAddReport(
                          teacherSchedule.studentId,
                          teacherSchedule.studentName,
                          date,
                          schedule.hour,
                          int.tryParse(teacherSchedule.lessonDuration) ?? 30,
                        )
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}
