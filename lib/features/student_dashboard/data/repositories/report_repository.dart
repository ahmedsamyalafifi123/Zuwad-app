import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/models/student_report.dart';

class ReportRepository {
  static const String _cacheKey = 'student_reports_cache';
  static const String _cacheTimestampKey = 'student_reports_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<List<StudentReport>> getStudentReports(int studentId,
      {bool forceRefresh = false}) async {
    try {
      print(
          'Getting reports for student $studentId (forceRefresh: $forceRefresh)');

      // Check if we should use cached data
      if (!forceRefresh) {
        final cachedData = await _getCachedReports(studentId);
        if (cachedData != null) {
          print('Using cached reports for student $studentId');
          return cachedData;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('Error: Authentication token not found');
        throw Exception('Authentication token not found');
      }

      // Add timestamp to bust WordPress cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          '${ApiConstants.baseUrl}${ApiConstants.studentReportsEndpoint}?student_id=$studentId&_t=$timestamp';
      print('Making API request to: $url');
      print('Request headers: ${{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }}');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      print('API Response status: ${response.statusCode}');
      print('API Response headers: ${response.headers}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Decoded response data: $data');

        final reports = data.map((json) {
          print('Processing report: $json');
          return StudentReport.fromJson(json);
        }).toList();

        print('Created ${reports.length} StudentReport objects');

        // Cache the new data
        await _cacheReports(studentId, reports);
        print('Cached new reports for student $studentId');

        return reports;
      } else {
        print(
            'Error: Failed to load reports with status ${response.statusCode}');
        throw Exception('Failed to load reports: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching reports: $e');
      print('Stack trace: $stackTrace');
      // If there's an error, try to return cached data if available
      final cachedData = await _getCachedReports(studentId);
      if (cachedData != null) {
        print('Falling back to cached data due to error');
        return cachedData;
      }
      throw Exception('Error fetching reports: $e');
    }
  }

  Future<StudentReport?> getReportDetails(int studentId, String sessionNumber,
      {bool forceRefresh = false}) async {
    try {
      final reports =
          await getStudentReports(studentId, forceRefresh: forceRefresh);
      return reports.firstWhere(
          (report) => report.sessionNumber.toString() == sessionNumber);
    } catch (e) {
      print('Error in getReportDetails: $e');
      throw Exception('Error getting report details: $e');
    }
  }

  Future<void> _cacheReports(int studentId, List<StudentReport> reports) async {
    try {
      print('Caching reports for student $studentId');
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$studentId';

      final jsonData = reports.map((r) => r.toJson()).toList();
      print('Caching JSON data: $jsonData');

      await prefs.setString(cacheKey, json.encode(jsonData));
      await prefs.setInt('$_cacheTimestampKey$studentId',
          DateTime.now().millisecondsSinceEpoch);
      print('Successfully cached reports for student $studentId');
    } catch (e) {
      print('Error caching reports: $e');
      // Silently fail caching
    }
  }

  Future<List<StudentReport>?> _getCachedReports(int studentId) async {
    try {
      print('Checking cache for student $studentId');
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$studentId';
      final timestampKey = '$_cacheTimestampKey$studentId';

      final cachedData = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        print('Cache age: ${cacheAge / 1000} seconds');

        if (cacheAge < _cacheDuration.inMilliseconds) {
          print('Using valid cached data');
          final List<dynamic> data = json.decode(cachedData);
          return data.map((json) => StudentReport.fromJson(json)).toList();
        } else {
          print('Cache expired');
        }
      } else {
        print('No cached data found');
      }

      return null;
    } catch (e) {
      print('Error getting cached reports: $e');
      return null;
    }
  }
}
