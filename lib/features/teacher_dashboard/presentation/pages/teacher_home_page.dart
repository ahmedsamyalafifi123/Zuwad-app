import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../auth/domain/models/teacher.dart';
import '../../domain/models/teacher_schedule.dart';
import '../../data/repositories/teacher_schedule_repository.dart';
import '../../../student_dashboard/domain/models/schedule.dart';
import '../../../../core/utils/gender_helper.dart';

class TeacherHomePage extends StatefulWidget {
  final Teacher teacher;

  const TeacherHomePage({super.key, required this.teacher});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TeacherScheduleRepository _scheduleRepo = TeacherScheduleRepository();

  List<TeacherSchedule> _schedules = [];
  TeacherSchedule? _nextSchedule;
  Schedule? _nextLesson;
  String _nextStudentName = '';
  String? _nextStudentImage;
  String _nextStudentGender = 'ذكر';
  String _lessonDuration = '30';
  DateTime? _nextLessonDateTime;
  Duration? _timeUntilNextLesson;
  Timer? _countdownTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      setState(() => _isLoading = true);

      final schedules = await _scheduleRepo.getTeacherSchedules(
        widget.teacher.id,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _schedules = schedules;
          _findNextLesson();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading schedules: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _findNextLesson() {
    if (_schedules.isEmpty) {
      _nextLesson = null;
      _nextSchedule = null;
      return;
    }

    final now = DateTime.now();
    final dayMap = {
      'الأحد': DateTime.sunday,
      'الاثنين': DateTime.monday,
      'الثلاثاء': DateTime.tuesday,
      'الأربعاء': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'الجمعة': DateTime.friday,
      'السبت': DateTime.saturday,
    };

    final List<Map<String, dynamic>> upcomingLessons = [];

    for (final schedule in _schedules) {
      for (final slot in schedule.schedules) {
        final scheduledDay = dayMap[slot.day];
        if (scheduledDay == null) continue;

        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil < 0) daysUntil += 7;

        final timeParts = slot.hour.trim().split(' ');
        if (timeParts.length != 2) continue;

        final hourMinute = timeParts[0].split(':');
        if (hourMinute.length != 2) continue;

        int hour = int.tryParse(hourMinute[0]) ?? 0;
        final int minute = int.tryParse(hourMinute[1]) ?? 0;
        final String ampm = timeParts[1].toUpperCase();

        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;

        final lessonDateTime = DateTime(
          now.year,
          now.month,
          now.day + daysUntil,
          hour,
          minute,
        );

        if (lessonDateTime.isAfter(now)) {
          upcomingLessons.add({
            'schedule': schedule,
            'slot': slot,
            'dateTime': lessonDateTime,
          });
        }
      }
    }

    upcomingLessons.sort((a, b) =>
        (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

    if (upcomingLessons.isNotEmpty) {
      final next = upcomingLessons.first;
      final sched = next['schedule'] as TeacherSchedule;
      final studentInfo = widget.teacher.students.firstWhere(
        (s) => s.id == sched.studentId,
        orElse: () => widget.teacher.students.first,
      );
      setState(() {
        _nextSchedule = sched;
        _nextLesson = next['slot'] as Schedule;
        _nextStudentName = sched.studentName;
        _nextStudentImage = studentInfo.profileImage;
        _nextStudentGender = studentInfo.gender ?? 'ذكر';
        _lessonDuration = sched.lessonDuration;
        _nextLessonDateTime = next['dateTime'] as DateTime;
      });

      _startCountdown();
    } else {
      setState(() {
        _nextLesson = null;
        _nextSchedule = null;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    if (_nextLessonDateTime != null) {
      _updateCountdown();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _updateCountdown();
        }
      });
    }
  }

  void _updateCountdown() {
    if (_nextLessonDateTime == null) return;

    final now = DateTime.now();
    final difference = _nextLessonDateTime!.difference(now);

    if (mounted) {
      setState(() {
        if (difference.isNegative) {
          _timeUntilNextLesson = Duration.zero;
        } else {
          _timeUntilNextLesson = difference;
        }
      });
    }
  }

  String _getArabicDayName(DateTime date) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return days[date.weekday - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final ampm = hour >= 12 ? 'م' : 'ص';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:${minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 20.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF8b0628),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.0, topPadding, 16.0, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header with gradient
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255),
                      Color.fromARGB(255, 234, 234, 234),
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
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26D4AF37),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.teacher.profileImage != null &&
                                widget.teacher.profileImage!.isNotEmpty
                            ? Image.network(
                                widget.teacher.profileImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  GenderHelper.isFemale(widget.teacher.gender)
                                      ? 'assets/images/woman.png'
                                      : 'assets/images/man.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                GenderHelper.isFemale(widget.teacher.gender)
                                    ? 'assets/images/woman.png'
                                    : 'assets/images/man.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً،',
                            style: TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.teacher.name,
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildNextLessonSection(),
              const SizedBox(height: 18),
              const Divider(color: Colors.white, height: 1, thickness: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextLessonSection() {
    final isFemale = widget.teacher.gender == 'أنثى';
    final teacherAvatar =
        isFemale ? 'assets/images/woman.png' : 'assets/images/man.png';

    if (_isLoading) {
      return Center(
        child: Container(
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
          child: const CircularProgressIndicator(
            color: Color(0xFFD4AF37),
          ),
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

    return Column(
      children: [
        // Gradient box with lesson info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 230, 230, 230),
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
              // Main row: Student name (right) | Avatar (center) | Day+Time (left)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Right: Student name
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الحصة القادمة',
                      style: const TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Center: Avatar + الطالب + Student name
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              const Color.fromARGB(255, 230, 230, 230),
                          backgroundImage: _nextStudentImage != null &&
                                  _nextStudentImage!.isNotEmpty
                              ? NetworkImage(_nextStudentImage!)
                              : AssetImage(
                                  GenderHelper.isFemale(_nextStudentGender)
                                      ? 'assets/images/woman.png'
                                      : 'assets/images/man.png',
                                ) as ImageProvider,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الطالب',
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _nextStudentName.split(' ').first,
                              style: const TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Left: Day + Time
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _nextLessonDateTime != null
                              ? _getArabicDayName(_nextLessonDateTime!)
                              : _nextLesson!.day,
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nextLessonDateTime != null
                              ? _formatTime(_nextLessonDateTime!)
                              : _nextLesson!.hour,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 14,
                            color: Colors.grey[700],
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
                        offset: const Offset(0, -2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'الوقـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــت',
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
                            SizedBox(height: 8),
                            Text(
                              'المتبقـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــي',
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
                          const SizedBox(width: 50),
                          if (_timeUntilNextLesson!.inDays > 0) ...[
                            _buildCountdownItem(
                              _timeUntilNextLesson!.inDays,
                              'يوم',
                            ),
                            const SizedBox(width: 8),
                          ],
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inHours % 24,
                            'ساعة',
                          ),
                          const SizedBox(width: 8),
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inMinutes % 60,
                            'دقيقة',
                          ),
                          const SizedBox(width: 8),
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inSeconds % 60,
                            'ثانية',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownItem(int value, String label) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              height: 1.0,
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
}
