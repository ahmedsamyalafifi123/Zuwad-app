import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/models/teacher_report.dart';

class TeacherReportRepository {
  static const String _cacheKey = 'teacher_reports_cache';
  static const String _cacheTimestampKey = 'teacher_reports_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final WordPressApi _api = WordPressApi();

  Future<List<TeacherReport>> getTeacherReports(
    int teacherId, {
    String? startDate,
    String? endDate,
    bool forceRefresh = false,
  }) async {
    try {
      if (kDebugMode) {
        print(
            'Getting reports for teacher $teacherId (forceRefresh: $forceRefresh)');
      }

      if (!forceRefresh && startDate == null && endDate == null) {
        final cachedData = await _getCachedReports(teacherId);
        if (cachedData != null) {
          if (kDebugMode) {
            print('Using cached reports for teacher $teacherId');
          }
          return cachedData;
        }
      }

      final data = await _api.getTeacherReports(
        teacherId,
        startDate: startDate,
        endDate: endDate,
      );

      if (kDebugMode) {
        print('Received ${data.length} teacher reports from API');
      }

      final reports = data
          .map((json) => TeacherReport.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        print('Parsed ${reports.length} teacher reports');
      }

      if (startDate == null && endDate == null) {
        await _cacheReports(teacherId, reports);
      }

      return reports;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching teacher reports: $e');
      }
      final cachedData = await _getCachedReports(teacherId);
      if (cachedData != null) {
        if (kDebugMode) {
          print('Falling back to cached data due to error');
        }
        return cachedData;
      }
      throw Exception('Error fetching teacher reports: $e');
    }
  }

  Future<Map<String, dynamic>> createReport({
    required int studentId,
    required int teacherId,
    required String date,
    required String time,
    required String attendance,
    required int lessonDuration,
    int? sessionNumber,
    String? evaluation,
    String? tasmii,
    String? tahfiz,
    String? mourajah,
    String? nextTasmii,
    String? nextMourajah,
    String? notes,
    String? zoomImageUrl,
  }) async {
    try {
      if (kDebugMode) {
        print('Creating report for student $studentId');
      }

      final result = await _api.createStudentReport(
        studentId: studentId,
        teacherId: teacherId,
        attendance: attendance,
        date: date,
        lessonDuration: lessonDuration,
        time: time,
        sessionNumber: sessionNumber?.toString(),
        evaluation: evaluation,
        tasmii: tasmii,
        tahfiz: tahfiz,
        mourajah: mourajah,
        nextTasmii: nextTasmii,
        nextMourajah: nextMourajah,
        notes: notes,
        zoomImageUrl: zoomImageUrl,
      );

      if (kDebugMode) {
        print('Report created successfully');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating report: $e');
      }
      throw Exception('Error creating report: $e');
    }
  }

  Future<String?> uploadReportImage(File imageFile) async {
    try {
      if (kDebugMode) {
        print('TeacherReportRepository: Uploading report image...');
        print('Image path: ${imageFile.path}');
      }

      final imageUrl = await _api.uploadReportImage(imageFile.path);

      if (kDebugMode) {
        print(
            'TeacherReportRepository: Image uploaded successfully: $imageUrl');
      }

      return imageUrl;
    } catch (e) {
      if (kDebugMode) {
        print('TeacherReportRepository: Error uploading report image: $e');
      }
      return null;
    }
  }

  Future<int> getSessionNumber(int studentId, String attendance) async {
    try {
      final result = await _api.getSessionNumber(
        studentId: studentId,
        attendance: attendance,
      );
      return result['session_number'] ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting session number: $e');
      }
      return 0;
    }
  }

  Future<void> _cacheReports(int teacherId, List<TeacherReport> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$teacherId';

      final jsonData = reports.map((r) => r.toJson()).toList();
      await prefs.setString(cacheKey, json.encode(jsonData));
      await prefs.setInt('$_cacheTimestampKey$teacherId',
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        print('Error caching teacher reports: $e');
      }
    }
  }

  Future<List<TeacherReport>?> _getCachedReports(int teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$teacherId';
      final timestampKey = '$_cacheTimestampKey$teacherId';

      final cachedData = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

        if (cacheAge < _cacheDuration.inMilliseconds) {
          final List<dynamic> data = json.decode(cachedData);
          return data.map((json) => TeacherReport.fromJson(json)).toList();
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached teacher reports: $e');
      }
      return null;
    }
  }

  Future<void> clearCache(int teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKey$teacherId');
      await prefs.remove('$_cacheTimestampKey$teacherId');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }
}
