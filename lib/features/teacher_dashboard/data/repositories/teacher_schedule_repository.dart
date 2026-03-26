import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/teacher_schedule.dart';

class TeacherScheduleRepository {
  static const String _cacheKey = 'teacher_schedules_cache';
  static const String _cacheTimestampKey = 'teacher_schedules_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final WordPressApi _api = WordPressApi();

  Future<List<TeacherSchedule>> getTeacherSchedules(int teacherId,
      {bool forceRefresh = false}) async {
    try {
      if (kDebugMode) {
        print(
            'Getting schedules for teacher $teacherId (forceRefresh: $forceRefresh)');
      }

      if (!forceRefresh) {
        final cachedData = await _getCachedSchedules(teacherId);
        if (cachedData != null) {
          if (kDebugMode) {
            print('Using cached data for teacher $teacherId');
          }
          return cachedData;
        }
      }

      final data = await _api.getTeacherSchedules(teacherId);

      if (kDebugMode) {
        print('Received ${data.length} teacher schedules from API');
      }

      final schedules = data
          .map((json) => TeacherSchedule.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        print('Parsed ${schedules.length} teacher schedules');
      }

      await _cacheSchedules(teacherId, schedules);

      return schedules;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching teacher schedules: $e');
      }
      final cachedData = await _getCachedSchedules(teacherId);
      if (cachedData != null) {
        if (kDebugMode) {
          print('Falling back to cached data due to error');
        }
        return cachedData;
      }
      throw Exception('Error fetching teacher schedules: $e');
    }
  }

  Future<void> _cacheSchedules(
      int teacherId, List<TeacherSchedule> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$teacherId';

      final jsonData = schedules.map((s) => s.toJson()).toList();
      await prefs.setString(cacheKey, json.encode(jsonData));
      await prefs.setInt('$_cacheTimestampKey$teacherId',
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        print('Error caching teacher schedules: $e');
      }
    }
  }

  Future<List<TeacherSchedule>?> _getCachedSchedules(int teacherId) async {
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
          return data.map((json) => TeacherSchedule.fromJson(json)).toList();
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached teacher schedules: $e');
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
