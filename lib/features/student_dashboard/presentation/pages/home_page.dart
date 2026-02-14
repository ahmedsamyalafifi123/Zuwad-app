import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/gender_helper.dart';
import '../../../../core/utils/timezone_helper.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/student_report.dart';
import '../../domain/models/schedule.dart';
import 'report_details_page.dart';
import 'postpone_page.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/domain/models/student.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ReportRepository _reportRepository = ReportRepository();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();

  // Reports state
  List<StudentReport> _reports = [];
  bool _isLoadingReports = true; // Start loading initially

  // Next Lessons state
  List<Map<String, dynamic>> _nextLessons = [];
  bool _isLoadingSchedule = true; // Start loading initially

  // Tab state: 0 = upcoming lessons, 1 = previous reports
  int _activeTab = 0;

  // Tutorial Keys
  final GlobalKey _upcomingTabKey = GlobalKey();
  final GlobalKey _previousTabKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    // Defer data loading to avoid setState in initState or just run it as it's async
    // Since variables are true, UI shows loaders.
    // _loadData will eventually update them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(forceRefresh: true);
    });

    // Check for tutorial part 2
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    // kDebugMode allows testing easily - ALWAYS SHOWS IN DEBUG as requested
    if (kDebugMode) {
      // Small delay to ensure UI is built
      Future.delayed(const Duration(seconds: 1), () {
        _showTutorial();
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenPart1 = prefs.getBool('seen_dashboard_tutorial') ?? false;
    final seenPart2 = prefs.getBool('seen_schedule_tutorial') ?? false;

    // Only show part 2 if part 1 is seen AND part 2 is not
    if (seenPart1 && !seenPart2) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "تخطي",
      textStyleSkip: const TextStyle(
        fontFamily: 'Qatar',
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _markTutorialSeen();
      },
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_schedule_tutorial', true);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 1. Upcoming Lessons Tab
    targets.add(
      TargetFocus(
        identify: "upcoming_tab",
        keyTarget: _upcomingTabKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "الحصص القادمة",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "اضغط هنا لعرض جدول الحصص القادمة.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => controller.next(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("التالي",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // 2. Previous Reports Tab
    targets.add(
      TargetFocus(
        identify: "previous_tab",
        keyTarget: _previousTabKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "الحصص السابقة",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "اضغط هنا لعرض تقارير الحصص التي تم الانتهاء منها.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Back Button (Previous) - Flex 1
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => controller.previous(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("السابق",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Next/Finish Button - Flex 2
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => controller.next(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("إنهاء",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    return targets;
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      if (forceRefresh) {
        setState(() {
          _isLoadingReports = true;
          _isLoadingSchedule = true;
        });
      }

      // Load reports first as they are needed for filtering schedules
      await _loadReports(
          studentId: authState.student!.id, forceRefresh: forceRefresh);
      // Then load schedules
      await _loadNextLessons(
          studentId: authState.student!.id, forceRefresh: forceRefresh);
    }
  }

  Future<void> _loadReports(
      {required int studentId, bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingReports = true;
      });

      final reports = await _reportRepository.getStudentReports(
        studentId,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      setState(() {
        _reports = reports;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reports = [];
      });
      // Error handling is done in UI or silent
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
        });
      }
    }
  }

  Future<void> _loadNextLessons(
      {required int studentId, bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingSchedule = true;
      });

      // Get next schedule with force refresh
      final nextSchedule = await _scheduleRepository.getNextSchedule(
        studentId,
        forceRefresh: forceRefresh,
      );

      if (nextSchedule != null && nextSchedule.schedules.isNotEmpty) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated && authState.student != null) {
          _findNextTwoLessons(
              nextSchedule.schedules, _reports, authState.student!);
        }
      } else {
        if (mounted) {
          setState(() {
            _nextLessons = [];
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading next lessons: $e');
      }
      if (mounted) {
        setState(() {
          _nextLessons = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSchedule = false;
        });
      }
    }
  }

  void _findNextTwoLessons(
      List<Schedule> schedules, List<StudentReport> reports, Student student) {
    if (schedules.isEmpty) {
      if (mounted) setState(() => _nextLessons = []);
      return;
    }

    final now = TimezoneHelper.localToEgypt(DateTime.now());

    // Create a set of report date+time keys for quick lookup
    // Format: "YYYY-MM-DD|HH:MM" to uniquely identify each lesson
    final reportDateTimes = reports.map((r) {
      try {
        final date = DateTime.parse(r.date);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        // Normalize time to HH:MM format
        final timeStr = _normalizeTimeForComparison(r.time);
        return '$dateStr|$timeStr';
      } catch (e) {
        return '${r.date}|${r.time}';
      }
    }).toSet();

    // Create a list of all upcoming lessons with their actual DateTime
    List<Map<String, dynamic>> upcomingLessons = [];

    // Track added trial lessons to prevent duplicates (key: "trialDate|trialTime")
    Set<String> addedTrialLessons = {};

    for (var schedule in schedules) {
      DateTime? lessonDateTime;
      String? lessonDateStr;

      if (schedule.isTrial && schedule.trialDate != null) {
        // Handle trial lessons with specific dates
        try {
          // Use trialDatetime if available, otherwise parse from trialDate + trialTime
          DateTime? trialDateTime;
          if (schedule.trialDatetime != null) {
            try {
              trialDateTime = DateTime.parse(schedule.trialDatetime!);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing trial_datetime: $e');
              }
            }
          }

          // If trialDatetime parsing failed or not available, use trialDate + hour
          if (trialDateTime == null) {
            final trialDate = DateTime.parse(schedule.trialDate!);
            final lessonTime = _parseTimeString(schedule.hour);

            if (lessonTime != null) {
              trialDateTime = DateTime(
                trialDate.year,
                trialDate.month,
                trialDate.day,
                lessonTime.hour,
                lessonTime.minute,
              );
            }
          }

          if (trialDateTime != null) {
            lessonDateTime = trialDateTime;
            lessonDateStr =
                '${trialDateTime.year}-${trialDateTime.month.toString().padLeft(2, '0')}-${trialDateTime.day.toString().padLeft(2, '0')}';
          } else {
            continue;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing trial lesson date: $e');
          }
          continue;
        }

        // Check if this trial lesson already has a report (date+time match)
        final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final lessonKey = '$lessonDateStr|$lessonTimeStr';
        if (reportDateTimes.contains(lessonKey)) {
          continue; // Skip this trial schedule if a report exists
        }

        // IMPORTANT: Check for duplicate trial lessons
        // Create a unique key for this trial lesson
        final trialKey =
            '${schedule.trialDate}|${_normalizeTimeForComparison(schedule.hour)}';
        if (addedTrialLessons.contains(trialKey)) {
          if (kDebugMode) {
            print('Skipping duplicate trial lesson: $trialKey (already added)');
          }
          continue; // Skip duplicate trial lesson
        }
        // Mark this trial lesson as added
        addedTrialLessons.add(trialKey);
      } else if (schedule.isPostponed && schedule.postponedDate != null) {
        // Handle postponed schedules
        try {
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          lessonDateStr =
              '${postponedDate.year}-${postponedDate.month.toString().padLeft(2, '0')}-${postponedDate.day.toString().padLeft(2, '0')}';

          final lessonTime = _parseTimeString(schedule.hour);
          if (lessonTime != null) {
            lessonDateTime = DateTime(
              postponedDate.year,
              postponedDate.month,
              postponedDate.day,
              lessonTime.hour,
              lessonTime.minute,
            );
          }
        } catch (e) {
          continue;
        }

        // Check if this postponed lesson already has a report (date+time match)
        final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final lessonKey = '$lessonDateStr|$lessonTimeStr';
        if (reportDateTimes.contains(lessonKey)) {
          continue; // Skip this postponed schedule if a report exists
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

        final normalizedDay = _normalizeDay(schedule.day);
        final scheduledDay = dayMap[normalizedDay];
        if (scheduledDay == null) continue;

        final lessonTime = _parseTimeString(schedule.hour);
        if (lessonTime == null) continue;

        // Calculate days until the scheduled day
        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil == 0) {
          // If it's today, check if the time has already passed
          if (lessonTime.hour < now.hour ||
              (lessonTime.hour == now.hour &&
                  lessonTime.minute <= now.minute)) {
            // If time has passed, schedule is for next week
            daysUntil = 7;
          }
        }

        // Iterate through future weeks to find all slots without a report within 30 days
        final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final thirtyDaysFromNow = now.add(const Duration(days: 30));

        for (int weekOffset = 0; weekOffset < 5; weekOffset++) {
          final candidateDateTime = DateTime(
            now.year,
            now.month,
            now.day + daysUntil + (weekOffset * 7),
            lessonTime.hour,
            lessonTime.minute,
          );

          // Stop if beyond 30 days
          if (candidateDateTime.isAfter(thirtyDaysFromNow)) {
            break;
          }

          // Calculate the date string for comparison with reports
          final candidateDateStr =
              '${candidateDateTime.year}-${candidateDateTime.month.toString().padLeft(2, '0')}-${candidateDateTime.day.toString().padLeft(2, '0')}';
          final candidateKey = '$candidateDateStr|$regularLessonTimeStr';

          if (reportDateTimes.contains(candidateKey)) {
            continue; // Report exists, check next week
          }

          // Found a slot without a report
          lessonDateTime = candidateDateTime;
          lessonDateStr = candidateDateStr;

          // Include if lesson is upcoming or still in progress
          final lessonDuration = int.tryParse(student.lessonDuration ?? '') ?? 45;
          final lessonWindowEnd = lessonDateTime.add(Duration(minutes: lessonDuration + 10));
          if (lessonDateTime.isAfter(now) || now.isBefore(lessonWindowEnd)) {
            upcomingLessons.add({
              'schedule': schedule,
              'dateTime': lessonDateTime,
              'dateStr': lessonDateStr,
            });
          }
          // Continue checking for more lessons within 30 days
        }

        // Skip the logic below since we added to upcomingLessons inside the loop
        continue;
      }

      // This part is only reached by the trial/postponed logic blocks above
      // because the regular schedule block now continues/breaks.

      // Include future or in-progress lessons (for trial and postponed)
      if (lessonDateTime != null) {
        final lessonDuration = int.tryParse(student.lessonDuration ?? '') ?? 45;
        final lessonWindowEnd = lessonDateTime.add(Duration(minutes: lessonDuration + 10));
        if (lessonDateTime.isAfter(now) || now.isBefore(lessonWindowEnd)) {
          upcomingLessons.add({
            'schedule': schedule,
            'dateTime': lessonDateTime,
            'dateStr': lessonDateStr,
          });
        }
      }
    }

    // Sort by date/time
    if (upcomingLessons.isNotEmpty) {
      upcomingLessons.sort((a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      // Calculate session numbers
      int lastSessionNumber = 0;
      if (reports.isNotEmpty) {
        // Sort all reports by date and time descending to get the LATEST report first
        final sortedReports = List<StudentReport>.from(reports);
        sortedReports.sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return b.time.compareTo(a.time);
        });

        // Valid attendance values for determining session number
        const validAttendanceValues = [
          'حضور',
          'غياب',
          'تأجيل المعلم',
          'تأجيل ولي أمر',
        ];

        // Helper function to check if a report is valid for session calculation
        bool isValidReport(StudentReport r) {
          return !r.isPostponed && validAttendanceValues.contains(r.attendance);
        }

        // Find the latest valid report (NOT postponed AND has valid attendance)
        // and use its sessionNumber (even if it's 0, e.g., for attendance "حضور" with sessionNumber 0)
        final latestValidReport = sortedReports.firstWhere(
          (r) => isValidReport(r),
          orElse: () => sortedReports.first,
        );

        // Use the sessionNumber from the latest valid report
        // This correctly handles sessionNumber == 0 when attendance is "حضور"
        if (isValidReport(latestValidReport)) {
          lastSessionNumber = latestValidReport.sessionNumber;
        } else {
          // No valid reports found, fall back to finding any with sessionNumber > 0
          final validReports =
              reports.where((r) => r.sessionNumber > 0).toList();
          if (validReports.isNotEmpty) {
            validReports.sort((a, b) {
              final dateCompare = b.date.compareTo(a.date);
              if (dateCompare != 0) return dateCompare;
              return b.time.compareTo(a.time);
            });
            lastSessionNumber = validReports.first.sessionNumber;
          }
        }

        if (kDebugMode) {
          print(
              'DEBUG: Latest non-postponed report sessionNumber: $lastSessionNumber');
        }
      } else {
        if (kDebugMode) {
          print('DEBUG: No reports found in list');
        }
      }

      int currentSessionNum = lastSessionNumber;
      final int totalLessons =
          student.lessonsNumber != null && student.lessonsNumber! > 0
              ? student.lessonsNumber!
              : 8; // Default fallback

      if (kDebugMode) {
        print('DEBUG: Student Total Lessons: $totalLessons');
        print('DEBUG: Starting count from: $currentSessionNum');
      }

      // Assign session numbers to upcoming lessons logic
      for (var lesson in upcomingLessons) {
        final schedule = lesson['schedule'] as Schedule;
        if (schedule.isPostponed || schedule.isTrial) {
          lesson['sessionNumber'] = 0; // 0 indicates postponed/trial/no number
        } else {
          currentSessionNum++;
          if (currentSessionNum > totalLessons) {
            currentSessionNum = 1;
          }
          lesson['sessionNumber'] = currentSessionNum;
        }

        if (kDebugMode) {
          print(
              'DEBUG: Assigned session ${lesson['sessionNumber']} to lesson on ${lesson['dateStr']} (Postponed: ${schedule.isPostponed}, Trial: ${schedule.isTrial})');
        }
      }

      // Take all lessons within 30 days (no limit)
      final allLessons = upcomingLessons.toList();

      if (mounted) {
        setState(() {
          _nextLessons = allLessons;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _nextLessons = [];
        });
      }
    }
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      final parts = timeString.trim().split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      final int minute = int.tryParse(timeParts[1]) ?? 0;

      String ampm = parts[1].toUpperCase();
      if (ampm == 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  /// Normalizes time string to "HH:MM" format for comparison (strips seconds)
  String _normalizeTimeForComparison(String timeString) {
    try {
      // First try parsing with _parseTimeString (handles AM/PM)
      final parsed = _parseTimeString(timeString);
      if (parsed != null) {
        return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
      // Fallback: if it's already in HH:MM:SS or HH:MM format, extract HH:MM
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  String _normalizeDay(String day) {
    switch (day.trim()) {
      case 'الاحد':
        return 'الأحد';
      case 'الإثنين':
        return 'الاثنين';
      case 'الاربعاء':
        return 'الأربعاء';
      case 'الجمعه':
        return 'الجمعة';
      default:
        return day.trim();
    }
  }

  Future<void> _openPostponePage(
      Schedule schedule, DateTime lessonDateTime) async {
    // Fetch teacher free slots logic similar to dashboard
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated || authState.student == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطأ في بيانات الطالب')));
        return;
      }

      final student = authState.student!;
      final teacherId = student.teacherId ?? 0;
      if (teacherId == 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('لا يوجد معلم مسجل')));
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final lessonDuration = int.tryParse(student.lessonDuration ?? '0') ?? 0;
      final slots = await _scheduleRepository.getTeacherFreeSlots(teacherId);

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      // Prepare data for PostponePage
      final currentLessonDay = schedule.day;
      final currentLessonTime = schedule.hour;
      final currentLessonDate =
          '${lessonDateTime.year}-${lessonDateTime.month.toString().padLeft(2, '0')}-${lessonDateTime.day.toString().padLeft(2, '0')}';

      if (!mounted) return;

      // Show modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: PostponePage(
              teacherId: teacherId,
              freeSlots: slots,
              studentLessonDuration: lessonDuration,
              currentLessonDay: currentLessonDay,
              currentLessonTime: currentLessonTime,
              currentLessonDate: currentLessonDate,
              scrollController: scrollController,
              isTrial: schedule.isTrial,
              onSuccess: () {
                // Refresh data
                if (mounted) {
                  _loadData(forceRefresh: true);
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      // Close loading if open
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (e) {/* ignore */}

      if (kDebugMode) {
        print('Error opening postpone page: $e');
      }
    }
  }

  Widget _buildDecorativeHeading(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative border
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x80F6C302), // 0.5 opacity
                  Color(0xFFF6C302),
                  Color(0x80F6C302), // 0.5 opacity
                  Colors.transparent,
                ],
                stops: [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
            ),
          ),
          // Decorative elements
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left decoration
              Container(
                padding: const EdgeInsets.only(right: 8),
                child: const Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Color(0xB3F6C302), // 0.7 opacity
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      color: Color(0x80F6C302), // 0.5 opacity
                      size: 12,
                    ),
                  ],
                ),
              ),
              // Text
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8b0628),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Right decoration
              Container(
                padding: const EdgeInsets.only(left: 8),
                child: const Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Color(0x80F6C302), // 0.5 opacity
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      color: Color(0xB3F6C302), // 0.7 opacity
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextLessonsSection() {
    if (_isLoadingSchedule) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFf6c302),
          ),
        ),
      );
    }

    if (_nextLessons.isEmpty) {
      return const SizedBox
          .shrink(); // Don't show section if no upcoming lessons
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDecorativeHeading('الحصص القادمة'),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _nextLessons.length,
          itemBuilder: (context, index) {
            final lessonData = _nextLessons[index];
            return KeyedSubtree(
              key: ValueKey(
                  '${lessonData['dateStr']}_${lessonData['sessionNumber']}'),
              child: _buildNextLessonCard(
                lessonData['schedule'] as Schedule,
                lessonData['dateTime'] as DateTime,
                lessonData['sessionNumber'] as int? ?? 0,
                showRescheduleButton: index == 0, // Only show for first card
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNextLessonCard(
      Schedule schedule, DateTime dateTime, int sessionNumber,
      {bool showRescheduleButton = true}) {
    // Get student details from Bloc
    String teacherName = 'المعلم';
    String teacherGender = 'ذكر';
    String lessonName = 'درس';

    // We can access the auth state here since we are inside a widget
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        teacherName = authState.student!.teacherName ?? 'المعلم';
        teacherGender = authState.student!.teacherGender ?? 'ذكر';
        lessonName = authState.student!.displayLessonName;
      }
    } catch (e) {
      // safe fallback
    }

    // Month names mapping
    final Map<int, String> monthNames = {
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر'
    };

    final dayNumber = dateTime.day.toString();
    final monthName = monthNames[dateTime.month] ?? '';

    // Normalize time strictly for display (HH:MM or h:mm a)
    String displayTime = schedule.hour;

    // Clean teacher first name
    String teacherFirstName = teacherName;
    if (teacherName.contains(' ')) {
      teacherFirstName = teacherName.split(' ')[0];
    }

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Right Side: Date/Time (Placed first for RTL)
            Container(
              width: 120, // Increased width as requested
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      schedule.day,
                      style: const TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Swapped Icon/Text order for RTL (Icon on Right)
                      const Icon(Icons.access_time,
                          color: Color(0xFFF0BF0C), size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          displayTime,
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Swapped Icon/Text order for RTL (Icon on Right)
                      const Icon(Icons.calendar_month,
                          color: Color(0xFFF0BF0C), size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$dayNumber $monthName',
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Left Side: Main Card (Gradient BG)
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255), // Warm cream white
                      Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header: Lesson# (Right) | Avatar (Left)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lesson Number (Right visual / Start in RTL)
                        Flexible(
                          child: Text(
                            schedule.isTrial
                                ? 'حصة تجريبية'
                                : schedule.isPostponed
                                    ? 'حصة مؤجلة'
                                    : 'الحصة $sessionNumber',
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      GenderHelper.getFormalTitle(
                                          teacherGender),
                                      style: TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      teacherFirstName,
                                      style: const TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFD4AF37),
                                      width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: AssetImage(
                                    GenderHelper.getTeacherImage(teacherGender),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Footer: LessonName (Right) | Button (Left)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle_outlined,
                                      size: 8, color: Color(0xFFF0BF0C)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'درس',
                                    style: TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                lessonName,
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: showRescheduleButton ? 1.0 : 0.4,
                          child: Container(
                            height: isDesktop ? 45 : 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: showRescheduleButton
                                    ? [
                                        const Color.fromARGB(
                                            255, 255, 198, 12), // Gold Yellow
                                        const Color.fromARGB(
                                            255, 206, 158, 1), // Light Yellow
                                      ]
                                    : [
                                        const Color.fromARGB(
                                            255, 208, 208, 208),
                                        const Color.fromARGB(
                                            255, 167, 167, 167),
                                      ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: showRescheduleButton
                                  ? () => _openPostponePage(schedule, dateTime)
                                  : null, // Disabled when not first
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'إعادة الجدولة',
                                style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: isDesktop ? 14 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: showRescheduleButton
                                      ? Colors.black
                                      : const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDecorativeHeading('تقارير الحصص السابقة'),
        if (_isLoadingReports)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFf6c302),
            ),
          )
        else if (_reports.isEmpty)
          const Center(
            child: Text(
              'لا توجد تقارير سابقة',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          )
        else
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reports.length,
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey('${_reports[index].date}_${_reports[index].time}'),
              child: _buildReportCard(_reports[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildReportCard(StudentReport report) {
    // Get student details from Bloc
    String teacherName = 'المعلم';
    String teacherGender = 'ذكر';
    String lessonName = 'درس';

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        teacherName = authState.student!.teacherName ?? 'المعلم';
        teacherGender = authState.student!.teacherGender ?? 'ذكر';
        lessonName = authState.student!.displayLessonName;
      }
    } catch (e) {
      // safe fallback
    }

    // Parse date for display
    String dayName = '';
    String dayNumber = '';
    String monthName = '';

    try {
      final date = DateTime.parse(report.date);
      final Map<int, String> dayNames = {
        DateTime.sunday: 'الأحد',
        DateTime.monday: 'الاثنين',
        DateTime.tuesday: 'الثلاثاء',
        DateTime.wednesday: 'الأربعاء',
        DateTime.thursday: 'الخميس',
        DateTime.friday: 'الجمعة',
        DateTime.saturday: 'السبت',
      };
      final Map<int, String> monthNames = {
        1: 'يناير',
        2: 'فبراير',
        3: 'مارس',
        4: 'أبريل',
        5: 'مايو',
        6: 'يونيو',
        7: 'يوليو',
        8: 'أغسطس',
        9: 'سبتمبر',
        10: 'أكتوبر',
        11: 'نوفمبر',
        12: 'ديسمبر'
      };
      dayName = dayNames[date.weekday] ?? '';
      dayNumber = date.day.toString();
      monthName = monthNames[date.month] ?? '';
    } catch (e) {
      dayNumber = report.date;
    }

    // Format time to 12-hour format
    String displayTime = '--:--';
    if (report.time.isNotEmpty) {
      try {
        final timeParts = report.time.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          final int minute = int.parse(timeParts[1]);
          final String period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          displayTime = '$hour:${minute.toString().padLeft(2, '0')} $period';
        }
      } catch (e) {
        displayTime = report.time;
      }
    }

    // Clean teacher first name
    String teacherFirstName = teacherName;
    if (teacherName.contains(' ')) {
      teacherFirstName = teacherName.split(' ')[0];
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailsPage(
              report: report,
              teacherGender: teacherGender,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Right Side: Date/Time (Placed first for RTL)
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time,
                            color: Color(0xFFF0BF0C), size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            displayTime,
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month,
                            color: Color(0xFFF0BF0C), size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$dayNumber $monthName',
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Left Side: Main Card (Gradient BG)
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(255, 255, 255, 255), // Warm cream white
                        Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header: Session# (Right) | Evaluation + Avatar (Left)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session Number & Evaluation
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.isPostponed
                                      ? 'حصة مجدولة'
                                      : report.attendance == 'اجازة معلم'
                                          ? 'اجازة معلم'
                                          : 'الحصة ${report.sessionNumber}',
                                  style: const TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (report.evaluation.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getEvaluationColor(
                                          report.evaluation),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      report.evaluation,
                                      style: const TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        GenderHelper.getFormalTitle(
                                            teacherGender),
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        teacherFirstName,
                                        style: const TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFD4AF37),
                                        width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: AssetImage(
                                      GenderHelper.getTeacherImage(
                                          teacherGender),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Footer: LessonName (Right) | Button (Left)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.circle_outlined,
                                        size: 8, color: Color(0xFFF0BF0C)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'درس',
                                      style: TextStyle(
                                        fontFamily: 'Qatar',
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  lessonName,
                                  style: const TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(
                                      255, 255, 198, 12), // Dark/Gold Yellow
                                  Color.fromARGB(
                                      255, 206, 158, 1), // Light Yellow
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportDetailsPage(
                                      report: report,
                                      teacherGender: teacherGender,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'عرض الإنجاز',
                                style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEvaluationColor(String evaluation) {
    switch (evaluation.toLowerCase()) {
      case 'ممتاز':
        return Colors.green;
      case 'جيد جداً':
        return Colors.blue;
      case 'جيد':
        return Colors.amber;
      case 'مقبول':
        return Colors.orange;
      case 'ضعيف':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8b0628),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData(forceRefresh: true);
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 20.0, 16, 16 + 80),
          child: ResponsiveContentWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Action Buttons Section - Two centered buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickActionButton(
                        key: _upcomingTabKey,
                        imagePath: 'assets/images/Calender.json',
                        label: 'الحصص القادمة',
                        isActive: _activeTab == 0,
                        onTap: () {
                          setState(() {
                            _activeTab = 0;
                          });
                        },
                      ),
                      // White border separator
                      Container(
                        width: 2,
                        height: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      _buildQuickActionButton(
                        key: _previousTabKey,
                        imagePath: 'assets/images/lottie.json',
                        label: 'الحصص السابقة',
                        isActive: _activeTab == 1,
                        onTap: () {
                          setState(() {
                            _activeTab = 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Show section based on active tab
                if (_activeTab == 0) ...[
                  // Next Lessons Section
                  _buildNextLessonsSection(),
                ] else ...[
                  // Reports Section
                  _buildReportsSection(),
                ],

                // Add extra padding at the bottom
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String imagePath,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.65,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isActive ? 1.0 : 0.92,
          child: SizedBox(
            width: 110,
            height: 100,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // White card - positioned in the middle
                Positioned(
                  top: 35,
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromARGB(255, 255, 255, 255),
                          Color.fromARGB(255, 234, 234, 234),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: isActive
                          ? Border.all(
                              color: const Color(0xFFf6c302),
                              width: 2,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(isActive ? 0.15 : 0.08),
                          blurRadius: isActive ? 10 : 6,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Lottie animation at TOP
                Positioned(
                  top: -25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Lottie.asset(
                      imagePath,
                      width: 130,
                      height: 130,
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                ),
                // Yellow pill at BOTTOM
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 25,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf6c302),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(135, 0, 0, 0)
                              .withOpacity(0.2),
                          blurRadius: 5,
                          spreadRadius: 3,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Qatar',
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
