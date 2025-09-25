import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/schedule.dart';
import '../../domain/models/student_report.dart';
import 'report_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final ReportRepository _reportRepository = ReportRepository();
  StudentSchedule? _nextSchedule;
  Schedule? _nextLesson;
  final String _teacherName = '';
  final String _lessonName = '';
  final bool _isLoading = true;
  Duration? _timeUntilNextLesson;
  Timer? _countdownTimer;
  List<StudentReport> _reports = [];
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReports({bool forceRefresh = false}) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      try {
        setState(() {
          _isLoadingReports = true;
        });

        // Get student reports with force refresh
        final reports = await _reportRepository.getStudentReports(
          authState.student!.id,
          forceRefresh: forceRefresh,
        );

        setState(() {
          _reports = reports;
        });
      } catch (e) {
        setState(() {
          _reports = [];
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل التقارير: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoadingReports = false;
        });
      }
    }
  }

  Widget _buildDecorativeHeading(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative border
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFf6c302).withOpacity(0.5),
                  const Color(0xFFf6c302),
                  const Color(0xFFf6c302).withOpacity(0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
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
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: const Color(0xFFf6c302).withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      color: const Color(0xFFf6c302).withOpacity(0.5),
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
                      fontSize: 20, // Slightly reduced font size
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
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: const Color(0xFFf6c302).withOpacity(0.5),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      color: const Color(0xFFf6c302).withOpacity(0.7),
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
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
              Row(
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
                  const Icon(
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
          await _loadReports(forceRefresh: true);
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reports Section
              _buildReportsSection(),

              const SizedBox(height: 24),

              // Add extra padding at the bottom to ensure content is visible above the nav bar
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
