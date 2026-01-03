import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/student_report.dart';
import '../../domain/models/schedule.dart';
import 'report_details_page.dart';
import 'postpone_page.dart';
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

  @override
  void initState() {
    super.initState();
    // Defer data loading to avoid setState in initState or just run it as it's async
    // Since variables are true, UI shows loaders.
    // _loadData will eventually update them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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

    final now = DateTime.now();

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

    for (var schedule in schedules) {
      DateTime? lessonDateTime;
      String? lessonDateStr;

      if (schedule.isPostponed && schedule.postponedDate != null) {
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

        // Iterate through future weeks to find a slot without a report
        // Check up to 8 weeks ahead
        final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);

        for (int weekOffset = 0; weekOffset < 8; weekOffset++) {
          final candidateDateTime = DateTime(
            now.year,
            now.month,
            now.day + daysUntil + (weekOffset * 7),
            lessonTime.hour,
            lessonTime.minute,
          );

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

          // Only include if it's in the future (double check)
          if (lessonDateTime.isAfter(now)) {
            upcomingLessons.add({
              'schedule': schedule,
              'dateTime': lessonDateTime,
              'dateStr': lessonDateStr,
            });
          }
          break; // Found the next lesson for this schedule, move to next schedule
        }

        // Skip the logic below since we added to upcomingLessons inside the loop
        continue;
      }

      // This part is only reached by the postponed logic block above
      // because the regular schedule block now continues/breaks.

      // Only include future lessons (for postponed)
      if (lessonDateTime != null && lessonDateTime.isAfter(now)) {
        upcomingLessons.add({
          'schedule': schedule,
          'dateTime': lessonDateTime,
          'dateStr': lessonDateStr,
        });
      }
    }

    // Sort by date/time
    if (upcomingLessons.isNotEmpty) {
      upcomingLessons.sort((a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      // Calculate session numbers
      int lastSessionNumber = 0;
      if (reports.isNotEmpty) {
        final validReports = reports.where((r) => r.sessionNumber > 0).toList();
        if (validReports.isNotEmpty) {
          // Sort by date and time descending to get the LATEST report
          validReports.sort((a, b) {
            final dateCompare = b.date.compareTo(a.date);
            if (dateCompare != 0) return dateCompare;

            // If dates are equal, try to compare times
            // Simple string comparison might suffice for standard formats,
            // but parsing is safer if formats vary.
            // Given the context, we'll do a basic string compare for now
            // as normalized times are usually comparable.
            return b.time.compareTo(a.time);
          });

          lastSessionNumber = validReports.first.sessionNumber;
        }
        if (kDebugMode) {
          print(
              'DEBUG: Max Session Number (from latest report): $lastSessionNumber');
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
        if (schedule.isPostponed) {
          lesson['sessionNumber'] = 0; // 0 indicates postponed/no number
        } else {
          currentSessionNum++;
          if (currentSessionNum > totalLessons) {
            currentSessionNum = 1;
          }
          lesson['sessionNumber'] = currentSessionNum;
        }

        if (kDebugMode) {
          print(
              'DEBUG: Assigned session ${lesson['sessionNumber']} to lesson on ${lesson['dateStr']} (Postponed: ${schedule.isPostponed})');
        }
      }

      // Take up to 2 lessons
      final nextTwo = upcomingLessons.take(2).toList();

      if (mounted) {
        setState(() {
          _nextLessons = nextTwo;
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
            return _buildNextLessonCard(
              lessonData['schedule'] as Schedule,
              lessonData['dateTime'] as DateTime,
              lessonData['sessionNumber'] as int? ?? 0,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNextLessonCard(
      Schedule schedule, DateTime dateTime, int sessionNumber) {
    // Get student details from Bloc
    String teacherName = 'المعلم';
    String lessonName = 'درس';

    // We can access the auth state here since we are inside a widget
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        teacherName = authState.student!.teacherName ?? 'المعلم';
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
                        Text(
                          schedule.isPostponed
                              ? 'حصة مؤجلة'
                              : 'الحصة $sessionNumber',
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'الاستاذة',
                                  style: TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  teacherFirstName,
                                  style: const TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFD4AF37), width: 1.5),
                              ),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: const AssetImage(
                                    'assets/images/male_avatar.webp'),
                              ),
                            ),
                          ],
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
                            onPressed: () =>
                                _openPostponePage(schedule, dateTime),
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
                              'إعادة الجدولة',
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
            itemBuilder: (context, index) => _buildReportCard(_reports[index]),
          ),
      ],
    );
  }

  Widget _buildReportCard(StudentReport report) {
    // Get student details from Bloc
    String teacherName = 'المعلم';
    String lessonName = 'درس';

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        teacherName = authState.student!.teacherName ?? 'المعلم';
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
            builder: (context) => ReportDetailsPage(report: report),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الحصة ${report.sessionNumber}',
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              if (report.evaluation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        _getEvaluationColor(report.evaluation),
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
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'الاستاذة',
                                    style: TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    teacherFirstName,
                                    style: const TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
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
                                  backgroundImage: const AssetImage(
                                      'assets/images/male_avatar.webp'),
                                ),
                              ),
                            ],
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
                                    builder: (context) =>
                                        ReportDetailsPage(report: report),
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
    );
  }

  Widget _buildQuickActionButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return GestureDetector(
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
