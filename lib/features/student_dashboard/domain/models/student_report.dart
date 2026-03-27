import 'dart:convert';

class StudentReport {
  final int studentId;
  final int teacherId;
  final String teacherName;
  final int sessionNumber;
  final String date;
  final String time;
  final String attendance;
  final String evaluation;
  final int grade;
  final int lessonDuration;
  final String tasmii;
  final String tahfiz;
  final String mourajah;
  final String nextTasmii;
  final String nextMourajah;
  final String notes;
  final String zoomImageUrl;
  final bool isPostponed;

  StudentReport({
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.sessionNumber,
    required this.date,
    required this.time,
    required this.attendance,
    required this.evaluation,
    required this.grade,
    required this.lessonDuration,
    required this.tasmii,
    required this.tahfiz,
    required this.mourajah,
    required this.nextTasmii,
    required this.nextMourajah,
    required this.notes,
    required this.zoomImageUrl,
    this.isPostponed = false,
  });

  factory StudentReport.fromJson(Map<String, dynamic> json) {
    // Parse zoom image URL from array - handle empty strings
    String imageUrl = '';
    final zoomData = json['zoom_image_url'] ?? json['zoomImageUrl'];
    if (zoomData != null && zoomData.toString().isNotEmpty) {
      try {
        if (zoomData is List) {
          if (zoomData.isNotEmpty) {
            imageUrl = zoomData[0].toString();
          }
        } else if (zoomData is String && zoomData.trim().isNotEmpty) {
          if (zoomData.trim().startsWith('[')) {
            final List<dynamic> images = jsonDecode(zoomData);
            if (images.isNotEmpty) {
              imageUrl = images[0].toString();
            }
          } else {
            imageUrl = zoomData;
          }
        }
      } catch (e) {
        imageUrl = '';
      }
    }

    // Handle integer fields that might come as strings
    int parseIntField(dynamic value, String fieldName) {
      try {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
        return 0;
      } catch (e) {
        return 0;
      }
    }

    // Support both camelCase (v1) and snake_case (v2) field names
    return StudentReport(
      studentId:
          parseIntField(json['studentId'] ?? json['student_id'], 'studentId'),
      teacherId:
          parseIntField(json['teacherId'] ?? json['teacher_id'], 'teacherId'),
      teacherName: json['teacherName']?.toString() ??
          json['teacher_name']?.toString() ??
          '',
      sessionNumber: parseIntField(
          json['sessionNumber'] ?? json['session_number'], 'sessionNumber'),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      attendance: json['attendance']?.toString() ?? '',
      evaluation: json['evaluation']?.toString() ?? '',
      grade: parseIntField(json['grade'], 'grade'),
      lessonDuration: parseIntField(
          json['lessonDuration'] ?? json['lesson_duration'], 'lessonDuration'),
      tasmii: json['tasmii']?.toString() ?? '',
      tahfiz: json['tahfiz']?.toString() ?? '',
      mourajah: json['mourajah']?.toString() ?? '',
      nextTasmii: json['nextTasmii']?.toString() ??
          json['next_tasmii']?.toString() ??
          '',
      nextMourajah: json['nextMourajah']?.toString() ??
          json['next_mourajah']?.toString() ??
          '',
      notes: json['notes']?.toString() ?? '',
      zoomImageUrl: imageUrl,
      isPostponed: json['isPostponed'] == true ||
          json['is_postponed'] == true ||
          json['isPostponed'] == 1 ||
          json['is_postponed'] == 1 ||
          json['isPostponed'] == '1' ||
          json['is_postponed'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'session_number': sessionNumber,
      'date': date,
      'time': time,
      'attendance': attendance,
      'evaluation': evaluation,
      'grade': grade,
      'lesson_duration': lessonDuration,
      'tasmii': tasmii,
      'tahfiz': tahfiz,
      'mourajah': mourajah,
      'next_tasmii': nextTasmii,
      'next_mourajah': nextMourajah,
      'notes': notes,
      'zoom_image_url': zoomImageUrl,
      'is_postponed': isPostponed,
    };
  }
}
