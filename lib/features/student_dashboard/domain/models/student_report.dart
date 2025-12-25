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
  });

  factory StudentReport.fromJson(Map<String, dynamic> json) {
    // Parse zoom image URL from array - handle empty strings
    String imageUrl = '';
    final zoomData = json['zoomImageUrl'] ?? json['zoom_image_url'];
    if (zoomData != null && zoomData.toString().isNotEmpty) {
      try {
        if (zoomData is String) {
          // Skip if empty string
          if (zoomData.trim().isEmpty) {
            imageUrl = '';
          } else {
            final List<dynamic> images = jsonDecode(zoomData);
            if (images.isNotEmpty) {
              imageUrl = images[0].toString().replaceAll(r'\\', '');
            }
          }
        } else if (zoomData is List) {
          if (zoomData.isNotEmpty) {
            imageUrl = zoomData[0].toString().replaceAll(r'\\', '');
          }
        }
      } catch (e) {
        // Silently handle parsing errors for zoomImageUrl
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'sessionNumber': sessionNumber,
      'date': date,
      'time': time,
      'attendance': attendance,
      'evaluation': evaluation,
      'grade': grade,
      'lessonDuration': lessonDuration,
      'tasmii': tasmii,
      'tahfiz': tahfiz,
      'mourajah': mourajah,
      'nextTasmii': nextTasmii,
      'nextMourajah': nextMourajah,
      'notes': notes,
      'zoomImageUrl': zoomImageUrl,
    };
  }
}
