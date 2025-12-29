import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/student_report.dart';
import '../../domain/models/schedule.dart';
import 'report_details_page.dart';
import 'postpone_page.dart';

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
        _findNextTwoLessons(nextSchedule.schedules, _reports);
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
      List<Schedule> schedules, List<StudentReport> reports) {
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

        lessonDateTime = DateTime(
          now.year,
          now.month,
          now.day + daysUntil,
          lessonTime.hour,
          lessonTime.minute,
        );

        lessonDateStr =
            '${lessonDateTime.year}-${lessonDateTime.month.toString().padLeft(2, '0')}-${lessonDateTime.day.toString().padLeft(2, '0')}';
      }

      // Check if this lesson date+time already has a report
      // Only check reports for regular schedules, NOT postponed schedules
      final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);
      final regularLessonKey = '$lessonDateStr|$regularLessonTimeStr';
      if (!schedule.isPostponed && reportDateTimes.contains(regularLessonKey)) {
        continue; // Skip this regular schedule, a report already exists for this date+time
      }

      // Only include future lessons
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
            return _buildNextLessonCard(lessonData['schedule'] as Schedule,
                lessonData['dateTime'] as DateTime);
          },
        ),
      ],
    );
  }

  Widget _buildNextLessonCard(Schedule schedule, DateTime dateTime) {
    // Format date nicely (e.g., 2024-05-20)
    final dateStr =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // 0.1 opacity grey
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اليوم: ${schedule.day}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'التاريخ: $dateStr',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الوقت: ${schedule.hour}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Postpone Button
                ElevatedButton(
                  onPressed: () => _openPostponePage(schedule, dateTime),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 1,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'تأجيل الحصة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (schedule.isPostponed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: const Text(
                  'هذه الحصة مؤجلة',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000), // 0.1 opacity grey
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الحصة رقم ${report.sessionNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEvaluationColor(report.evaluation),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.evaluation.isEmpty
                          ? 'غير متوفر'
                          : report.evaluation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'تاريخ: ${report.date}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'مدة الدرس: ${report.lessonDuration} دقيقة',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (report.nextTasmii.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'التسميع القادم: ${report.nextTasmii}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'عرض الإنجاز',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.secondaryColor,
                  ),
                ],
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
              // Next Lessons Section (New)
              _buildNextLessonsSection(),

              const SizedBox(height: 16),

              // Reports Section
              _buildReportsSection(),

              // Add extra padding at the bottom
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
