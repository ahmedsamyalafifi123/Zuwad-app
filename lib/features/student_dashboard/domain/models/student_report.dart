import 'dart:convert';
import 'package:flutter/foundation.dart';

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
    // Parse zoom image URL from array
    String imageUrl = '';
    if (json['zoomImageUrl'] != null) {
      try {
        if (json['zoomImageUrl'] is String) {
          final List<dynamic> images = jsonDecode(json['zoomImageUrl']);
          if (images.isNotEmpty) {
            imageUrl = images[0].toString().replaceAll(r'\\', '');
          }
        } else if (json['zoomImageUrl'] is List) {
          final List<dynamic> images = json['zoomImageUrl'];
          if (images.isNotEmpty) {
            imageUrl = images[0].toString().replaceAll(r'\\', '');
          }
        }
      } catch (e) {
        debugPrint('Error parsing zoomImageUrl: $e');
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
        debugPrint('Failed to parse $fieldName: $value');
        return 0;
      } catch (e) {
        debugPrint('Error parsing $fieldName: $e');
        return 0;
      }
    }

    return StudentReport(
      studentId: parseIntField(json['studentId'], 'studentId'),
      teacherId: parseIntField(json['teacherId'], 'teacherId'),
      teacherName: json['teacherName']?.toString() ?? '',
      sessionNumber: parseIntField(json['sessionNumber'], 'sessionNumber'),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      attendance: json['attendance']?.toString() ?? '',
      evaluation: json['evaluation']?.toString() ?? '',
      grade: parseIntField(json['grade'], 'grade'),
      lessonDuration: parseIntField(json['lessonDuration'], 'lessonDuration'),
      tasmii: json['tasmii']?.toString() ?? '',
      tahfiz: json['tahfiz']?.toString() ?? '',
      mourajah: json['mourajah']?.toString() ?? '',
      nextTasmii: json['nextTasmii']?.toString() ?? '',
      nextMourajah: json['nextMourajah']?.toString() ?? '',
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
