import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/models/schedule.dart';
import '../../domain/models/free_slot.dart';

class ScheduleRepository {
  static const String _cacheKey = 'student_schedules_cache';
  static const String _cacheTimestampKey = 'student_schedules_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<List<StudentSchedule>> getStudentSchedules(int studentId,
      {bool forceRefresh = false}) async {
    try {
      if (kDebugMode) {
        print(
            'Getting schedules for student $studentId (forceRefresh: $forceRefresh)');
      }

      // Check if we should use cached data
      if (!forceRefresh) {
        final cachedData = await _getCachedSchedules(studentId);
        if (cachedData != null) {
          if (kDebugMode) {
            print('Using cached data for student $studentId');
          }
          return cachedData;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Add timestamp to bust WordPress cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          '${ApiConstants.baseUrl}/wp-json/zuwad/v1/student-schedules?student_id=$studentId&_t=$timestamp';
      if (kDebugMode) {
        print('Making API request to: $url');
      }

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

      if (kDebugMode) {
        print('API Response status: ${response.statusCode}');
        print('API Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (kDebugMode) {
          print('Decoded response data: $data');
        }

        final schedules =
            data.map((json) => StudentSchedule.fromJson(json)).toList();
        if (kDebugMode) {
          print('Parsed schedules: ${schedules.length} items');
        }

        // Cache the new data
        await _cacheSchedules(studentId, schedules);
        if (kDebugMode) {
          print('Cached new schedules for student $studentId');
        }

        return schedules;
      } else {
        throw Exception('Failed to load schedules: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching schedules: $e');
      }
      // If there's an error, try to return cached data if available
      final cachedData = await _getCachedSchedules(studentId);
      if (cachedData != null) {
        if (kDebugMode) {
          print('Falling back to cached data due to error');
        }
        return cachedData;
      }
      throw Exception('Error fetching schedules: $e');
    }
  }

  Future<List<FreeSlot>> getTeacherFreeSlots(int teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url =
          '${ApiConstants.baseUrl}/wp-json/zuwad/v1/teacher-free-slots?teacher_id=$teacherId&_t=${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        print('Fetching teacher free slots from: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => FreeSlot.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load free slots: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching free slots: $e');
      }
      return [];
    }
  }

  Future<StudentSchedule?> getNextSchedule(int studentId,
      {bool forceRefresh = false}) async {
    try {
      final schedules =
          await getStudentSchedules(studentId, forceRefresh: forceRefresh);

      if (schedules.isEmpty) {
        return null;
      }

      // IMPORTANT FIX: Combine all schedules from all StudentSchedule objects
      // This ensures both regular and postponed schedules are included
      List<Schedule> allSchedules = [];
      StudentSchedule? baseSchedule;

      for (var schedule in schedules) {
        if (schedule.schedules.isNotEmpty) {
          // Use the first schedule as the base for metadata
          baseSchedule ??= schedule;
          // Add all schedules from this StudentSchedule object
          allSchedules.addAll(schedule.schedules);
        }
      }

      if (baseSchedule != null && allSchedules.isNotEmpty) {
        // Create a combined StudentSchedule with all schedules
        return StudentSchedule(
          studentId: baseSchedule.studentId,
          teacherId: baseSchedule.teacherId,
          lessonDuration: baseSchedule.lessonDuration,
          schedules: allSchedules,
          isPostponed: baseSchedule.isPostponed,
        );
      }

      return null;
    } catch (e) {
      throw Exception('Error getting next schedule: $e');
    }
  }

  Future<void> _cacheSchedules(
      int studentId, List<StudentSchedule> schedules) async {
    try {
      if (kDebugMode) {
        print('Caching schedules for student $studentId');
      }
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKey$studentId';

      final jsonData = schedules.map((s) => s.toJson()).toList();
      if (kDebugMode) {
        print('Caching JSON data: $jsonData');
      }

      await prefs.setString(cacheKey, json.encode(jsonData));
      await prefs.setInt('$_cacheTimestampKey$studentId',
          DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) {
        print('Successfully cached schedules for student $studentId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching schedules: $e');
      }
      // Silently fail caching
    }
  }

  Future<List<StudentSchedule>?> _getCachedSchedules(int studentId) async {
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
          return data.map((json) => StudentSchedule.fromJson(json)).toList();
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
        print('Error getting cached schedules: $e');
      }
      return null;
    }
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      // Parse time string like "2:00 PM"
      final parts = timeString.trim().split(' ');
      if (parts.length != 2) {
        if (kDebugMode) {
          print('Invalid time format: parts length is not 2');
        }
        return null;
      }

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) {
        if (kDebugMode) {
          print('Invalid time format: time parts length is not 2');
        }
        return null;
      }

      int hour = int.tryParse(timeParts[0]) ?? 0;
      final int minute = int.tryParse(timeParts[1]) ?? 0;

      // Adjust for AM/PM
      String ampm = parts[1].toUpperCase();
      if (ampm == 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing time string: $e');
      }
      return null;
    }
  }

  Duration? getTimeUntilNextLesson(Schedule schedule) {
    try {
      final now = DateTime.now();
      DateTime? nextLesson;

      if (schedule.isPostponed && schedule.postponedDate != null) {
        // Handle postponed schedules with specific dates
        try {
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          final scheduledTime = _parseTimeString(schedule.hour);
          if (scheduledTime != null) {
            nextLesson = DateTime(
              postponedDate.year,
              postponedDate.month,
              postponedDate.day,
              scheduledTime.hour,
              scheduledTime.minute,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing postponed date: $e');
          }
          return null;
        }
      } else {
        // Handle regular recurring schedules
        final dayMap = {
          'الأحد': DateTime.sunday,
          'الاثنين': DateTime.monday,
          'الثلاثاء': DateTime.tuesday,
          'الأربعاء': DateTime.wednesday,
          'الخميس': DateTime.thursday,
          'الجمعة': DateTime.friday,
          'السبت': DateTime.saturday,
        };

        final scheduledDay = dayMap[schedule.day];
        if (scheduledDay == null) {
          if (kDebugMode) {
            print('Unknown day: ${schedule.day}');
          }
          return null;
        }

        final scheduledTime = _parseTimeString(schedule.hour);
        if (scheduledTime == null) {
          if (kDebugMode) {
            print('Failed to parse time: ${schedule.hour}');
          }
          return null;
        }

        // Calculate days until the scheduled day
        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil == 0) {
          // If it's today, check if the time has already passed
          if (scheduledTime.hour < now.hour ||
              (scheduledTime.hour == now.hour &&
                  scheduledTime.minute <= now.minute)) {
            // If time has passed, schedule is for next week
            daysUntil = 7;
          }
        }

        // Create DateTime for the next scheduled lesson
        nextLesson = DateTime(
          now.year,
          now.month,
          now.day + daysUntil,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      }

      if (nextLesson != null && nextLesson.isAfter(now)) {
        return nextLesson.difference(now);
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating time until next lesson: $e');
      }
      return null;
    }
  }
}
