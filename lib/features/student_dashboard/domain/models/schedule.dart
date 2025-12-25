import 'dart:convert';
import 'package:flutter/foundation.dart';

class Schedule {
  final String day;
  final String hour;
  final Map<String, dynamic>? original;
  final bool isPostponed;
  final String? postponedDate;

  Schedule({
    required this.day,
    required this.hour,
    this.original,
    this.isPostponed = false,
    this.postponedDate,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // Debug the raw JSON
    if (kDebugMode) {
      print('Parsing schedule from: $json');
    }

    // Ensure day and hour are strings
    String day = '';
    if (json['day'] != null) {
      day = json['day'].toString();
    }

    String hour = '';
    if (json['hour'] != null) {
      hour = json['hour'].toString();
    }

    // Handle postponed fields
    bool isPostponed = false;
    if (json['is_postponed'] != null) {
      isPostponed = json['is_postponed'] == true ||
          json['is_postponed'] == 1 ||
          json['is_postponed'] == '1';
    }

    String? postponedDate;
    if (json['postponed_date'] != null) {
      postponedDate = json['postponed_date'].toString();
    }

    return Schedule(
      day: day,
      hour: hour,
      original: json['original'] != null
          ? (json['original'] is String
              ? jsonDecode(json['original'])
              : json['original'] as Map<String, dynamic>?)
          : null,
      isPostponed: isPostponed,
      postponedDate: postponedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'hour': hour,
      'original': original,
      'is_postponed': isPostponed,
      'postponed_date': postponedDate,
    };
  }
}

class StudentSchedule {
  final int studentId;
  final int teacherId;
  final String lessonDuration;
  final List<Schedule> schedules;
  final int isPostponed;

  StudentSchedule({
    required this.studentId,
    required this.teacherId,
    required this.lessonDuration,
    required this.schedules,
    this.isPostponed = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'teacher_id': teacherId,
      'lesson_duration': lessonDuration,
      'schedules': schedules.map((s) => s.toJson()).toList(),
      'is_postponed': isPostponed,
    };
  }

  factory StudentSchedule.fromJson(Map<String, dynamic> json) {
    // Debug the raw JSON
    if (kDebugMode) {
      print('-----------------------------------');
      print('Parsing student schedule from JSON:');
      print(json);
      print('-----------------------------------');
    }

    List<Schedule> schedulesList = [];

    // Special case: Look for direct schedule items in the JSON
    if (json.containsKey('day') && json.containsKey('hour')) {
      if (kDebugMode) {
        print('Found schedule data directly in the JSON');
      }
      try {
        schedulesList.add(Schedule.fromJson(json));
        if (kDebugMode) {
          print('Added direct schedule: ${json['day']} at ${json['hour']}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error adding direct schedule: $e');
        }
      }
    }

    // Try to get schedules from either 'schedules' or 'schedule' field
    var rawSchedules = json['schedules'];

    if (rawSchedules == null) {
      if (kDebugMode) {
        print('No "schedules" field found, checking for "schedule" field');
      }
      rawSchedules = json['schedule'];

      if (rawSchedules == null) {
        if (kDebugMode) {
          print('Neither "schedules" nor "schedule" field found in JSON');
        }
      }
    } else {
      if (kDebugMode) {
        print('Found "schedules" field type: ${rawSchedules.runtimeType}');
      }
    }

    // Process the schedules if we found them
    if (rawSchedules != null) {
      List<dynamic> scheduleItems = [];

      // Convert to list if it's a string
      if (rawSchedules is String) {
        try {
          var decoded = jsonDecode(rawSchedules);
          if (decoded is List) {
            scheduleItems = decoded;
            if (kDebugMode) {
              print(
                  'Successfully decoded schedules string to list with ${scheduleItems.length} items');
            }
          } else {
            if (kDebugMode) {
              print('Decoded schedules string is not a list: $decoded');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error decoding schedules string: $e');
          }

          // Try cleaning up the string
          String cleanedString = rawSchedules
              .toString()
              .replaceAll('\\"', '"')
              .replaceAll('\\\\', '\\');

          try {
            var decoded = jsonDecode(cleanedString);
            if (decoded is List) {
              scheduleItems = decoded;
              if (kDebugMode) {
                print('Successfully decoded cleaned schedules string to list');
              }
            } else {
              if (kDebugMode) {
                print('Cleaned decoded schedules string is not a list');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Still failed to decode cleaned string: $e');
            }
          }
        }
      } else if (rawSchedules is List) {
        scheduleItems = rawSchedules;
        if (kDebugMode) {
          print(
              'Schedules is already a list with ${scheduleItems.length} items');
        }
      } else {
        if (kDebugMode) {
          print(
              'Schedules is not a string or list: ${rawSchedules.runtimeType}');
        }
        // Try to extract a list from a potentially nested map
        try {
          if (rawSchedules is Map) {
            // Some APIs nest the actual list under a key
            for (var key in ['data', 'items', 'schedules', 'list']) {
              if (rawSchedules.containsKey(key) && rawSchedules[key] is List) {
                scheduleItems = rawSchedules[key];
                if (kDebugMode) {
                  print(
                      'Found nested list under key "$key" with ${scheduleItems.length} items');
                }
                break;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error trying to extract nested list: $e');
          }
        }
      }

      // Get parent-level postponed_date and is_postponed to pass to child schedules
      final parentPostponedDate = json['postponed_date'];
      final parentIsPostponed = json['is_postponed'] == true ||
          json['is_postponed'] == 1 ||
          json['is_postponed'] == '1';

      // Process each schedule item
      for (var item in scheduleItems) {
        try {
          if (kDebugMode) {
            print(
                'Processing schedule item type: ${item.runtimeType}, value: $item');
          }
          Map<String, dynamic> scheduleJson;

          if (item is String) {
            try {
              scheduleJson = jsonDecode(item);
              if (kDebugMode) {
                print('Decoded schedule item string to JSON');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error decoding schedule item string: $e');
              }
              continue;
            }
          } else if (item is Map) {
            scheduleJson = Map<String, dynamic>.from(item);
            if (kDebugMode) {
              print(
                  'Schedule item is a Map with keys: ${scheduleJson.keys.toList()}');
            }
          } else {
            if (kDebugMode) {
              print(
                  'Schedule item is not a string or map: ${item.runtimeType}');
            }
            continue;
          }

          if (scheduleJson.containsKey('day') &&
              scheduleJson.containsKey('hour')) {
            // IMPORTANT: Propagate parent-level postponed_date to child schedules
            // if the child doesn't have its own postponed_date
            if (parentPostponedDate != null &&
                scheduleJson['postponed_date'] == null) {
              scheduleJson['postponed_date'] = parentPostponedDate;
            }
            if (parentIsPostponed && scheduleJson['is_postponed'] == null) {
              scheduleJson['is_postponed'] = true;
            }

            schedulesList.add(Schedule.fromJson(scheduleJson));
            if (kDebugMode) {
              print(
                  'Added schedule: ${scheduleJson['day']} at ${scheduleJson['hour']}, '
                  'isPostponed: ${scheduleJson['is_postponed']}, postponedDate: ${scheduleJson['postponed_date']}');
            }
          } else {
            if (kDebugMode) {
              print('Schedule JSON missing required fields: $scheduleJson');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing schedule item: $e');
          }
        }
      }
    }

    if (kDebugMode) {
      print('Final schedules list has ${schedulesList.length} items');
    }

    // Parse student_id and teacher_id safely
    int studentId = 0;
    if (json['student_id'] != null) {
      if (json['student_id'] is String) {
        try {
          studentId = int.parse(json['student_id']);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing student_id: $e');
          }
        }
      } else if (json['student_id'] is int) {
        studentId = json['student_id'];
      }
    }

    int teacherId = 0;
    if (json['teacher_id'] != null) {
      if (json['teacher_id'] is String) {
        try {
          teacherId = int.parse(json['teacher_id']);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing teacher_id: $e');
          }
        }
      } else if (json['teacher_id'] is int) {
        teacherId = json['teacher_id'];
      }
    }

    String lessonDuration = '';
    if (json['lesson_duration'] != null) {
      lessonDuration = json['lesson_duration'].toString();
    }

    int isPostponed = 0;
    if (json['is_postponed'] != null) {
      if (json['is_postponed'] is String) {
        try {
          isPostponed = int.parse(json['is_postponed']);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing is_postponed: $e');
          }
        }
      } else if (json['is_postponed'] is int) {
        isPostponed = json['is_postponed'];
      }
    }

    return StudentSchedule(
      studentId: studentId,
      teacherId: teacherId,
      lessonDuration: lessonDuration,
      schedules: schedulesList,
      isPostponed: isPostponed,
    );
  }
}
