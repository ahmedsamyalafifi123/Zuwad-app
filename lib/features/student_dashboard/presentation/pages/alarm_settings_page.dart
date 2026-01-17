import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/services/alarm_service.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../../../core/utils/timezone_helper.dart';
import '../../domain/models/schedule.dart';

class AlarmSettingsPage extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onSuccess;

  const AlarmSettingsPage({
    super.key,
    this.scrollController,
    this.onSuccess,
  });

  @override
  State<AlarmSettingsPage> createState() => _AlarmSettingsPageState();
}

class _AlarmSettingsPageState extends State<AlarmSettingsPage> {
  int _selectedHours = 0;
  int _selectedMinutes = 15;
  bool _repeatForAll = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final ScheduleRepository _scheduleRepository = ScheduleRepository();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AlarmService.getAlarmSettings();
      if (mounted) {
        setState(() {
          _selectedHours = settings['hours'] ?? 0;
          _selectedMinutes = settings['minutes'] ?? 15;
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
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAndScheduleAlarm() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Save settings
      await AlarmService.saveAlarmSettings(
        enabled: true,
        hours: _selectedHours,
        minutes: _selectedMinutes,
        repeatForAll: _repeatForAll,
      );

      // Cancel all existing alarms
      await AlarmService.cancelAllAlarms();

      // Get student info
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated || authState.student == null) {
        throw Exception('Student not authenticated');
      }

      final student = authState.student!;

      if (_repeatForAll) {
        // Schedule alarms for all upcoming lessons
        await _scheduleAlarmsForAllLessons(student.id);
      } else {
        // Schedule alarm for next lesson only
        await _scheduleAlarmForNextLesson(student.id);
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving alarm: $e');
      }
      if (mounted) {
        _showErrorDialog('حدث خطأ أثناء حفظ المنبه');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _scheduleAlarmForNextLesson(int studentId) async {
    try {
      final studentSchedules =
          await _scheduleRepository.getStudentSchedules(studentId);
      if (studentSchedules.isEmpty) {
        throw Exception('لا توجد حصص مجدولة');
      }

      final now = TimezoneHelper.nowInEgypt();
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
          hoursBeforeLesson: _selectedHours,
          minutesBeforeLesson: _selectedMinutes,
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

  Future<void> _scheduleAlarmsForAllLessons(int studentId) async {
    try {
      final studentSchedules =
          await _scheduleRepository.getStudentSchedules(studentId);
      if (studentSchedules.isEmpty) {
        throw Exception('لا توجد حصص مجدولة');
      }

      final now = TimezoneHelper.nowInEgypt();
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
              hoursBeforeLesson: _selectedHours,
              minutesBeforeLesson: _selectedMinutes,
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
    final now = TimezoneHelper.nowInEgypt();

    if (schedule.isPostponed && schedule.postponedDate != null) {
      try {
        final postponedDate = DateTime.parse(schedule.postponedDate!);
        final scheduledTime = _parseTimeString(schedule.hour) ?? DateTime.now();
        return DateTime(
          postponedDate.year,
          postponedDate.month,
          postponedDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      } catch (e) {
        // Fall back to regular schedule
      }
    }

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

    int daysUntil = (scheduledDay - now.weekday) % 7;
    if (daysUntil == 0) {
      if (scheduledTime.hour < now.hour ||
          (scheduledTime.hour == now.hour &&
              scheduledTime.minute <= now.minute)) {
        daysUntil = 7;
      }
    }

    return DateTime(
      now.year,
      now.month,
      now.day + daysUntil,
      scheduledTime.hour,
      scheduledTime.minute,
    );
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing time string: $e');
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
                ? 'تم تفعيل المنبه لجميع الحصص القادمة'
                : 'تم تفعيل المنبه للحصة القادمة',
            style: const TextStyle(fontFamily: 'Qatar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'حسناً',
                style: TextStyle(fontFamily: 'Qatar'),
              ),
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
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Qatar'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'حسناً',
                style: TextStyle(fontFamily: 'Qatar'),
              ),
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
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 230, 230, 230),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8b0628),
                ),
              )
            : SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    const Text(
                      'منبه قبل الحصة',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8b0628),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اختر موعد التنبيه قبل الحصة',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Time selection section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'وقت التنبيه',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFD4AF37),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _selectedHours,
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
                                            24,
                                            (index) => DropdownMenuItem(
                                              value: index,
                                              child: Text('$index'),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _selectedHours = value;
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
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFD4AF37),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _selectedMinutes,
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
                                              .map((value) => DropdownMenuItem(
                                                    value: value,
                                                    child: Text('$value'),
                                                  ))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _selectedMinutes = value;
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
                    const SizedBox(height: 24),

                    // Repeat checkbox
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndScheduleAlarm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8b0628),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'حفظ',
                                style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
