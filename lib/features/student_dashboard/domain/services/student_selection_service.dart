import 'package:flutter/foundation.dart';
import '../../../auth/domain/models/student.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/schedule.dart';
import '../../domain/models/student_report.dart';
import '../../../../core/utils/timezone_helper.dart';

class StudentSelectionService {
  final ScheduleRepository _scheduleRepository;
  final ReportRepository _reportRepository;

  StudentSelectionService({
    ScheduleRepository? scheduleRepository,
    ReportRepository? reportRepository,
  })  : _scheduleRepository = scheduleRepository ?? ScheduleRepository(),
        _reportRepository = reportRepository ?? ReportRepository();

  /// Determines the best student to select based on who has the nearest upcoming lesson.
  /// Returns the passed list's optimal student, or the first one if unsure.
  Future<Student> determineBestStudent(List<Student> students) async {
    if (students.isEmpty) {
      throw Exception('Cannot determine best student from empty list');
    }
    if (students.length == 1) {
      return students.first;
    }

    if (kDebugMode) {
      print('Determining best student among ${students.length} candidates...');
    }

    Student bestStudent = students.first;
    DateTime? minNextLessonTime;

    // We want the smallest positive difference from now,
    // OR if a lesson is currently happening, that's the best one.
    // If all are in the past (shouldn't happen with correct logic), pick the one that ended most recently?
    // Actually, getNextLessonTime returns NULL if no upcoming lesson.
    // So we pick the one with the earliest non-null future lesson.

    final now = DateTime.now();

    for (final student in students) {
      try {
        if (kDebugMode) {
          print(
              'Checking schedule for student: ${student.name} (${student.id})');
        }

        final nextLesson = await _getNextLessonTime(student.id);

        if (nextLesson != null) {
          if (kDebugMode) {
            print('Student ${student.name} next lesson: $nextLesson');
          }

          if (minNextLessonTime == null) {
            minNextLessonTime = nextLesson;
            bestStudent = student;
          } else {
            if (nextLesson.isBefore(minNextLessonTime!)) {
              minNextLessonTime = nextLesson;
              bestStudent = student;
            }
          }
        } else {
          if (kDebugMode) {
            print('Student ${student.name} has no upcoming lessons');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking student ${student.name}: $e');
        }
      }
    }

    if (kDebugMode) {
      print(
          'Selected best student: ${bestStudent.name} with lesson at $minNextLessonTime');
    }

    return bestStudent;
  }

  /// Calculates the next lesson time for a student, replicating Dashboard logic.
  Future<DateTime?> _getNextLessonTime(int studentId) async {
    try {
      // 1. Get Schedules
      final nextSchedule = await _scheduleRepository.getNextSchedule(studentId);
      if (nextSchedule == null || nextSchedule.schedules.isEmpty) {
        return null;
      }

      // 2. Get Reports (to exclude finished lessons)
      final reports = await _reportRepository.getStudentReports(studentId);

      // 3. Logic from StudentDashboardPage._findNextLesson
      return _calculateUpcomingLesson(nextSchedule.schedules, reports);
    } catch (e) {
      if (kDebugMode) {
        print('Error in _getNextLessonTime for student $studentId: $e');
      }
      return null;
    }
  }

  DateTime? _calculateUpcomingLesson(
      List<Schedule> schedules, List<StudentReport> reports) {
    if (schedules.isEmpty) return null;

    final nowLocal = DateTime.now();
    final now = TimezoneHelper.localToEgypt(nowLocal);

    // Create a set of report keys
    final reportDateTimes = reports.map((r) {
      try {
        final date = DateTime.parse(r.date);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final timeStr = _normalizeTimeForComparison(r.time);
        return '$dateStr|$timeStr';
      } catch (e) {
        return '${r.date}|${r.time}';
      }
    }).toSet();

    List<DateTime> validLessonTimes = [];

    for (var schedule in schedules) {
      DateTime? lessonDateTime;
      String? lessonDateStr;

      if (schedule.isTrial && schedule.trialDate != null) {
        // Trial Lesson Logic
        try {
          DateTime? trialDateTime;
          if (schedule.trialDatetime != null) {
            trialDateTime = DateTime.tryParse(schedule.trialDatetime!);
          }
          if (trialDateTime == null) {
            final trialDate = DateTime.parse(schedule.trialDate!);
            final lessonTime = _parseTimeString(schedule.hour);
            if (lessonTime != null) {
              trialDateTime = DateTime(trialDate.year, trialDate.month,
                  trialDate.day, lessonTime.hour, lessonTime.minute);
            }
          }

          if (trialDateTime != null) {
            lessonDateStr =
                '${trialDateTime.year}-${trialDateTime.month.toString().padLeft(2, '0')}-${trialDateTime.day.toString().padLeft(2, '0')}';

            // Check report
            final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
            if (!reportDateTimes.contains('$lessonDateStr|$lessonTimeStr')) {
              lessonDateTime = trialDateTime;
            }
          }
        } catch (_) {}
      } else if (schedule.isPostponed && schedule.postponedDate != null) {
        // Postponed Logic
        try {
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          lessonDateStr =
              '${postponedDate.year}-${postponedDate.month.toString().padLeft(2, '0')}-${postponedDate.day.toString().padLeft(2, '0')}';

          final lessonTime = _parseTimeString(schedule.hour);
          if (lessonTime != null) {
            DateTime tentativeDate = DateTime(
                postponedDate.year,
                postponedDate.month,
                postponedDate.day,
                lessonTime.hour,
                lessonTime.minute);

            // Check report
            final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
            if (!reportDateTimes.contains('$lessonDateStr|$lessonTimeStr')) {
              lessonDateTime = tentativeDate;
            }
          }
        } catch (_) {}
      } else {
        // Regular Schedule Logic
        final dayMap = {
          'الأحد': DateTime.sunday,
          'الاثنين': DateTime.monday,
          'الثلاثاء': DateTime.tuesday,
          'الأربعاء': DateTime.wednesday,
          'الخميس': DateTime.thursday,
          'الجمعة': DateTime.friday,
          'السبت': DateTime.saturday,
        };

        final normalizedDay = _normalizeDay(schedule.day);
        final scheduledDay = dayMap[normalizedDay];
        if (scheduledDay == null) continue;

        final lessonTime = _parseTimeString(schedule.hour);
        if (lessonTime == null) continue;

        // Determine next instance
        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil == 0) {
          // If today, check if passed (allow 10 min window or similar logic? Dashboard uses generous check)
          // Dashboard logic: if (nowMinutes > lessonStart + duration + 10) -> next week
          // We will use strict start time for comparison simplicity for now, or match dashboard
          final lessonMinutes = lessonTime.hour * 60 + lessonTime.minute;
          final nowMinutes = now.hour * 60 + now.minute;
          // Assuming default 45 min duration + 10 buffer
          if (nowMinutes > lessonMinutes + 45 + 10) {
            daysUntil = 7;
          }
        }

        // Look ahead 8 weeks for a slot without report
        final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);

        for (int i = 0; i < 8; i++) {
          final candidate = DateTime(
              now.year,
              now.month,
              now.day + daysUntil + (i * 7),
              lessonTime.hour,
              lessonTime.minute);
          final dStr =
              '${candidate.year}-${candidate.month.toString().padLeft(2, '0')}-${candidate.day.toString().padLeft(2, '0')}';

          if (!reportDateTimes.contains('$dStr|$regularLessonTimeStr')) {
            lessonDateTime = candidate;
            break;
          }
        }
      }

      if (lessonDateTime != null) {
        // Check if it's in the future OR currently active (within window)
        // Dashboard allows showing it if we are within [Start, Start + Duration + 10]
        // Ideally we pick the one that is closest.
        // We will include it if it's after now OR if now is within the window.
        // But for sorting, we just want the DateTime.

        // Actually, we want to convert Egypt Time back to Local Time for the final comparison/return
        // But internal comparison should be consistent.
        // Let's keep it in Egypt time? No, the Service should probably return Local time for the app to use?
        // But for comparison, TimezoneHelper.egyptToLocal(lessonDateTime)

        // Valid if: lessonDateTime > now - durationBuffer
        // Let's just add it if it is "upcoming" (future) or "active".
        // Calculate end time
        final endTime =
            lessonDateTime.add(const Duration(minutes: 55)); // 45 + 10

        if (lessonDateTime.isAfter(now) || now.isBefore(endTime)) {
          validLessonTimes.add(lessonDateTime);
        }
      }
    }

    if (validLessonTimes.isEmpty) return null;

    // Sort to find the earliest one
    validLessonTimes.sort((a, b) => a.compareTo(b));

    // Return the first one (converted to local time for the caller)
    return TimezoneHelper.egyptToLocal(validLessonTimes.first);
  }

  // --- Helper Methods Copied/Adapted from Dashboard ---

  String _normalizeDay(String day) {
    switch (day.trim()) {
      case 'الاحد':
        return 'الأحد';
      case 'الإثنين':
        return 'الاثنين';
      case 'الاربعاء':
        return 'الأربعاء';
      case 'الجمعه':
        return 'الجمعة';
      default:
        return day.trim();
    }
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      final parts = timeString.trim().split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      final int minute = int.tryParse(timeParts[1]) ?? 0;
      String ampm = parts[1].toUpperCase();

      if (ampm == 'PM' && hour < 12)
        hour += 12;
      else if (ampm == 'AM' && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  String _normalizeTimeForComparison(String timeString) {
    try {
      final parsed = _parseTimeString(timeString);
      if (parsed != null) {
        return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return timeString;
    } catch (_) {
      return timeString;
    }
  }
}
