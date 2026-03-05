import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/student_event.dart';

/// Repository for managing student events
///
/// Features:
/// - Fetch events for a student
/// - Filter events by eligibility and time
/// - Get upcoming events only
class EventRepository {
  final WordPressApi _api = WordPressApi();

  /// Get all events for a student
  Future<List<StudentEvent>> getStudentEvents(int studentId) async {
    try {
      if (kDebugMode) {
        print('EventRepository.getStudentEvents - studentId: $studentId');
      }

      final data = await _api.getStudentEvents(studentId);

      if (data.isEmpty) {
        if (kDebugMode) {
          print('EventRepository.getStudentEvents - No events found');
        }
        return [];
      }

      final events = data
          .map((json) => StudentEvent.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        print(
            'EventRepository.getStudentEvents - Found ${events.length} events');
        for (var event in events) {
          print(
              '  - ${event.title}: ${event.datetime}, canJoin: ${event.canJoin}, isCountdown: ${event.isCountdown}');
        }
      }

      return events;
    } catch (e) {
      if (kDebugMode) {
        print('EventRepository.getStudentEvents - Error: $e');
      }
      return [];
    }
  }

  /// Get only upcoming events (not in the past)
  Future<List<StudentEvent>> getUpcomingEvents(int studentId) async {
    final events = await getStudentEvents(studentId);
    final now = DateTime.now();

    return events.where((event) {
      if (event.datetime.isEmpty) return false;
      try {
        final eventDateTime =
            DateTime.parse(event.datetime.replaceFirst(' ', 'T'));
        // Include events that haven't ended yet (add duration to start time)
        final eventEndTime =
            eventDateTime.add(Duration(minutes: event.duration));
        return eventEndTime.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Get the next upcoming event (the one closest to now)
  Future<StudentEvent?> getNextEvent(int studentId) async {
    final events = await getUpcomingEvents(studentId);

    if (events.isEmpty) return null;

    // Sort by datetime
    events.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.datetime.replaceFirst(' ', 'T'));
        final dateB = DateTime.parse(b.datetime.replaceFirst(' ', 'T'));
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    return events.first;
  }
}
