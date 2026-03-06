import 'package:flutter/foundation.dart';
import '../../../../core/utils/timezone_helper.dart';

/// Student Event Model
/// Represents an event that a student can participate in
class StudentEvent {
  final int id;
  final String title;
  final String date;
  final String time;
  final String datetime;
  final int duration;
  final String roomName;
  final String roomUrl;
  final int minutesUntil;
  final bool canJoin;
  final bool isCountdown;
  final bool isEvent;
  final int teacherId;
  final String teacherName;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaFilename;

  StudentEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.datetime,
    required this.duration,
    required this.roomName,
    required this.roomUrl,
    required this.minutesUntil,
    required this.canJoin,
    required this.isCountdown,
    required this.isEvent,
    required this.teacherId,
    required this.teacherName,
    this.mediaUrl,
    this.mediaType,
    this.mediaFilename,
  });

  factory StudentEvent.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing StudentEvent from: $json');
    }

    return StudentEvent(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      datetime: json['datetime'] ?? '',
      duration: json['duration'] ?? 0,
      roomName: json['room_name'] ?? '',
      roomUrl: json['room_url'] ?? '',
      minutesUntil: json['minutes_until'] ?? 0,
      canJoin: json['can_join'] == true ||
          json['can_join'] == 1 ||
          json['can_join'] == '1',
      isCountdown: json['is_countdown'] == true ||
          json['is_countdown'] == 1 ||
          json['is_countdown'] == '1',
      isEvent: json['is_event'] == true ||
          json['is_event'] == 1 ||
          json['is_event'] == '1',
      teacherId: json['teacher_id'] ?? 0,
      teacherName: json['teacher_name'] ?? '',
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaFilename: json['media_filename'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'datetime': datetime,
      'duration': duration,
      'room_name': roomName,
      'room_url': roomUrl,
      'minutes_until': minutesUntil,
      'can_join': canJoin,
      'is_countdown': isCountdown,
      'is_event': isEvent,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_filename': mediaFilename,
    };
  }

  /// Check if event is in the past
  bool get isPast {
    if (datetime.isEmpty) return false;
    try {
      // API returns Egypt time — convert to UTC before comparing with now
      final egyptDateTime = DateTime.parse(datetime.replaceFirst(' ', 'T'));
      final eventUtc = TimezoneHelper.egyptToUtc(egyptDateTime);
      return eventUtc.isBefore(DateTime.now().toUtc());
    } catch (e) {
      return false;
    }
  }

  /// Get the DateTime object from datetime string
  DateTime? get eventDateTime {
    if (datetime.isEmpty) return null;
    try {
      return DateTime.parse(datetime.replaceFirst(' ', 'T'));
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'StudentEvent(id: $id, title: $title, datetime: $datetime, canJoin: $canJoin)';
  }
}
