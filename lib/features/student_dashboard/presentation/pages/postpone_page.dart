import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuwad/core/utils/gender_helper.dart';
import '../../domain/models/free_slot.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

import '../../../../core/utils/timezone_helper.dart';

class PostponePage extends StatefulWidget {
  final int teacherId;
  final List<FreeSlot> freeSlots;
  final int studentLessonDuration;
  final String? currentLessonDay;
  final String? currentLessonTime;
  final String? currentLessonDate;
  final ScrollController? scrollController;
  final Function? onSuccess;
  final String? teacherGender;

  const PostponePage({
    super.key,
    required this.teacherId,
    required this.freeSlots,
    required this.studentLessonDuration,
    this.currentLessonDay,
    this.currentLessonTime,
    this.currentLessonDate,
    this.scrollController,
    this.onSuccess,
    this.teacherGender,
  });

  @override
  State<PostponePage> createState() => _PostponePageState();
}

class _PostponePageState extends State<PostponePage> {
  int? _selectedDayOfWeek;
  String? _selectedStartTime;
  bool _isCreatingEvent = false;
  final WordPressApi _api = WordPressApi();
  List<ConvertedSlot> _convertedSlots = [];

  @override
  void initState() {
    super.initState();
    _initializeConvertedSlots();
  }

  void _initializeConvertedSlots() {
    final now = TimezoneHelper.nowInEgypt();
    _convertedSlots = widget.freeSlots
        .map((slot) {
          // 1. Determine date of next occurrence in Egypt time
          // Server days: 0=Sunday, 1=Monday... 6=Saturday
          // Date.weekday: 1=Monday... 7=Sunday

          // key: Map server day (0-6) to Dart weekday (1-7)
          final serverDayToDart = slot.dayOfWeek == 0 ? 7 : slot.dayOfWeek;

          int daysUntil = (serverDayToDart - now.weekday + 7) % 7;
          if (daysUntil == 0) daysUntil = 7; // Next occurrence

          final egyptDate = now.add(Duration(days: daysUntil));

          // Parse times
          final startParts = slot.startTime.split(':');
          final endParts = slot.endTime.split(':');

          if (startParts.length < 2 || endParts.length < 2) return null;

          final egyptStart = DateTime(
            egyptDate.year,
            egyptDate.month,
            egyptDate.day,
            int.parse(startParts[0]),
            int.parse(startParts[1]),
          );

          final egyptEnd = DateTime(
            egyptDate.year,
            egyptDate.month,
            egyptDate.day,
            int.parse(endParts[0]),
            int.parse(endParts[1]),
          );

          // Convert to local
          final localStart = TimezoneHelper.egyptToLocal(egyptStart);
          final localEnd = TimezoneHelper.egyptToLocal(egyptEnd);

          return ConvertedSlot(
            localStart: localStart,
            localEnd: localEnd,
          );
        })
        .whereType<ConvertedSlot>()
        .toList();
  }

  // Filter free slots based on student's lesson duration
  List<ConvertedSlot> get filteredFreeSlots {
    if (widget.studentLessonDuration <= 0) {
      return _convertedSlots;
    }

    return _convertedSlots.where((slot) {
      final slotDurationMinutes =
          slot.localEnd.difference(slot.localStart).inMinutes;
      return slotDurationMinutes >= widget.studentLessonDuration;
    }).toList();
  }

  List<int> get availableDays {
    final days = filteredFreeSlots.map((s) => s.dayOfWeek).toSet().toList();
    // Sort with Saturday (6) first, then Sunday (0) through Friday (5)
    days.sort((a, b) {
      if (a == 6 && b != 6) return -1; // Saturday comes first
      if (b == 6 && a != 6) return 1; // Saturday comes first
      return a.compareTo(b); // Normal sort for other days
    });
    return days;
  }

  List<String> timesForDay(int day) {
    if (widget.studentLessonDuration <= 0) {
      return filteredFreeSlots
          .where((s) => s.dayOfWeek == day)
          .map((s) =>
              '${s.localStart.hour.toString().padLeft(2, '0')}:${s.localStart.minute.toString().padLeft(2, '0')}:00')
          .toList();
    }

    List<String> availableTimes = [];

    for (final slot in filteredFreeSlots.where((s) => s.dayOfWeek == day)) {
      // Use local properties directly
      final startTime = slot.localStart;
      final endTime = slot.localEnd;

      // Generate time slots based on lesson duration
      DateTime currentSlotStart = startTime;

      while (currentSlotStart
              .add(Duration(minutes: widget.studentLessonDuration))
              .isBefore(endTime) ||
          currentSlotStart
              .add(Duration(minutes: widget.studentLessonDuration))
              .isAtSameTime(endTime)) {
        final timeString =
            '${currentSlotStart.hour.toString().padLeft(2, '0')}:${currentSlotStart.minute.toString().padLeft(2, '0')}:00';
        availableTimes.add(timeString);

        // Move to next slot
        currentSlotStart = currentSlotStart
            .add(Duration(minutes: widget.studentLessonDuration));
      }
    }

    // Remove duplicates and sort
    availableTimes = availableTimes.toSet().toList();
    availableTimes.sort();

    return availableTimes;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'تأجيل الحصة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.studentLessonDuration > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1A8B0628), // 0.1 opacity primary
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'يتم عرض الأوقات المتاحة التي تزيد عن ${widget.studentLessonDuration} دقيقة فقط',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('اختر اليوم',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (availableDays.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'لا توجد أوقات متاحة تناسب مدة الدرس المطلوبة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: availableDays.map((d) {
                        final label = _dayLabel(d);
                        final selected = _selectedDayOfWeek == d;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedDayOfWeek = d;
                              _selectedStartTime = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  const Text('اختر الساعة',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_selectedDayOfWeek == null)
                    const Text('الرجاء اختيار اليوم أولاً')
                  else ...[
                    Wrap(
                      spacing: 8,
                      children: timesForDay(_selectedDayOfWeek!).map((t) {
                        final selected = _selectedStartTime == t;
                        return ChoiceChip(
                          label: Text(t),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedStartTime = t;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Confirm button directly below choices
                  ElevatedButton(
                    onPressed: (_selectedDayOfWeek != null &&
                            _selectedStartTime != null &&
                            !_isCreatingEvent)
                        ? _createPostponedEvent
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreatingEvent
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'جاري الإنشاء...',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : const Text(
                            'تأكيد',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 40), // Add space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(int d) {
    switch (d) {
      case 6:
        return 'السبت';
      case 0:
        return 'الأحد';
      case 1:
        return 'الاثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return d.toString();
    }
  }

  Future<void> _createPostponedEvent() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.student == null) {
      _showErrorDialog('خطأ في المصادقة');
      return;
    }

    if (_selectedDayOfWeek == null || _selectedStartTime == null) {
      _showErrorDialog('الرجاء اختيار اليوم والوقت');
      return;
    }

    setState(() {
      _isCreatingEvent = true;
    });

    try {
      final student = authState.student!;

      // 1. Calculate Local DateTime
      final now = DateTime.now();
      final daysUntilSelected = (_selectedDayOfWeek! - now.weekday + 7) % 7;
      final localDate = now
          .add(Duration(days: daysUntilSelected == 0 ? 7 : daysUntilSelected));

      // Parse time
      final timeParts = _selectedStartTime!.split(':');
      final localDateTime = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // 2. Convert back to Egypt DateTime for server
      final egyptDateTime = TimezoneHelper.localToEgypt(localDateTime);

      final egyptDateStr =
          '${egyptDateTime.year}-${egyptDateTime.month.toString().padLeft(2, '0')}-${egyptDateTime.day.toString().padLeft(2, '0')}';
      final egyptTimeStr =
          '${egyptDateTime.hour.toString().padLeft(2, '0')}:${egyptDateTime.minute.toString().padLeft(2, '0')}:00';

      if (kDebugMode) {
        print('Creating event:');
        print('  Local: $localDateTime');
        print('  Egypt: $egyptDateStr $egyptTimeStr');
      }

      await _api.createPostponedEvent(
        studentId: student.id,
        teacherId: widget.teacherId,
        originalDate: widget.currentLessonDate ??
            egyptDateStr, // Use current lesson date or new date if unknown
        originalTime: widget.currentLessonTime ?? egyptTimeStr,
        newDate: egyptDateStr,
        newTime: egyptTimeStr,
      );

      // Create student report for the CURRENT lesson being postponed
      if (widget.currentLessonDate != null) {
        if (kDebugMode) {
          print(
              'DEBUG: Creating postponement report for student ${student.id}');
          print('DEBUG: Teacher ID: ${widget.teacherId}');
          print('DEBUG: Date: ${widget.currentLessonDate}');
          print('DEBUG: Time: ${widget.currentLessonTime}');
          print('DEBUG: Attendance: تأجيل ولي أمر');
        }

        // Calculate session number first
        String sessionNumber = '0';
        try {
          final sessionData = await _api.calculateSessionNumber(
            studentId: student.id,
            attendance: 'تأجيل ولي أمر',
          );
          sessionNumber = sessionData['session_number']?.toString() ?? '0';
          if (kDebugMode) {
            print('DEBUG: Calculated session number: $sessionNumber');
          }
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: Failed to calculate session number: $e');
            // Fallback to '0' or maybe try to fetch latest report?
            // For now, keep '0' as fallback but ideally we want the real number
          }
        }

        final reportResult = await _api.createStudentReport(
          studentId: student.id,
          teacherId: widget.teacherId,
          attendance: 'تأجيل ولي أمر',
          sessionNumber: sessionNumber,
          date: widget.currentLessonDate!,
          time: widget.currentLessonTime ?? '',
          lessonDuration: widget.studentLessonDuration,
          isPostponed: 0,
        );

        if (kDebugMode) {
          print('DEBUG: Report creation result: $reportResult');
        }
      }

      _showSuccessDialog(student.teacherGender ?? 'ذكر');
    } catch (e) {
      _showErrorDialog('فشل في إنشاء الحدث المؤجل: ${e.toString()}');
    } finally {
      setState(() {
        _isCreatingEvent = false;
      });
    }
  }

  void _showSuccessDialog(String teacherGender) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم بنجاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تم إنشاء الحدث المؤجل بنجاح.',
                style: const TextStyle(fontFamily: 'Qatar', fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إشعار ${GenderHelper.getTeacherTitle(teacherGender)} بالموعد الجديد وبانتظار الموافقة.',
                style: const TextStyle(
                  fontFamily: 'Qatar',
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close sheet
                // Trigger refresh callback
                widget.onSuccess?.call();
              },
              child: const Text(
                'موافق',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('خطأ'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'موافق',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Extension method to check if two DateTime objects represent the same time
extension DateTimeComparison on DateTime {
  bool isAtSameTime(DateTime other) {
    return hour == other.hour && minute == other.minute;
  }
}

class ConvertedSlot {
  final DateTime localStart;
  final DateTime localEnd;

  ConvertedSlot({required this.localStart, required this.localEnd});

  int get dayOfWeek => localStart.weekday % 7; // 0=Sun, 1=Mon...
}
