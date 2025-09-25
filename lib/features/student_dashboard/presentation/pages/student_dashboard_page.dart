import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../services/livekit_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../meeting/presentation/pages/meeting_page.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/schedule.dart';
import 'postpone_page.dart';
import 'placeholder_page.dart';
import 'home_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _currentIndex = 2; // Start with the middle tab (dashboard)

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages
    _pages = [
      const HomePage(),
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
      _DashboardContent(),
      const PlaceholderPage(
        title: 'الملف الشخصي',
        icon: Icons.person_outline,
      ),
      const PlaceholderPage(
        title: 'الإعدادات',
        icon: Icons.settings_outlined,
      ),
    ];

    // Fetch student profile data when dashboard loads
    context.read<AuthBloc>().add(GetStudentProfileEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/zuwad.png',
                  height: 40,
                  width: 40,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('أكاديمية زواد'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutEvent());
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      extendBody:
          true, // This will make the body extend behind the bottom navigation bar
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 60,
            margin: const EdgeInsets.only(top: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              borderRadius: BorderRadius.circular(15), // 25% of 60px height
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home tab
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = 0),
                      customBorder: const CircleBorder(),
                      splashColor: const Color(0xFF8b0628).withOpacity(0.1),
                      highlightColor: const Color(0xFF8b0628).withOpacity(0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment,
                            size: 22,
                            color: _currentIndex == 0
                                ? const Color.fromARGB(255, 187, 153, 32)
                                : const Color(0xFF8b0628),
                          ),
                          Text(
                            'الإنجازات',
                            style: TextStyle(
                              color: _currentIndex == 0
                                  ? const Color.fromARGB(255, 187, 153, 32)
                                  : const Color(0xFF8b0628),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Notifications tab
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = 1),
                      customBorder: const CircleBorder(),
                      splashColor: const Color(0xFF8b0628).withOpacity(0.1),
                      highlightColor: const Color(0xFF8b0628).withOpacity(0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_outlined,
                            size: 22,
                            color: _currentIndex == 1
                                ? const Color.fromARGB(255, 187, 153, 32)
                                : const Color(0xFF8b0628),
                          ),
                          Text(
                            'مراسلة',
                            style: TextStyle(
                              color: _currentIndex == 1
                                  ? const Color.fromARGB(255, 187, 153, 32)
                                  : const Color(0xFF8b0628),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Middle spacer for the logo
                const Expanded(child: SizedBox()),

                // Profile tab
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = 3),
                      customBorder: const CircleBorder(),
                      splashColor: const Color(0xFF8b0628).withOpacity(0.1),
                      highlightColor: const Color(0xFF8b0628).withOpacity(0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 22,
                            color: _currentIndex == 3
                                ? const Color.fromARGB(255, 187, 153, 32)
                                : const Color(0xFF8b0628),
                          ),
                          Text(
                            'الملف',
                            style: TextStyle(
                              color: _currentIndex == 3
                                  ? const Color.fromARGB(255, 187, 153, 32)
                                  : const Color(0xFF8b0628),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Settings tab
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = 4),
                      customBorder: const CircleBorder(),
                      splashColor: const Color(0xFF8b0628).withOpacity(0.1),
                      highlightColor: const Color(0xFF8b0628).withOpacity(0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 22,
                            color: _currentIndex == 4
                                ? const Color.fromARGB(255, 187, 153, 32)
                                : const Color(0xFF8b0628),
                          ),
                          Text(
                            'الإعدادات',
                            style: TextStyle(
                              color: _currentIndex == 4
                                  ? const Color.fromARGB(255, 187, 153, 32)
                                  : const Color(0xFF8b0628),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center floating logo button that's half outside the navbar
          Positioned(
            top: -20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 2),
                customBorder: const CircleBorder(),
                splashColor: const Color(0xFF8b0628).withOpacity(0.2),
                highlightColor: const Color(0xFF8b0628).withOpacity(0.1),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _currentIndex == 2
                        ? const Color(0xFF8b0628)
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/zuwad.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
  StudentSchedule? _nextSchedule;
  Schedule? _nextLesson;
  String _teacherName = '';
  String _lessonName = '';
  bool _isLoading = true;
  Duration? _timeUntilNextLesson;
  Timer? _countdownTimer;

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
        _lessonName = student.lessonsName ?? 'درس';
        _teacherName = student.teacherName ?? 'المعلم';

        // Get next schedule with force refresh
        final nextSchedule = await _scheduleRepository.getNextSchedule(
          student.id,
          forceRefresh: forceRefresh,
        );

        if (nextSchedule != null) {
          setState(() {
            _nextSchedule = nextSchedule;
            if (nextSchedule.schedules.isNotEmpty) {
              _findNextLesson(nextSchedule.schedules);
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

  void _findNextLesson(List<Schedule> schedules) {
    if (schedules.isEmpty) {
      _nextLesson = null;
      return;
    }

    final now = DateTime.now();

    // Create a list of all upcoming lessons with their actual DateTime
    List<Map<String, dynamic>> upcomingLessons = [];

    for (var schedule in schedules) {
      DateTime? lessonDateTime;

      // Debug each schedule
      print(
          'Checking schedule: day=${schedule.day}, hour=${schedule.hour}, isPostponed=${schedule.isPostponed}, postponedDate=${schedule.postponedDate}');

      if (schedule.isPostponed && schedule.postponedDate != null) {
        // Handle postponed schedules with specific dates
        try {
          print(
              'Processing postponed schedule: ${schedule.day} at ${schedule.hour}, postponed_date: ${schedule.postponedDate}');
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          print('Parsed postponed date: $postponedDate');
          final lessonTime = _parseTimeString(schedule.hour);
          print('Parsed lesson time: $lessonTime');
          if (lessonTime != null) {
            lessonDateTime = DateTime(
              postponedDate.year,
              postponedDate.month,
              postponedDate.day,
              lessonTime.hour,
              lessonTime.minute,
            );
            print('Created postponed lesson DateTime: $lessonDateTime');
            print('Current time: $now');
            print(
                'Is postponed lesson in future? ${lessonDateTime.isAfter(now)}');
          } else {
            print('Failed to parse lesson time for postponed schedule');
          }
        } catch (e) {
          print('Error parsing postponed date: $e');
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

        lessonDateTime = DateTime(
          now.year,
          now.month,
          now.day + daysUntil,
          lessonTime.hour,
          lessonTime.minute,
        );
      }

      // Only include future lessons
      if (lessonDateTime != null && lessonDateTime.isAfter(now)) {
        print(
            'Adding upcoming lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime, isPostponed: ${schedule.isPostponed}');
        upcomingLessons.add({
          'schedule': schedule,
          'dateTime': lessonDateTime,
        });
      } else if (lessonDateTime != null) {
        print(
            'Skipping past lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime');
      }
    }

    // Sort by date/time and get the earliest one
    if (upcomingLessons.isNotEmpty) {
      print('Found ${upcomingLessons.length} upcoming lessons before sorting');
      upcomingLessons.sort((a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      print('Sorted upcoming lessons:');
      for (int i = 0; i < upcomingLessons.length; i++) {
        final lesson = upcomingLessons[i];
        final schedule = lesson['schedule'] as Schedule;
        final dateTime = lesson['dateTime'] as DateTime;
        print(
            '  $i: ${schedule.day} at ${schedule.hour}, dateTime: $dateTime, isPostponed: ${schedule.isPostponed}');
      }

      _nextLesson = upcomingLessons.first['schedule'] as Schedule;
      print(
          'Selected next lesson: ${_nextLesson!.day} at ${_nextLesson!.hour}, isPostponed: ${_nextLesson!.isPostponed}');
    } else {
      print('No upcoming lessons found');
      _nextLesson = null;
    }
  }

  void _updateCountdown() {
    if (_nextLesson != null) {
      final previousDuration = _timeUntilNextLesson;
      final newDuration =
          _scheduleRepository.getTimeUntilNextLesson(_nextLesson!);

      if (previousDuration == null ||
          previousDuration.inSeconds != newDuration?.inSeconds) {
        setState(() {
          _timeUntilNextLesson = newDuration;
        });
      }
    }
  }

  String _getDayNameInArabic(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      default:
        return '';
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

  Widget _buildNextLessonSection() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFf6c302), // Gold color for better visibility
          backgroundColor: Colors.white.withOpacity(0.2),
        ),
      );
    }

    if (_nextLesson == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'الدرس القادم',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFf6c302)),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadNextLesson(forceRefresh: true);
                  },
                  tooltip: 'تحديث الجدول',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد دروس مجدولة',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'الدرس القادم',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFf6c302)),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadNextLesson(forceRefresh: true);
                },
                tooltip: 'تحديث الجدول',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _lessonName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _nextLesson!.day,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.access_time,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _nextLesson!.hour,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'المعلم:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _teacherName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (_nextSchedule != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.timelapse,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'المدة:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated &&
                              state.student != null) {
                            return Text(
                              '${state.student!.lessonDuration} دقيقة',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            );
                          }
                          return const Text(
                            '-- دقيقة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_timeUntilNextLesson != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'الوقت المتبقي للدرس',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCountdownItem(
                        _timeUntilNextLesson!.inDays,
                        'يوم',
                      ),
                      _buildCountdownSeparator(),
                      _buildCountdownItem(
                        _timeUntilNextLesson!.inHours % 24,
                        'ساعة',
                      ),
                      _buildCountdownSeparator(),
                      _buildCountdownItem(
                        _timeUntilNextLesson!.inMinutes % 60,
                        'دقيقة',
                      ),
                      _buildCountdownSeparator(),
                      _buildCountdownItem(
                        _timeUntilNextLesson!.inSeconds % 60,
                        'ثانية',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildJoinLessonButton(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownItem(int value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildJoinLessonButton() {
    // Determine lesson duration in minutes
    int lessonDuration = 30; // fallback
    if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
      lessonDuration =
          int.tryParse(_nextSchedule!.lessonDuration) ?? lessonDuration;
    }

    // Compute canJoin: active from 15 minutes before start until lesson end
    bool canJoin = false;
    if (_timeUntilNextLesson != null) {
      final minutesUntilStart = _timeUntilNextLesson!.inMinutes;
      final minutesAfterStart = -minutesUntilStart; // negative if past start

      if (minutesUntilStart <= 15 && minutesAfterStart <= lessonDuration) {
        canJoin = true;
      }
    }

    // postpone button enabled only when join is disabled
    final canPostpone = !canJoin;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: canPostpone ? _openPostponePage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canPostpone ? Colors.white : Colors.grey[300],
              foregroundColor:
                  canPostpone ? AppTheme.primaryColor : Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: canPostpone ? 2 : 0,
            ),
            child: const Text('تأجيل الحصة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canJoin ? _joinLesson : null,
            icon: Icon(
              Icons.video_call,
              size: 20,
              color: canJoin ? Colors.white : Colors.grey[400],
            ),
            label: Text(
              'دخول الدرس',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: canJoin ? Colors.white : Colors.grey[400],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canJoin ? const Color(0xFFf6c302) : Colors.grey[300],
              foregroundColor: canJoin ? Colors.white : Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: canJoin ? 4 : 0,
            ),
          ),
        ),
      ],
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
          final lessonTime = _parseTimeString(currentLessonTime ?? '');
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostponePage(
            teacherId: teacherId,
            freeSlots: slots,
            studentLessonDuration: lessonDuration,
            currentLessonDay: currentLessonDay,
            currentLessonTime: currentLessonTime,
            currentLessonDate: currentLessonDate,
          ),
        ),
      );
    } catch (e) {
      print('Error opening postpone page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ أثناء جلب الأوقات الحرة')));
    }
  }

  void _joinLesson() {
    if (_nextLesson == null) return;

    print('JoinLesson: Starting join process');
    try {
      print('JoinLesson: Generating room name');
      final roomName = _generateRoomName();
      print('JoinLesson: Room name generated: $roomName');
      print('JoinLesson: Getting participant name');
      final participantName = _getParticipantName();
      print('JoinLesson: Participant name: $participantName');
      print('JoinLesson: Getting participant ID');
      final participantId = _getParticipantId();
      print('JoinLesson: Participant ID: $participantId');

      print('JoinLesson: Pushing MeetingPage');
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
      print('JoinLesson: Navigation pushed successfully');
    } catch (e) {
      print('JoinLesson Error: $e');
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
        print('Error parsing postponed date: $e');
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFF8b0628),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const LoadingWidget();
            } else if (state is AuthAuthenticated && state.student != null) {
              final student = state.student!;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً، ${student.name}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'نتمنى لك يوماً موفقاً',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Next Lesson Section
                    _buildNextLessonSection(),

                    const SizedBox(height: 20),

                    // Student Info Card
                    _buildCard(
                      title: 'معلومات الطالب',
                      icon: Icons.person,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('الاسم:', student.name),
                          _buildInfoRow('رقم الهاتف:', student.phone),
                          _buildInfoRow('المعرف:', '${student.mId}'),
                          if (student.teacherName != null &&
                              student.teacherName!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.school,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'معلومات المعلم',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow('المعلم:', student.teacherName!),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Lessons Info Card
                    _buildCard(
                      title: 'معلومات الدروس',
                      icon: Icons.menu_book,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                              'عدد الدروس:', '${student.lessonsNumber}'),
                          _buildInfoRow(
                              'مدة الدرس:', '${student.lessonDuration} دقيقة'),
                          _buildInfoRow(
                              'اسم الدرس:', student.lessonsName ?? ''),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions Card
                    _buildCard(
                      title: 'الإجراءات السريعة',
                      icon: Icons.flash_on,
                      child: Column(
                        children: [
                          _buildActionButton(
                            context: context,
                            icon: Icons.calendar_today,
                            title: 'جدول الحصص',
                            subtitle: 'عرض جدول الحصص القادمة',
                            onTap: () {
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => const PlaceholderPage(
                              //       title: 'جدول الحصص',
                              //       icon: Icons.calendar_today,
                              //     ),
                              //   ),
                              // );
                            },
                          ),
                          const Divider(),
                          _buildActionButton(
                            context: context,
                            icon: Icons.assignment,
                            title: 'تقارير الحصص',
                            subtitle: 'عرض تقارير الحصص السابقة',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HomePage(),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          _buildActionButton(
                            context: context,
                            icon: Icons.support_agent,
                            title: 'الدعم الفني',
                            subtitle: 'تواصل مع الدعم الفني',
                            onTap: () {
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => const PlaceholderPage(
                              //       title: 'الدعم الفني',
                              //       icon: Icons.support_agent,
                              //     ),
                              //   ),
                              // );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Notes Card
                    if (student.notes != null && student.notes!.isNotEmpty)
                      _buildCard(
                        title: 'ملاحظات',
                        icon: Icons.note,
                        child: Text(
                          student.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                  ],
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

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'غير متوفر' : value,
              style: TextStyle(
                fontSize: 14,
                color: value.isEmpty ? Colors.grey : Colors.black87,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
