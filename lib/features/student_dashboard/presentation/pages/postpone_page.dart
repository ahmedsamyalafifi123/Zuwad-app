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
import '../../../chat/presentation/pages/chat_page.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/student_report.dart';

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

  // Postponement Limit State
  final ReportRepository _reportRepository = ReportRepository();
  bool _checkingLimit = true;
  int _allowedPostponements = 0;
  int _usedPostponements = 0;
  bool _isRestricted = false;

  @override
  void initState() {
    super.initState();
    _initializeConvertedSlots();
    _checkPostponementLimit();
  }

  Future<void> _checkPostponementLimit() async {
    if (!mounted) return;
    setState(() => _checkingLimit = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        final student = authState.student!;
        final lessonsNumber = student.lessonsNumber ?? 8;

        // 1. Calculate allowed: floor(lessonsNumber / 4)
        // If < 4, maybe allow 1? Or 0? User said "for 4 can 1", "if 8 can 2".
        // Assuming integer division.
        _allowedPostponements = (lessonsNumber / 4).floor();
        if (_allowedPostponements < 1)
          _allowedPostponements = 1; // Fallback to at least 1

        // 2. Fetch reports
        final reports = await _reportRepository.getStudentReports(student.id);

        // Sort descending by date and time
        final sortedReports = List<StudentReport>.from(reports);
        sortedReports.sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return b.time.compareTo(a.time);
        });

        // Valid attendance values for determining session number (from home_page.dart)
        const validAttendanceValues = [
          'حضور',
          'غياب',
          'تأجيل المعلم',
          'تأجيل ولي أمر',
        ];

        // Helper to check if report is valid for session calculation
        bool isValidReport(StudentReport r) {
          return validAttendanceValues.contains(r.attendance);
        }

        // Find the latest valid report's sessionNumber
        int lastSessionNumber = 0;
        if (sortedReports.isNotEmpty) {
          final latestValidReport = sortedReports.firstWhere(
            (r) => isValidReport(r),
            orElse: () => sortedReports.first,
          );
          if (isValidReport(latestValidReport)) {
            lastSessionNumber = latestValidReport.sessionNumber;
          }
        }

        // Calculate next session number
        int nextSessionNumber = lastSessionNumber + 1;
        if (nextSessionNumber > lessonsNumber) {
          nextSessionNumber = 1;
        }

        if (kDebugMode) {
          print('DEBUG: Last session number: $lastSessionNumber');
          print('DEBUG: Next session number: $nextSessionNumber');
        }

        // 3. Determine if student is starting a new pack
        int count = 0;
        if (nextSessionNumber == 1) {
          // Student is about to start a new pack!
          // Reset postponements - they get full allowance
          count = 0;
          if (kDebugMode) {
            print('DEBUG: Next session is 1, resetting postponement count');
          }
        } else {
          // Count postponements from the LATEST session 1 in the current cycle
          DateTime? cycleStartDate;
          for (var report in sortedReports) {
            if (report.sessionNumber == 1) {
              cycleStartDate = DateTime.tryParse(report.date);
              break;
            }
          }

          for (var report in sortedReports) {
            final rDate = DateTime.tryParse(report.date);
            if (rDate == null) continue;

            // Only count if report is AFTER or SAME as cycle start
            if (cycleStartDate != null && rDate.isBefore(cycleStartDate)) {
              continue;
            }

            // Check if postponed
            if (report.attendance == 'تأجيل ولي أمر' ||
                report.attendance.contains('تأجيل')) {
              count++;
            }
          }
        }

        _usedPostponements = count;

        if (_usedPostponements >= _allowedPostponements) {
          _isRestricted = true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking postponement limit: $e');
    } finally {
      if (mounted) {
        setState(() => _checkingLimit = false);
      }
    }
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
          // Drag Handle + Header Combined
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
                      color: Colors.white.withOpacity(0.3),
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
                          'إعادة جدولة الحصة',
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
            child: _checkingLimit
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor))
                : SingleChildScrollView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isRestricted) ...[
                          Row(
                            children: [
                              const Icon(Icons.calendar_month,
                                  color: Color(0xFFD4AF37), size: 24),
                              const SizedBox(width: 8),
                              const Text('اختر اليوم',
                                  style: TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
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
                                style: TextStyle(
                                    fontFamily: 'Qatar', color: Colors.grey),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              children: availableDays.map((d) {
                                final label = _dayLabel(d);
                                final selected = _selectedDayOfWeek == d;
                                return Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ChoiceChip(
                                    label: Text(label,
                                        style: const TextStyle(
                                            fontFamily: 'Qatar')),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedDayOfWeek = d;
                                        _selectedStartTime = null;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled,
                                  color: Color(0xFFD4AF37), size: 24),
                              const SizedBox(width: 8),
                              const Text('اختر الساعة',
                                  style: TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedDayOfWeek == null)
                            const Text('الرجاء اختيار اليوم أولاً',
                                style: TextStyle(fontFamily: 'Qatar'))
                          else ...[
                            Wrap(
                              spacing: 8,
                              children:
                                  timesForDay(_selectedDayOfWeek!).map((t) {
                                final selected = _selectedStartTime == t;
                                return Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ChoiceChip(
                                    label: Text(t,
                                        style: const TextStyle(
                                            fontFamily: 'Qatar')),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedStartTime = t;
                                      });
                                    },
                                  ),
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'جاري الإنشاء...',
                                        style: TextStyle(
                                            fontFamily: 'Qatar',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'تأكيد',
                                    style: TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                          const SizedBox(height: 36),
                        ], // End of if (!_isRestricted)

                        if (_isRestricted)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'لقد استنفذت عدد مرات التأجيل المتاحة لهذا الشهر.',
                                    style: const TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 14,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Color(0xFFD4AF37), size: 24),
                                  const SizedBox(width: 8),
                                  const Text('إرشادات',
                                      style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Dynamic Guidelines
                              _buildInfoBullet(
                                  'يمكنك إعادة جدولة $_allowedPostponements حصة في الشهر.'),
                              const SizedBox(height: 8),

                              if (!_isRestricted) ...[
                                _buildInfoBullet(
                                    'المتبقي لك: ${_allowedPostponements - _usedPostponements} حصة.'),
                                const SizedBox(height: 8),
                              ],

                              _buildInfoBullet(
                                  'يمكنك إعادة الجدولة في اي وقت وحتى قبل الحصة بساعة واحدة فقط.'),
                              const SizedBox(height: 8),
                              _buildInfoBullet(
                                  'يظهر لك فقط المواعيد المتاحة المناسبة لك.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final authState = context.read<AuthBloc>().state;
                            if (authState is AuthAuthenticated &&
                                authState.student != null) {
                              final student = authState.student!;
                              final supervisorId = student.supervisorId;

                              if (supervisorId != null && supervisorId != 0) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      recipientId: supervisorId.toString(),
                                      recipientName: 'خدمة العملاء',
                                      studentId: student.id.toString(),
                                      studentName: student.name,
                                      recipientRole: 'supervisor',
                                      recipientGender:
                                          'male', // Default or fetch
                                    ),
                                  ),
                                );
                              } else {
                                // Show toast or dialog if no supervisor assigned
                                _showErrorDialog('لا يوجد مشرف مخصص لك حالياً');
                              }
                            }
                          },
                          child: const Text(
                            'تواصل معنا في حال واجهتك أي مشكلة',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primaryColor,
                              decorationThickness: 2.0,
                            ),
                          ),
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
            style: const TextStyle(fontFamily: 'Qatar', fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'موافق',
                style: TextStyle(
                    fontFamily: 'Qatar',
                    color: AppTheme.primaryColor,
                    fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(Icons.circle, size: 6, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
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
