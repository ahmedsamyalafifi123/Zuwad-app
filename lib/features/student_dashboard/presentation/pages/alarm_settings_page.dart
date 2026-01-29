import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/services/alarm_service.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../../../core/utils/timezone_helper.dart';
import '../../domain/models/schedule.dart';

class AlarmSettingsPage extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onSuccess;

  const AlarmSettingsPage({super.key, this.scrollController, this.onSuccess});

  @override
  State<AlarmSettingsPage> createState() => _AlarmSettingsPageState();
}

class AlarmTime {
  int hours;
  int minutes;

  AlarmTime({this.hours = 0, this.minutes = 15});
}

class _AlarmSettingsPageState extends State<AlarmSettingsPage> {
  List<AlarmTime> _alarmTimes = [];
  bool _repeatForAll = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final ScheduleRepository _scheduleRepository = ScheduleRepository();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBatteryOptimization();
  }

  /// Check if battery optimization is enabled and show dialog if needed
  Future<void> _checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      // Show dialog after a short delay to avoid interrupting the user immediately
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showBatteryOptimizationDialog();
        }
      });
    }
  }

  /// Show dialog requesting battery optimization exemption
  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'تفعيل المنبه في الخلفية',
            style: TextStyle(fontFamily: 'Qatar', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'للتأكد من عمل المنبهات حتى عند إغلاق التطبيق، يرجى السماح للتطبيق بالعمل في الخلفية وتعطيل توفير الطاقة للتطبيق.',
            style: TextStyle(fontFamily: 'Qatar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'لاحقاً',
                style: TextStyle(fontFamily: 'Qatar'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _requestBatteryOptimizationExemption();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8b0628),
              ),
              child: const Text(
                'إعدادات البطارية',
                style: TextStyle(
                  fontFamily: 'Qatar',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Request battery optimization exemption
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (!status.isGranted) {
        // Open app settings if user denied
        await openAppSettings();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting battery optimization exemption: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AlarmService.getMultipleAlarmSettings();
      if (mounted) {
        setState(() {
          // Load all alarm times from saved settings
          final alarmTimesList =
              settings['alarmTimes'] as List<Map<String, int>>? ?? [];
          if (alarmTimesList.isNotEmpty) {
            _alarmTimes = alarmTimesList
                .map(
                  (alarm) => AlarmTime(
                    hours: alarm['hours'] ?? 0,
                    minutes: alarm['minutes'] ?? 15,
                  ),
                )
                .toList();
          } else {
            _alarmTimes = [AlarmTime()];
          }
          _repeatForAll = settings['repeatForAll'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading alarm settings: $e');
      }
      if (mounted) {
        setState(() {
          _alarmTimes = [AlarmTime()];
          _isLoading = false;
        });
      }
    }
  }

  void _addAlarm() {
    setState(() {
      _alarmTimes.add(AlarmTime());
    });
  }

  void _removeAlarm(int index) async {
    setState(() {
      _alarmTimes.removeAt(index);
    });

    // If all alarms are removed, cancel all scheduled alarms
    if (_alarmTimes.isEmpty) {
      try {
        await AlarmService.cancelAllAlarms();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء جميع المنبهات')),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error canceling alarms: $e');
        }
      }
    }
  }

  Future<void> _saveAndScheduleAlarm() async {
    if (_alarmTimes.isEmpty) {
      _showErrorDialog('يجب إضافة منبه واحد على الأقل');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (kDebugMode) {
        print('AlarmSettings: Starting to save ${_alarmTimes.length} alarms');
      }

      // Save all alarm times
      final alarmTimesData = _alarmTimes
          .map((alarm) => {'hours': alarm.hours, 'minutes': alarm.minutes})
          .toList();

      await AlarmService.saveMultipleAlarmSettings(
        alarmTimes: alarmTimesData,
        repeatForAll: _repeatForAll,
      );

      if (kDebugMode) {
        print('AlarmSettings: Saved settings, cancelling existing alarms');
      }

      // Cancel all existing alarms
      await AlarmService.cancelAllAlarms();

      if (kDebugMode) {
        print('AlarmSettings: Getting student info');
      }

      // Get student info
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated || authState.student == null) {
        throw Exception('Student not authenticated');
      }

      final student = authState.student!;

      if (kDebugMode) {
        print('AlarmSettings: Student ID: ${student.id}, scheduling alarms');
      }

      // Schedule alarms for each configured time with timeout
      int totalScheduled = 0;
      for (int i = 0; i < _alarmTimes.length; i++) {
        final alarmTime = _alarmTimes[i];
        if (kDebugMode) {
          print(
            'AlarmSettings: Scheduling alarm ${i + 1}: ${alarmTime.hours}h ${alarmTime.minutes}m',
          );
        }

        try {
          // Add timeout to prevent hanging
          await Future.microtask(() async {
            if (_repeatForAll) {
              // Schedule alarms for all upcoming lessons
              await _scheduleAlarmsForAllLessons(
                student.id,
                alarmTime.hours,
                alarmTime.minutes,
              );
            } else {
              // Schedule alarm for next lesson only
              await _scheduleAlarmForNextLesson(
                student.id,
                alarmTime.hours,
                alarmTime.minutes,
              );
            }
          }).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Scheduling timed out after 10 seconds');
            },
          );
          totalScheduled++;
        } catch (e) {
          if (kDebugMode) {
            print('AlarmSettings: Error scheduling alarm ${i + 1}: $e');
          }
          // Continue with other alarms even if one fails
        }
      }

      if (kDebugMode) {
        print(
          'AlarmSettings: Successfully scheduled $totalScheduled/${_alarmTimes.length} alarms',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        if (totalScheduled > 0) {
          _showSuccessDialog();
        } else {
          _showErrorDialog('لم يتم جدولة أي منبه. تأكد من وجود حصص قادمة');
        }
        widget.onSuccess?.call();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AlarmSettings: Error saving alarm: $e');
        print('AlarmSettings: Stack trace: $stackTrace');
      }
      if (mounted) {
        _showErrorDialog('حدث خطأ أثناء حفظ المنبه: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _scheduleAlarmForNextLesson(
    int studentId,
    int hours,
    int minutes,
  ) async {
    try {
      if (kDebugMode) {
        print(
          'AlarmSettings: Getting schedules for student $studentId for next lesson alarm',
        );
      }

      final studentSchedules = await _scheduleRepository.getStudentSchedules(
        studentId,
      );

      if (kDebugMode) {
        print(
          'AlarmSettings: Retrieved ${studentSchedules.length} student schedules',
        );
      }

      if (studentSchedules.isEmpty) {
        if (kDebugMode) {
          print('AlarmSettings: No schedules found for student $studentId');
        }
        throw Exception('لا توجد حصص مجدولة');
      }

      final now = DateTime.now();
      Schedule? nextLesson;
      DateTime? nextLessonDateTime;

      // Iterate through all student schedules and their individual schedules
      for (final studentSchedule in studentSchedules) {
        for (final schedule in studentSchedule.schedules) {
          final lessonDateTime = _createLessonDateTime(schedule);
          if (lessonDateTime.isAfter(now)) {
            if (nextLessonDateTime == null ||
                lessonDateTime.isBefore(nextLessonDateTime)) {
              nextLesson = schedule;
              nextLessonDateTime = lessonDateTime;
            }
          }
        }
      }

      if (nextLesson != null && nextLessonDateTime != null) {
        final authState = context.read<AuthBloc>().state;
        final student = (authState as AuthAuthenticated).student!;

        await AlarmService.scheduleAlarm(
          lessonDateTime: nextLessonDateTime,
          hoursBeforeLesson: hours,
          minutesBeforeLesson: minutes,
          lessonName: student.displayLessonName,
          teacherName: student.teacherName ?? 'المعلم',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling alarm for next lesson: $e');
      }
      rethrow;
    }
  }

  Future<void> _scheduleAlarmsForAllLessons(
    int studentId,
    int hours,
    int minutes,
  ) async {
    try {
      final studentSchedules = await _scheduleRepository.getStudentSchedules(
        studentId,
      );
      if (studentSchedules.isEmpty) {
        throw Exception('لا توجد حصص مجدولة');
      }

      final now = DateTime.now();
      final authState = context.read<AuthBloc>().state;
      final student = (authState as AuthAuthenticated).student!;

      int scheduledCount = 0;
      // Iterate through all student schedules and their individual schedules
      for (final studentSchedule in studentSchedules) {
        for (final schedule in studentSchedule.schedules) {
          final lessonDateTime = _createLessonDateTime(schedule);
          if (lessonDateTime.isAfter(now)) {
            // Schedule alarm for this lesson
            final success = await AlarmService.scheduleAlarm(
              lessonDateTime: lessonDateTime,
              hoursBeforeLesson: hours,
              minutesBeforeLesson: minutes,
              lessonName: student.displayLessonName,
              teacherName: student.teacherName ?? 'المعلم',
            );
            if (success) {
              scheduledCount++;
            }
          }
        }
      }

      if (kDebugMode) {
        print('Scheduled $scheduledCount alarms for upcoming lessons');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling alarms for all lessons: $e');
      }
      rethrow;
    }
  }

  DateTime _createLessonDateTime(Schedule schedule) {
    final nowEgypt = TimezoneHelper.nowInEgypt();

    DateTime lessonDateTimeEgypt;

    if (schedule.isPostponed && schedule.postponedDate != null) {
      try {
        final postponedDate = DateTime.parse(schedule.postponedDate!);
        final scheduledTime = _parseTimeString(schedule.hour) ?? DateTime.now();
        lessonDateTimeEgypt = DateTime(
          postponedDate.year,
          postponedDate.month,
          postponedDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      } catch (e) {
        // Fall back to regular schedule
        lessonDateTimeEgypt = _calculateRegularLessonTime(schedule, nowEgypt);
      }
    } else {
      lessonDateTimeEgypt = _calculateRegularLessonTime(schedule, nowEgypt);
    }

    // Convert Egypt time to local timezone
    // Egypt is UTC+2, get the offset difference
    final egyptOffset = const Duration(hours: 2);
    final localOffset = DateTime.now().timeZoneOffset;
    final offsetDifference = localOffset - egyptOffset;

    // Add the offset difference to convert to local time
    final lessonDateTimeLocal = lessonDateTimeEgypt.add(offsetDifference);

    if (kDebugMode) {
      print('AlarmSettings: Egypt time: $lessonDateTimeEgypt');
      print('AlarmSettings: Local time: $lessonDateTimeLocal');
      print('AlarmSettings: Offset difference: $offsetDifference');
    }

    return lessonDateTimeLocal;
  }

  DateTime _calculateRegularLessonTime(Schedule schedule, DateTime nowEgypt) {
    final dayMap = {
      'الأحد': DateTime.sunday,
      'الاثنين': DateTime.monday,
      'الثلاثاء': DateTime.tuesday,
      'الأربعاء': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'الجمعة': DateTime.friday,
      'السبت': DateTime.saturday,
    };

    final scheduledDay = dayMap[schedule.day] ?? DateTime.sunday;
    final scheduledTime = _parseTimeString(schedule.hour) ?? DateTime.now();

    int daysUntil = (scheduledDay - nowEgypt.weekday) % 7;
    if (daysUntil == 0) {
      if (scheduledTime.hour < nowEgypt.hour ||
          (scheduledTime.hour == nowEgypt.hour &&
              scheduledTime.minute <= nowEgypt.minute)) {
        daysUntil = 7;
      }
    }

    return DateTime(
      nowEgypt.year,
      nowEgypt.month,
      nowEgypt.day + daysUntil,
      scheduledTime.hour,
      scheduledTime.minute,
    );
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      // Handle both "14:30" and "2:30 PM" formats
      timeString = timeString.trim();

      // Check if it's 12-hour format with AM/PM
      final isPM = timeString.toUpperCase().contains('PM');
      final isAM = timeString.toUpperCase().contains('AM');

      // Remove AM/PM if present
      String cleanTime =
          timeString.replaceAll(RegExp(r'[APMapm\s]+'), '').trim();

      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Convert 12-hour to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing time string "$timeString": $e');
      }
    }
    return null;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'تم الحفظ بنجاح',
            style: TextStyle(fontFamily: 'Qatar', fontWeight: FontWeight.bold),
          ),
          content: Text(
            _repeatForAll
                ? 'تم تفعيل ${_alarmTimes.length} منبه لجميع الحصص القادمة'
                : 'تم تفعيل ${_alarmTimes.length} منبه للحصة القادمة',
            style: const TextStyle(fontFamily: 'Qatar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Qatar')),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'خطأ',
            style: TextStyle(fontFamily: 'Qatar', fontWeight: FontWeight.bold),
          ),
          content: Text(message, style: const TextStyle(fontFamily: 'Qatar')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Qatar')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Drag Handle + Header Combined (matching postpone page)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF820C22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(123, 255, 255, 255),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'اعدادات المنبه',
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the close button
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8b0628)),
                  )
                : SingleChildScrollView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Description text
                        const Text(
                          'اختر موعد التنبيه قبل الحصة',
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Alarms list
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _alarmTimes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildAlarmTimeCard(index);
                          },
                        ),

                        // Repeat checkbox
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.fromARGB(255, 255, 255, 255),
                                Color.fromARGB(255, 234, 234, 234),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(50, 0, 0, 0),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _repeatForAll,
                                activeColor: const Color(0xFF8b0628),
                                onChanged: (value) {
                                  setState(() {
                                    _repeatForAll = value ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'تكرار التنبيه قبل جميع الحصص',
                                  style: TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons Row
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: _addAlarm,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 0, 0, 0),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 20,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'إضافة منبه آخر',
                                      style: TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Save button
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving ? null : _saveAndScheduleAlarm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8b0628),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'حفظ',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            // Add alarm button
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmTimeCard(int index) {
    final alarmTime = _alarmTimes[index];

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(50, 0, 0, 0),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold Divider / Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 250, 196, 13), // Gold
                  Color.fromARGB(255, 225, 175, 11), // Darker Gold
                ],
              ),
            ),
            child: Row(
              children: [
                Text(
                  'منبه ${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeAlarm(index),
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: Color.fromARGB(255, 112, 4, 4),
                  ), // White icon on gold bg
                  tooltip: 'حذف المنبه',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Hours
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ساعات',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color.fromARGB(255, 0, 0, 0),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: alarmTime.hours,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF8b0628),
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                items: List.generate(
                                  13, // 0 to 12
                                  (idx) => DropdownMenuItem(
                                    value: idx,
                                    child: Text('$idx'),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _alarmTimes[index].hours = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Minutes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'دقائق',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color.fromARGB(255, 0, 0, 0),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: alarmTime.minutes,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF8b0628),
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                items: [0, 5, 10, 15, 30, 45]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text('$value'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _alarmTimes[index].minutes = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
