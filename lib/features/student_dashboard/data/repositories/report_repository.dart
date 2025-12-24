import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/student_report.dart';

/// Repository for fetching student reports using API v2.
class ReportRepository {
  static const String _cacheKey = 'student_reports_cache';
  static const String _cacheTimestampKey = 'student_reports_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final WordPressApi _api = WordPressApi();

  /// Get all reports for a student.
  Future<List<StudentReport>> getStudentReports(int studentId,
      {bool forceRefresh = false}) async {
    try {
      if (kDebugMode) {
        print(
            'Getting reports for student $studentId (forceRefresh: $forceRefresh)');
      }

      // Check if we should use cached data
      if (!forceRefresh) {
        final cachedData = await _getCachedReports(studentId);
        if (cachedData != null) {
          if (kDebugMode) {
            print('Using cached reports for student $studentId');
          }
          return cachedData;
        }
      }

      // Fetch from API v2
      final data = await _api.getStudentReports(studentId);

      if (kDebugMode) {
        print('Received ${data.length} reports from API');
      }

      final reports = data.map((json) {
        if (kDebugMode) {
          print('Processing report: $json');
        }
        return StudentReport.fromJson(json as Map<String, dynamic>);
      }).toList();

      if (kDebugMode) {
        print('Created ${reports.length} StudentReport objects');
      }

      // Cache the new data
      await _cacheReports(studentId, reports);
      if (kDebugMode) {
        print('Cached new reports for student $studentId');
      }

      return reports;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching reports: $e');
        print('Stack trace: $stackTrace');
      }
      // If there's an error, try to return cached data if available
      final cachedData = await _getCachedReports(studentId);
      if (cachedData != null) {
        if (kDebugMode) {
          print('Falling back to cached data due to error');
        }
        return cachedData;
      }
      throw Exception('Error fetching reports: $e');
    }
  }

  /// Get details for a specific report by session number.
  Future<StudentReport?> getReportDetails(int studentId, String sessionNumber,
      {bool forceRefresh = false}) async {
    try {
      final reports =
          await getStudentReports(studentId, forceRefresh: forceRefresh);
      return reports.firstWhere(
          (report) => report.sessionNumber.toString() == sessionNumber);
    } catch (e) {
      if (kDebugMode) {
        print('Error in getReportDetails: $e');
      }
      throw Exception('Error getting report details: $e');
    }
  }

  /// Cache reports to SharedPreferences.
  Future<void> _cacheReports(int studentId, List<StudentReport> reports) async {
    try {
      if (kDebugMode) {
        print('Caching reports for student $studentId');
      }
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$studentId';

      final jsonData = reports.map((r) => r.toJson()).toList();
      if (kDebugMode) {
        print('Caching JSON data: $jsonData');
      }

      await prefs.setString(cacheKey, json.encode(jsonData));
      await prefs.setInt('$_cacheTimestampKey$studentId',
          DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) {
        print('Successfully cached reports for student $studentId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching reports: $e');
      }
      // Silently fail caching
    }
  }

  /// Get cached reports if valid.
  Future<List<StudentReport>?> _getCachedReports(int studentId) async {
    try {
      if (kDebugMode) {
        print('Checking cache for student $studentId');
      }
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$studentId';
      final timestampKey = '$_cacheTimestampKey$studentId';

      final cachedData = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (kDebugMode) {
          print('Cache age: ${cacheAge / 1000} seconds');
        }

        if (cacheAge < _cacheDuration.inMilliseconds) {
          if (kDebugMode) {
            print('Using valid cached data');
          }
          final List<dynamic> data = json.decode(cachedData);
          return data.map((json) => StudentReport.fromJson(json)).toList();
        } else {
          if (kDebugMode) {
            print('Cache expired');
          }
        }
      } else {
        if (kDebugMode) {
          print('No cached data found');
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached reports: $e');
      }
      return null;
    }
  }

  /// Clear cached reports for a student.
  Future<void> clearCache(int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKey$studentId');
      await prefs.remove('$_cacheTimestampKey$studentId');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }
}
