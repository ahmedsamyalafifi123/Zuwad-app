import 'dart:convert';

class TeacherReport {
  final int id;
  final int studentId;
  final String studentName;
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
  final DateTime? createdAt;

  const TeacherReport({
    required this.id,
    required this.studentId,
    required this.studentName,
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
    this.createdAt,
  });

  factory TeacherReport.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    final zoomData = json['zoomImageUrl'] ?? json['zoom_image_url'];
    if (zoomData != null && zoomData.toString().isNotEmpty) {
      try {
        if (zoomData is String) {
          if (zoomData.trim().isNotEmpty) {
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
        imageUrl = '';
      }
    }

    int parseIntField(dynamic value) {
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

    DateTime? createdAt;
    if (json['created_at'] != null) {
      try {
        createdAt = DateTime.parse(json['created_at'].toString());
      } catch (e) {
        createdAt = null;
      }
    }

    return TeacherReport(
      id: parseIntField(json['id']),
      studentId: parseIntField(json['student_id']),
      studentName: json['student_name']?.toString() ?? '',
      teacherId: parseIntField(json['teacher_id']),
      teacherName: json['teacher_name']?.toString() ?? '',
      sessionNumber: parseIntField(json['session_number']),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      attendance: json['attendance']?.toString() ?? '',
      evaluation: json['evaluation']?.toString() ?? '',
      grade: parseIntField(json['grade']),
      lessonDuration: parseIntField(json['lesson_duration']),
      tasmii: json['tasmii']?.toString() ?? '',
      tahfiz: json['tahfiz']?.toString() ?? '',
      mourajah: json['mourajah']?.toString() ?? '',
      nextTasmii: json['next_tasmii']?.toString() ?? '',
      nextMourajah: json['next_mourajah']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      zoomImageUrl: imageUrl,
      isPostponed: json['is_postponed'] == true ||
          json['is_postponed'] == 1 ||
          json['is_postponed'] == '1',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
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
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
