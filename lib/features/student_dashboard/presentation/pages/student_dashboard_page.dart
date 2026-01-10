import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../services/livekit_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/student.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../meeting/presentation/pages/meeting_page.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/schedule.dart';
import '../../domain/models/student_report.dart';
import 'postpone_page.dart';
import 'report_details_page.dart';

import 'placeholder_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../widgets/islamic_bottom_nav_bar.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/timezone_helper.dart';
import '../utils/timezone_utils.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _currentIndex = 0; // Start with الرئيسة (home/dashboard)

  late final List<Widget> _pages;

  // Navigation items configuration for cleaner code
  // Navigation items handled by IslamicBottomNavBar

  @override
  void initState() {
    super.initState();
    // Initialize pages - 6 pages for the 6 nav items
    _pages = [
      // 0: الرئيسة (Dashboard/Main page)
      _DashboardContent(),
      // 1: جدول الحصص (Schedule)
      const PlaceholderPage(
        title: 'جدول الحصص',
        icon: Icons.calendar_month_rounded,
      ),
      // 2: الانجازات (Achievements)
      const HomePage(),
      // 3: المراسلة (Messages)
      BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated && state.student != null) {
            return ChatListPage(
              studentId: state.student!.id.toString(),
              studentName: state.student!.name,
              teacherId: state.student!.teacherId?.toString() ?? '',
              teacherName: state.student!.teacherName ?? 'المعلم',
              supervisorId: state.student!.supervisorId?.toString() ?? '',
              supervisorName: state.student!.supervisorName ?? 'المشرف',
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      // 4: العاب (Games)
      const PlaceholderPage(
        title: 'العاب',
        icon: Icons.sports_esports_rounded,
      ),
      // 5: الاعدادات (Settings)
      const SettingsPage(),
    ];

    // Fetch student profile data when dashboard loads
    context.read<AuthBloc>().add(GetStudentProfileEvent());
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to white with dark icons
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50), // Adjusted height
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(
                    255, 255, 255, 255), // Warm cream white (Matching Nav Bar)
                Color.fromARGB(
                    255, 234, 234, 234), // Subtle gold tint (Matching Nav Bar)
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(85, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center: Title
                  Text(
                    IslamicBottomNavBar.navItems[_currentIndex]['label']
                        as String,
                    style: const TextStyle(
                      // Title Style
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Left: Notification Icon + Student Avatar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Notification Icon with real unread count
                        _NotificationButton(),
                        const SizedBox(width: 12),
                        // Student Avatar with dropdown menu
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            String? imageUrl;
                            if (state is AuthAuthenticated &&
                                state.student != null) {
                              imageUrl = state.student!.profileImageUrl;
                            }
                            return PopupMenuButton<String>(
                              offset: const Offset(0, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (value) {
                                if (value == 'logout') {
                                  // Show confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      content: const Text(
                                        'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                                        style: TextStyle(fontFamily: 'Qatar'),
                                        textAlign: TextAlign.center,
                                      ),
                                      actionsAlignment:
                                          MainAxisAlignment.center,
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: const Text(
                                            'إلغاء',
                                            style: TextStyle(
                                              fontFamily: 'Qatar',
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            context
                                                .read<AuthBloc>()
                                                .add(LogoutEvent());
                                            Navigator.of(context)
                                                .pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginPage(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF820c22),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'تسجيل الخروج',
                                            style: TextStyle(
                                              fontFamily: 'Qatar',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: const [
                                      Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          color: Color(0xFF820c22),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.logout_rounded,
                                        color: Color(0xFF820c22),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                // Avatar Container
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x26D4AF37),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                            'assets/images/male_avatar.webp',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/male_avatar.webp',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Right: Page Icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      // Page Icon
                      IslamicBottomNavBar.navItems[_currentIndex]['icon']
                          as IconData,
                      color:
                          Colors.black.withOpacity(0.30), // Black 30% opacity
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _pages[_currentIndex],
      extendBody: true,
      extendBodyBehindAppBar: true, // Allow body to show behind rounded corners
      bottomNavigationBar: IslamicBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

/// Notification button widget that shows unread count and navigates to NotificationsPage.
class _NotificationButton extends StatefulWidget {
  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  final NotificationRepository _repository = NotificationRepository();
  int _notificationCount = 0;

  StreamSubscription? _subscription;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscription = _notificationService.onNotificationReceived.listen((_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently fail - notification count is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Get current student ID
        int? studentId;
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated && authState.student != null) {
          studentId = authState.student!.id;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotificationsPage(studentId: studentId),
          ),
        );
        // Refresh count when returning from notifications page
        _loadUnreadCount();
      },
      child: Transform.translate(
        offset: const Offset(-10, -5),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Lottie.asset(
              'assets/images/Bell.json',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              animate: _notificationCount > 0,
            ),
            if (_notificationCount > 0)
              Positioned(
                top: 0,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF820c22), // Burgundy
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    _notificationCount > 99 ? '99+' : '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Qatar',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final ReportRepository _reportRepository = ReportRepository();
  StudentSchedule? _nextSchedule;
  Schedule? _nextLesson;
  DateTime?
      _nextLessonDateTime; // Store the actual calculated date for countdown
  String _teacherName = '';
  String _lessonName = '';
  bool _isLoading = true;
  Duration? _timeUntilNextLesson;
  Timer? _countdownTimer;

  final AuthRepository _authRepository = AuthRepository();
  StudentReport? _lastReport;
  List<Student> _familyMembers = [];
  bool _loadingFamily = false;
  final GlobalKey _arrowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadNextLesson();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNextLesson({bool forceRefresh = false}) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Get student data
        final student = authState.student!;

        // Load family members if not loaded
        if (_familyMembers.isEmpty) {
          _loadFamilyMembers();
        }

        _lessonName = student.displayLessonName;
        _teacherName = student.teacherName ?? 'المعلم';

        // Get reports to check which schedules already have reports
        final reports = await _reportRepository.getStudentReports(
          student.id,
          forceRefresh: forceRefresh,
        );

        // Sort reports to find the last one
        if (reports.isNotEmpty) {
          reports.sort((a, b) {
            try {
              final dateA = DateTime.parse('${a.date} ${a.time}');
              final dateB = DateTime.parse('${b.date} ${b.time}');
              return dateB.compareTo(dateA); // Descending
            } catch (e) {
              return 0;
            }
          });
          _lastReport = reports.first;
        } else {
          _lastReport = null;
        }

        // Get next schedule with force refresh
        final nextSchedule = await _scheduleRepository.getNextSchedule(
          student.id,
          forceRefresh: forceRefresh,
        );

        if (nextSchedule != null) {
          setState(() {
            _nextSchedule = nextSchedule;
            if (nextSchedule.schedules.isNotEmpty) {
              _findNextLesson(nextSchedule.schedules, reports);
              if (_nextLesson != null) {
                _updateCountdown();
                _countdownTimer?.cancel();
                _countdownTimer =
                    Timer.periodic(const Duration(seconds: 1), (_) {
                  _updateCountdown();
                });
              }
            } else {
              _nextLesson = null;
            }
          });
        } else {
          setState(() {
            _nextLesson = null;
            _nextSchedule = null;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading next lesson: $e');
        }
        setState(() {
          _nextLesson = null;
          _nextSchedule = null;
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _findNextLesson(List<Schedule> schedules, List<StudentReport> reports) {
    if (schedules.isEmpty) {
      _nextLesson = null;
      return;
    }

    // Use Egypt time for comparisons since schedules are stored in Egypt time
    final nowLocal = DateTime.now();
    final now = TimezoneHelper.localToEgypt(nowLocal);

    if (kDebugMode) {
      print('Timezone: Local time: $nowLocal, Egypt time: $now');
    }

    // Create a set of report date+time keys for quick lookup
    // Format: "YYYY-MM-DD|HH:MM" to uniquely identify each lesson
    final reportDateTimes = reports.map((r) {
      try {
        final date = DateTime.parse(r.date);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final timeStr = _normalizeTimeForComparison(r.time);
        return '$dateStr|$timeStr';
      } catch (e) {
        return '${r.date}|${r.time}';
      }
    }).toSet();
    if (kDebugMode) {
      print('Report date+times to exclude: $reportDateTimes');
    }

    // Create a list of all upcoming lessons with their actual DateTime
    List<Map<String, dynamic>> upcomingLessons = [];

    for (var schedule in schedules) {
      DateTime? lessonDateTime;
      String? lessonDateStr;

      // Debug each schedule
      if (kDebugMode) {
        print(
            'Checking schedule: day=${schedule.day}, hour=${schedule.hour}, isPostponed=${schedule.isPostponed}, postponedDate=${schedule.postponedDate}');
      }

      if (schedule.isPostponed && schedule.postponedDate != null) {
        // Handle postponed schedules with specific dates
        try {
          if (kDebugMode) {
            print(
                'Processing postponed schedule: ${schedule.day} at ${schedule.hour}, postponed_date: ${schedule.postponedDate}');
          }
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          lessonDateStr =
              '${postponedDate.year}-${postponedDate.month.toString().padLeft(2, '0')}-${postponedDate.day.toString().padLeft(2, '0')}';
          if (kDebugMode) {
            print(
                'Parsed postponed date: $postponedDate, dateStr: $lessonDateStr');
          }
          final lessonTime = _parseTimeString(schedule.hour);
          if (kDebugMode) {
            print('Parsed lesson time: $lessonTime');
          }
          if (lessonTime != null) {
            lessonDateTime = DateTime(
              postponedDate.year,
              postponedDate.month,
              postponedDate.day,
              lessonTime.hour,
              lessonTime.minute,
            );
            if (kDebugMode) {
              print('Created postponed lesson DateTime: $lessonDateTime');
              print('Current time: $now');
              print(
                  'Is postponed lesson in future? ${lessonDateTime.isAfter(now)}');
            }
          } else {
            if (kDebugMode) {
              print('Failed to parse lesson time for postponed schedule');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing postponed date: $e');
          }
          continue;
        }

        // Check if this postponed lesson already has a report (date+time match)
        final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final lessonKey = '$lessonDateStr|$lessonTimeStr';
        if (reportDateTimes.contains(lessonKey)) {
          if (kDebugMode) {
            print(
                'Skipping postponed lesson at $lessonKey - report already exists');
          }
          continue;
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

        // Calculate days until the scheduled day (using Egypt time)
        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil == 0) {
          // If it's today, check if we're past the lesson window
          // Get lesson duration for the window check (default to 45 minutes for generous check)
          int lessonDurationForCheck = 45;
          if (_nextSchedule != null &&
              _nextSchedule!.lessonDuration.isNotEmpty) {
            lessonDurationForCheck =
                int.tryParse(_nextSchedule!.lessonDuration) ?? 45;
          }

          // Calculate when today's lesson window ends (10 min after lesson ends)
          final lessonMinutesFromMidnight =
              lessonTime.hour * 60 + lessonTime.minute;
          final nowMinutesFromMidnight = now.hour * 60 + now.minute;
          final lessonWindowEndMinutes =
              lessonMinutesFromMidnight + lessonDurationForCheck + 10;

          // Only push to next week if we're PAST the lesson window, not just past the start time
          if (nowMinutesFromMidnight > lessonWindowEndMinutes) {
            // Lesson window has ended, schedule is for next week
            daysUntil = 7;
          }
        }

        // FIX: Iterate through future weeks to find a slot without a report
        // Check up to 8 weeks ahead (should be enough to find an available slot)
        final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        bool foundSlot = false;

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
            if (kDebugMode) {
              print(
                  'Skipping regular lesson at $candidateKey - report already exists, checking next week...');
            }
            continue; // Check next week's occurrence
          }

          // Found a slot without a report!
          lessonDateTime = candidateDateTime;
          lessonDateStr = candidateDateStr;
          foundSlot = true;
          if (kDebugMode) {
            print('Found available slot at $candidateKey');
          }
          break;
        }

        if (!foundSlot) {
          if (kDebugMode) {
            print(
                'No available slot found for ${schedule.day} at ${schedule.hour} in next 8 weeks');
          }
          continue; // Skip this schedule if no slot found
        }
      }
      // Include future lessons AND lessons currently in progress
      // A lesson is "in progress" if it started within (lessonDuration + 10) minutes ago
      if (lessonDateTime != null) {
        // Get lesson duration - use _nextSchedule if available, default to 45 minutes
        // for generous window filtering (we'll use the actual duration later for button logic)
        int scheduleLessonDuration = 45; // Default generous window
        if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
          scheduleLessonDuration =
              int.tryParse(_nextSchedule!.lessonDuration) ?? 45;
        }

        // Calculate when the lesson window ends (10 min after lesson ends)
        final lessonWindowEnd =
            lessonDateTime.add(Duration(minutes: scheduleLessonDuration + 10));

        // Include if lesson is in the future OR if we're within the lesson window
        if (lessonDateTime.isAfter(now) || now.isBefore(lessonWindowEnd)) {
          if (kDebugMode) {
            print(
                'Adding upcoming/in-progress lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime, isPostponed: ${schedule.isPostponed}');
          }
          upcomingLessons.add({
            'schedule': schedule,
            'dateTime': lessonDateTime,
          });
        } else {
          if (kDebugMode) {
            print(
                'Skipping past lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime (window ended at: $lessonWindowEnd)');
          }
        }
      }
    }

    // Sort by date/time and get the earliest one
    if (upcomingLessons.isNotEmpty) {
      if (kDebugMode) {
        print(
            'Found ${upcomingLessons.length} upcoming lessons before sorting');
      }
      upcomingLessons.sort((a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      if (kDebugMode) {
        print('Sorted upcoming lessons:');
        for (int i = 0; i < upcomingLessons.length; i++) {
          final lesson = upcomingLessons[i];
          final schedule = lesson['schedule'] as Schedule;
          final dateTime = lesson['dateTime'] as DateTime;
          print(
              '  $i: ${schedule.day} at ${schedule.hour}, dateTime: $dateTime, isPostponed: ${schedule.isPostponed}');
        }
      }

      _nextLesson = upcomingLessons.first['schedule'] as Schedule;
      // The dateTime from upcomingLessons is in Egypt time
      // Convert to local time for countdown display
      final egyptDateTime = upcomingLessons.first['dateTime'] as DateTime;
      _nextLessonDateTime = TimezoneHelper.egyptToLocal(egyptDateTime);
      if (kDebugMode) {
        print(
            'Selected next lesson: ${_nextLesson!.day} at ${_nextLesson!.hour}');
        print('  Egypt time: $egyptDateTime');
        print('  Local time: $_nextLessonDateTime');
        print('  isPostponed: ${_nextLesson!.isPostponed}');
      }
    } else {
      if (kDebugMode) {
        print('No upcoming lessons found');
      }
      _nextLesson = null;
      _nextLessonDateTime = null;
    }
  }

  void _updateCountdown() {
    // Use the stored _nextLessonDateTime directly instead of recalculating
    // This ensures the countdown uses the correct date that accounts for reports
    if (_nextLessonDateTime != null) {
      final now = DateTime.now();
      final previousDuration = _timeUntilNextLesson;
      Duration? newDuration;

      if (_nextLessonDateTime!.isAfter(now)) {
        // Lesson hasn't started yet - show countdown
        newDuration = _nextLessonDateTime!.difference(now);
      } else {
        // Lesson has started or is in progress
        // Get lesson duration to determine when to stop showing zeros
        int lessonDuration = 30;
        if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
          lessonDuration = int.tryParse(_nextSchedule!.lessonDuration) ?? 30;
        }

        // Calculate lesson end time + 10 minutes
        final lessonEndPlusTenMin =
            _nextLessonDateTime!.add(Duration(minutes: lessonDuration + 10));

        if (now.isBefore(lessonEndPlusTenMin)) {
          // Within the lesson period (lesson start to 10 min after end) - show 0:0:0
          newDuration = Duration.zero;
        } else {
          // Past the lesson period - set to null to trigger next lesson load
          newDuration = null;
        }
      }

      if (previousDuration == null ||
          previousDuration.inSeconds != newDuration?.inSeconds) {
        setState(() {
          _timeUntilNextLesson = newDuration;
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

  Widget _buildNextLessonSection() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFf6c302), // Gold color for better visibility
          backgroundColor: const Color(0x33FFFFFF), // 0.2 opacity white
        ),
      );
    }

    if (_nextLesson == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'لا يوجد دروس مجدولة',
            style: TextStyle(
              fontFamily: 'Qatar',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Determine if user can join the lesson
    int lessonDuration = 30;
    if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
      lessonDuration =
          int.tryParse(_nextSchedule!.lessonDuration) ?? lessonDuration;
    }

    bool canJoin = false;
    bool canPostpone = true;

    // Calculate actual time difference from lesson start time directly
    // Don't use _timeUntilNextLesson as it's set to 0 during the lesson for display purposes
    if (_nextLessonDateTime != null) {
      final now = DateTime.now();
      final actualDifference = _nextLessonDateTime!.difference(now);
      final minutesUntilStart = actualDifference.inMinutes;
      final minutesAfterStart =
          -minutesUntilStart; // Positive after lesson starts

      // إنضم للدرس (Join Lesson):
      // Active from 15 minutes BEFORE lesson start until 10 minutes AFTER lesson ends
      // Lesson ends at: lessonDuration minutes after start
      // So active when: minutesUntilStart <= 15 AND minutesAfterStart <= (lessonDuration + 10)
      if (minutesUntilStart <= 15 &&
          minutesAfterStart <= (lessonDuration + 10)) {
        canJoin = true;
      }

      // تأجيل الدرس (Postpone Lesson):
      // Disabled from 1 hour (60 minutes) BEFORE lesson until 10 minutes AFTER lesson ends
      // So disabled when: minutesUntilStart <= 60 AND minutesAfterStart <= (lessonDuration + 10)
      if (minutesUntilStart <= 60 &&
          minutesAfterStart <= (lessonDuration + 10)) {
        canPostpone = false;
      }
    }

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizes
    final containerPadding = isSmallScreen ? 12.0 : 16.0;
    final avatarRadius = isSmallScreen ? 16.0 : 20.0;
    final subjectFontSize = isSmallScreen ? 14.0 : 16.0;
    final dayFontSize = isSmallScreen ? 14.0 : 16.0;
    final timeFontSize = isSmallScreen ? 12.0 : 14.0;
    final teacherLabelSize = isSmallScreen ? 10.0 : 11.0;
    final teacherNameSize = isSmallScreen ? 11.0 : 13.0;
    final buttonFontSize = isSmallScreen ? 12.0 : 14.0;
    final buttonPaddingH = isSmallScreen ? 10.0 : 16.0;
    final buttonPaddingV = isSmallScreen ? 4.0 : 8.0;

    return Column(
      children: [
        // Gradient box with lesson info (like bottom nav bar)
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            // Gradient background like bottom nav bar
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255), // Warm cream white
                Color.fromARGB(255, 230, 230, 230), // Subtle gold tint
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(140, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Main row: Subject (right) | Avatar+Teacher (center) | Day+Time (left)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Right: Subject name
                  Expanded(
                    flex: 2,
                    child: Text(
                      _lessonName,
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: subjectFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Center: Avatar + المعلم + Teacher name (in a row)
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor:
                              const Color.fromARGB(255, 230, 230, 230),
                          backgroundImage: const AssetImage(
                              'assets/images/male_avatar.webp'),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'المعلم',
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: teacherLabelSize,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _teacherName.split(' ').first,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: teacherNameSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Left: Day + Time - pushed to the far left
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // Push to far left in RTL
                      children: [
                        Text(
                          _nextLessonDateTime != null
                              ? TimezoneUtils.getArabicDayName(
                                  _nextLessonDateTime!)
                              : _nextLesson!.day,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: dayFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2), // Reduced spacing
                        Text(
                          _nextLessonDateTime != null
                              ? TimezoneUtils.formatTime(_nextLessonDateTime!)
                              : _nextLesson!.hour,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: timeFontSize,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Countdown section
              if (_timeUntilNextLesson != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      // Background Text Layer
                      Transform.translate(
                        offset:
                            const Offset(0, -2), // Slight vertical adjustment
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'الوقــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــت', // Extended line
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.0,
                                letterSpacing:
                                    0.3, // Tighten slightly to connect
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                            SizedBox(
                                height:
                                    8), // Space between lines to match boxes
                            Text(
                              'المتبقــــــــــــــــــــــــــــــــــــــــــــــــــــــــــي', // Extended line
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.0,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),
                      // Foreground Countdown Layer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Padding to avoid covering the words "الوقت/المتبقي"
                          // Adjust this width based on the visual length of "الوقـ/المتبقـ"
                          const SizedBox(width: 50),

                          // Days (shown if > 0)
                          if (_timeUntilNextLesson!.inDays > 0) ...[
                            _buildCountdownItem(
                                _timeUntilNextLesson!.inDays, 'يوم'),
                            const SizedBox(width: 8),
                          ],
                          // Hours
                          _buildCountdownItem(
                              _timeUntilNextLesson!.inHours % 24, 'ساعة'),
                          const SizedBox(width: 8),
                          // Minutes
                          _buildCountdownItem(
                              _timeUntilNextLesson!.inMinutes % 60, 'دقيقة'),
                          const SizedBox(width: 8),
                          // Seconds
                          _buildCountdownItem(
                              _timeUntilNextLesson!.inSeconds % 60, 'ثانية'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Buttons below the box - smaller and aligned to right side
        SizedBox(height: isSmallScreen ? 8 : 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Start = right in RTL
            mainAxisSize: MainAxisSize.min,
            children: [
              // إنضم للدرس button - green gradient when can join, light yellow when can't
              Container(
                decoration: BoxDecoration(
                  gradient: canJoin
                      ? const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 101, 206, 107), // Light green
                            Color.fromARGB(255, 63, 151, 66), // Green
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            Color.fromARGB(0, 255, 255, 255), // Light yellow
                            Color.fromARGB(0, 240, 191, 12) // Lighter yellow
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Color.fromARGB(157, 255, 255, 255), width: 1.5),
                ),
                child: ElevatedButton(
                  onPressed: canJoin ? _joinLesson : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                        vertical: buttonPaddingV, horizontal: buttonPaddingH),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'إنضم للدرس',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                      color: canJoin
                          ? Colors.white
                          : const Color.fromARGB(157, 255, 255, 255),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 6 : 10),
              // تأجيل الدرس (white border only) - smaller button
              OutlinedButton(
                onPressed: canPostpone ? _openPostponePage : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: canPostpone
                        ? Colors.white
                        : const Color.fromARGB(255, 117, 117, 117),
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(
                      vertical: buttonPaddingV, horizontal: buttonPaddingH),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'تأجيل الدرس',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.bold,
                    color: canPostpone ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),

              // الانجاز السابق button
              if (_lastReport != null) ...[
                SizedBox(width: isSmallScreen ? 6 : 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 253, 247, 89), // Light yellow
                        Color.fromARGB(255, 240, 191, 12) // Lighter yellow
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReportDetailsPage(report: _lastReport!),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor:
                          Colors.black, // darker text for yellow bg
                      padding: EdgeInsets.symmetric(
                          vertical: buttonPaddingV, horizontal: buttonPaddingH),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'الانجاز السابق',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Divider(
          color: Colors.white,
          height: 1,
          thickness: 1,
        ),
      ],
    );
  }

  Widget _buildCountdownItem(int value, String label) {
    return Container(
      width: 40, // Fixed width for consistency
      padding: const EdgeInsets.symmetric(
          vertical: 10), // horizontal padding removed as width is fixed
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.0, // Reduced line height
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPostponePage() async {
    if (_nextSchedule == null) return;

    // Fetch teacher free slots from repository
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

      // Get student's lesson duration
      final lessonDuration = int.tryParse(student.lessonDuration ?? '0') ?? 0;

      final slots = await _scheduleRepository.getTeacherFreeSlots(teacherId);

      // Get current lesson information
      String? currentLessonDate;
      String? currentLessonTime;
      String? currentLessonDay;

      if (_nextLesson != null) {
        currentLessonDay = _nextLesson!.day;
        currentLessonTime = _nextLesson!.hour;

        // Calculate the date of the current lesson
        final now = DateTime.now();
        final dayMap = {
          'الأحد': DateTime.sunday % 7,
          'الاثنين': DateTime.monday % 7,
          'الثلاثاء': DateTime.tuesday % 7,
          'الأربعاء': DateTime.wednesday % 7,
          'الخميس': DateTime.thursday % 7,
          'الجمعة': DateTime.friday % 7,
          'السبت': DateTime.saturday % 7,
        };

        final currentDayValue = now.weekday % 7;
        final lessonDayValue = dayMap[currentLessonDay] ?? currentDayValue;

        int daysUntilLesson = (lessonDayValue - currentDayValue) % 7;
        if (daysUntilLesson == 0) {
          // Check if lesson is today but in the future
          final lessonTime = _parseTimeString(currentLessonTime);
          if (lessonTime != null &&
              (lessonTime.hour < now.hour ||
                  (lessonTime.hour == now.hour &&
                      lessonTime.minute <= now.minute))) {
            daysUntilLesson = 7; // Next week
          }
        }

        final lessonDate = now.add(Duration(days: daysUntilLesson));
        currentLessonDate =
            '${lessonDate.year}-${lessonDate.month.toString().padLeft(2, '0')}-${lessonDate.day.toString().padLeft(2, '0')}';
      }

      if (!mounted) return;

      // Show as modal bottom sheet to keep nav bar visible
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
                // Refresh schedules after successful postpone
                if (mounted) {
                  _loadNextLesson(forceRefresh: true);
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error opening postpone page: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ أثناء جلب الأوقات الحرة')));
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      if (kDebugMode) {
        print('_loadFamilyMembers: Starting to load family members...');
      }
      final members = await _authRepository.getFamilyMembers();
      if (kDebugMode) {
        print('_loadFamilyMembers: Received ${members.length} family members');
        for (var m in members) {
          print('_loadFamilyMembers: Member: id=${m.id}, name=${m.name}');
        }
      }
      if (mounted) {
        setState(() {
          _familyMembers = members;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading family members: $e');
      }
    }
  }

  Future<void> _switchAccount(Student newStudent) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );

      // Clear caches for the new student to ensure fresh data
      await _scheduleRepository.clearCache(newStudent.id);
      await _reportRepository.clearCache(newStudent.id);

      if (!mounted) return;

      await _authRepository.switchUser(newStudent);

      if (!mounted) return;

      // Clear local state before refreshing
      setState(() {
        _nextSchedule = null;
        _nextLesson = null;
        _nextLessonDateTime = null;
        _lastReport = null;
        _familyMembers = []; // Clear family members so they reload
        _timeUntilNextLesson = null;
        _countdownTimer?.cancel();
        _isLoading = true;
      });

      // Refresh profile - this will update the AuthBloc state
      context.read<AuthBloc>().add(GetStudentProfileEvent());

      // Pop loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Wait for AuthBloc to update with new student data
      // Poll for the new student ID with a timeout
      int attempts = 0;
      const maxAttempts = 10;
      bool foundNewStudent = false;

      while (attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;

        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated &&
            authState.student != null &&
            authState.student!.id == newStudent.id) {
          foundNewStudent = true;
          break;
        }
        attempts++;
      }

      if (!mounted) return;

      if (foundNewStudent) {
        // Now load dashboard data with the new student
        await _loadNextLesson(forceRefresh: true);
      } else {
        // Force load anyway after timeout
        await _loadNextLesson(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        // Pop loading dialog if still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تغيير الحساب: $e')),
        );
      }
    }
  }

  Future<void> _showAccountSelection(BuildContext context) async {
    if (_familyMembers.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingFamily = true;
        });
      }
      await _loadFamilyMembers();
      if (mounted) {
        setState(() {
          _loadingFamily = false;
        });
      }
    }

    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final currentStudentId =
        authState is AuthAuthenticated ? authState.student?.id : null;

    final RenderBox button = (_arrowKey.currentContext?.findRenderObject() ??
        context.findRenderObject()) as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Get button position in overlay coordinates
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    // Position the menu below the button
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx, // left
      buttonPosition.dy +
          buttonSize.height +
          8, // top - below button with 8px gap
      overlay.size.width - buttonPosition.dx - buttonSize.width, // right
      0, // bottom - let it grow upward if needed
    );

    final items = _familyMembers.isEmpty
        ? [
            const PopupMenuItem<Student>(
              enabled: false,
              child: Text(
                'لا توجد حسابات مرتبطة',
                style: TextStyle(fontFamily: 'Qatar', fontSize: 14),
                textAlign: TextAlign.right,
              ),
            )
          ]
        : _familyMembers.map((student) {
            final isSelected = student.id == currentStudentId;
            return PopupMenuItem<Student>(
              value: student,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFD4AF37), width: 1),
                        image: DecorationImage(
                          image: student.profileImageUrl != null &&
                                  student.profileImageUrl!.isNotEmpty
                              ? NetworkImage(student.profileImageUrl!)
                              : const AssetImage(
                                      'assets/images/male_avatar.webp')
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (student.lessonsName != null &&
                              student.lessonsName!.isNotEmpty)
                            Text(
                              student.displayLessonName,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check,
                          color: AppTheme.primaryColor, size: 18),
                  ],
                ),
              ),
            );
          }).toList();

    showMenu<Student>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: items,
    ).then((Student? selected) {
      if (selected != null && selected.id != currentStudentId) {
        _switchAccount(selected);
      }
    });
  }

  void _joinLesson() {
    if (_nextLesson == null) return;

    if (kDebugMode) {
      print('JoinLesson: Starting join process');
    }
    try {
      if (kDebugMode) {
        print('JoinLesson: Generating room name');
      }
      final roomName = _generateRoomName();
      if (kDebugMode) {
        print('JoinLesson: Room name generated: $roomName');
        print('JoinLesson: Getting participant name');
      }
      final participantName = _getParticipantName();
      if (kDebugMode) {
        print('JoinLesson: Participant name: $participantName');
        print('JoinLesson: Getting participant ID');
      }
      final participantId = _getParticipantId();
      if (kDebugMode) {
        print('JoinLesson: Participant ID: $participantId');
        print('JoinLesson: Pushing MeetingPage');
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MeetingPage(
            roomName: roomName,
            participantName: participantName,
            participantId: participantId,
            lessonName: _lessonName,
            teacherName: _teacherName,
          ),
        ),
      );
      if (kDebugMode) {
        print('JoinLesson: Navigation pushed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('JoinLesson Error: $e');
      }
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ'),
          content: Text('حدث خطأ أثناء محاولة الانضمام للدرس: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  String _generateRoomName() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated &&
        authState.student != null &&
        _nextLesson != null) {
      final student = authState.student!;

      // Create a DateTime from the schedule day and hour
      final lessonTime = _createLessonDateTime(_nextLesson!);

      return LiveKitService().generateRoomName(
        studentId: student.id.toString(),
        teacherId: student.teacherId?.toString() ?? '0',
        lessonTime: lessonTime,
      );
    }
    return 'default_room';
  }

  DateTime _createLessonDateTime(Schedule schedule) {
    final now = DateTime.now();

    if (schedule.isPostponed && schedule.postponedDate != null) {
      // Handle postponed schedules with specific dates
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
        if (kDebugMode) {
          print('Error parsing postponed date: $e');
        }
        // Fall back to regular schedule logic
      }
    }

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

    final scheduledDay = dayMap[schedule.day] ?? DateTime.sunday;
    final scheduledTime = _parseTimeString(schedule.hour) ?? DateTime.now();

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
    return DateTime(
      now.year,
      now.month,
      now.day + daysUntil,
      scheduledTime.hour,
      scheduledTime.minute,
    );
  }

  String _getParticipantName() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      return authState.student!.name;
    }
    return 'طالب';
  }

  String _getParticipantId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      return authState.student!.id.toString();
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding to account for the nav bar
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;
    // Calculate top padding for header
    final topPadding =
        MediaQuery.of(context).padding.top + 20.0; // Header height + spacing

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF8b0628),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const LoadingWidget();
            } else if (state is AuthAuthenticated && state.student != null) {
              final student = state.student!;

              return RefreshIndicator(
                onRefresh: () async {
                  // Clear family members so they reload fresh
                  setState(() {
                    _familyMembers = [];
                  });
                  context.read<AuthBloc>().add(GetStudentProfileEvent());
                  await _loadNextLesson(forceRefresh: true);
                  // Reload family members in the background
                  _loadFamilyMembers();
                },
                color: const Color(0xFFD4AF37),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.fromLTRB(0.0, topPadding, 0.0, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome header
                      Container(
                        margin: const EdgeInsets.only(bottom: 20.0, left: 24.0),
                        padding: const EdgeInsets.only(
                            right: 16.0, top: 12.0, bottom: 12.0, left: 20.0),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromARGB(
                                  255, 255, 255, 255), // Warm cream white
                              Color.fromARGB(
                                  255, 234, 234, 234), // Subtle gold tint
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.zero,
                            bottomLeft: Radius.circular(50),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB(120, 0, 0, 0),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 1,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(
                                      0x33FFFFFF), // 0.2 opacity white
                                  backgroundImage: student.profileImageUrl !=
                                              null &&
                                          student.profileImageUrl!.isNotEmpty
                                      ? NetworkImage(student.profileImageUrl!)
                                      : const AssetImage(
                                              'assets/images/male_avatar.webp')
                                          as ImageProvider),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً، ${student.name}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Black text
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                          28, 0, 0, 0), // Very light grey bg
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          student.displayLessonName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87, // Dark text
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12), // Separate arrow
                            GestureDetector(
                              onTap: () {
                                if (_arrowKey.currentContext != null) {
                                  _showAccountSelection(
                                      _arrowKey.currentContext!);
                                }
                              },
                              child: Container(
                                key: _arrowKey,
                                margin: const EdgeInsets.only(top: 24.0),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                      28, 0, 0, 0), // Very light grey bg
                                  borderRadius: BorderRadius.circular(24),
                                  border:
                                      Border.all(color: Colors.black, width: 1),
                                ),
                                child: _loadingFamily
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 24,
                                        color: Colors.black54,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),

                      // Quick Action Buttons Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // First button - الدروس القادمة
                            _buildQuickActionButton(
                              imagePath: 'assets/images/lottie.json',
                              label: 'الدروس القادمة',
                              onTap: () {
                                // TODO: Navigate to upcoming lessons
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Next Lesson Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildNextLessonSection(),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'حدث خطأ في تحميل البيانات',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'إعادة المحاولة',
                      onPressed: () {
                        context.read<AuthBloc>().add(GetStudentProfileEvent());
                      },
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // White card - positioned in the middle
            Positioned(
              top: 35, // Half of image height (70/2) to leave space for image
              left: 0,
              right: 0,
              bottom:
                  20, // Half of yellow pill height (35/2) to leave space for pill
              child: Container(
                decoration: BoxDecoration(
                  // Gradient background matching bottom nav bar
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255), // Warm cream white
                      Color.fromARGB(255, 234, 234, 234), // Subtle gray tint
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Lottie animation at TOP - half outside, half inside white card
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Lottie.asset(
                  imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  repeat: true, // Run continuously
                ),
              ),
            ),
            // Yellow pill at BOTTOM - half inside, half outside white card
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: Container(
                height: 25,
                decoration: BoxDecoration(
                  color: const Color(0xFFf6c302), // Yellow background
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color.fromARGB(135, 0, 0, 0).withOpacity(0.2),
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
    );
  }
}
