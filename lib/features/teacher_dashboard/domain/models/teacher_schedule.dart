import 'package:flutter/foundation.dart';
import '../../../student_dashboard/domain/models/schedule.dart';

class TeacherSchedule {
  final int id;
  final int studentId;
  final String studentName;
  final String? studentMId;
  final int teacherId;
  final String teacherName;
  final String lessonDuration;
  final bool isPostponed;
  final bool isRecurring;
  final List<Schedule> schedules;

  const TeacherSchedule({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentMId,
    required this.teacherId,
    required this.teacherName,
    required this.lessonDuration,
    this.isPostponed = false,
    this.isRecurring = true,
    required this.schedules,
  });

  factory TeacherSchedule.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing TeacherSchedule from: $json');
    }

    List<Schedule> schedulesList = [];

    final rawSchedules = json['schedules'];
    if (rawSchedules != null && rawSchedules is List) {
      for (var item in rawSchedules) {
        try {
          if (item is Map<String, dynamic>) {
            schedulesList.add(Schedule.fromJson(item));
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing schedule item: $e');
          }
        }
      }
    }

    bool isPostponed = false;
    if (json['is_postponed'] != null) {
      isPostponed = json['is_postponed'] == true ||
          json['is_postponed'] == 1 ||
          json['is_postponed'] == '1';
    }

    bool isRecurring = true;
    if (json['is_recurring'] != null) {
      isRecurring = json['is_recurring'] == true ||
          json['is_recurring'] == 1 ||
          json['is_recurring'] == '1';
    }

    return TeacherSchedule(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      studentId: json['student_id'] is int
          ? json['student_id']
          : int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      studentName: json['student_name']?.toString() ?? '',
      studentMId: json['student_m_id']?.toString(),
      teacherId: json['teacher_id'] is int
          ? json['teacher_id']
          : int.tryParse(json['teacher_id']?.toString() ?? '0') ?? 0,
      teacherName: json['teacher_name']?.toString() ?? '',
      lessonDuration: json['lesson_duration']?.toString() ?? '30',
      isPostponed: isPostponed,
      isRecurring: isRecurring,
      schedules: schedulesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_m_id': studentMId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'lesson_duration': lessonDuration,
      'is_postponed': isPostponed,
      'is_recurring': isRecurring,
      'schedules': schedules.map((s) => s.toJson()).toList(),
    };
  }
}
