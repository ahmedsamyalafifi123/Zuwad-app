import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/models/teacher.dart';
import '../../domain/models/teacher_report.dart';
import '../../data/repositories/teacher_report_repository.dart';

class TeacherReportsHistoryPage extends StatefulWidget {
  final Teacher teacher;

  const TeacherReportsHistoryPage({super.key, required this.teacher});

  @override
  State<TeacherReportsHistoryPage> createState() =>
      _TeacherReportsHistoryPageState();
}

class _TeacherReportsHistoryPageState extends State<TeacherReportsHistoryPage> {
  final TeacherReportRepository _reportRepo = TeacherReportRepository();
  List<TeacherReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _reportRepo.getTeacherReports(
        widget.teacher.id,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading reports: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في تحميل التقارير';
          _isLoading = false;
        });
      }
    }
  }

  Color _getAttendanceColor(String attendance) {
    switch (attendance) {
      case 'حضور':
        return Colors.green;
      case 'غياب':
        return Colors.red;
      case 'تأجيل المعلم':
      case 'تأجيل ولي أمر':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showReportDetails(TeacherReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 234, 234, 234),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'تفاصيل التقرير',
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('الطالب', report.studentName),
              _buildDetailRow('الحصة رقم', report.sessionNumber.toString()),
              _buildDetailRow('التاريخ', report.date),
              _buildDetailRow('الوقت', report.time),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _getAttendanceColor(report.attendance).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getAttendanceColor(report.attendance),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      report.attendance == 'حضور'
                          ? Icons.check_circle
                          : report.attendance == 'غياب'
                              ? Icons.cancel
                              : Icons.schedule,
                      color: _getAttendanceColor(report.attendance),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.attendance,
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getAttendanceColor(report.attendance),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('التقييم', report.evaluation),
              if (report.grade > 0)
                _buildDetailRow('الدرجة', '${report.grade}'),
              if (report.tasmii.isNotEmpty)
                _buildDetailRow('التسميع', report.tasmii),
              if (report.tahfiz.isNotEmpty)
                _buildDetailRow('التحفيظ', report.tahfiz),
              if (report.mourajah.isNotEmpty)
                _buildDetailRow('المراجعة', report.mourajah),
              if (report.nextTasmii.isNotEmpty)
                _buildDetailRow('التسميع القادم', report.nextTasmii),
              if (report.nextMourajah.isNotEmpty)
                _buildDetailRow('المراجعة القادمة', report.nextMourajah),
              if (report.notes.isNotEmpty)
                _buildDetailRow('ملاحظات', report.notes),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF820c22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD4AF37),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadReports(forceRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                  ),
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reports.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF8b0628),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تقارير',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لم يتم إنشاء أي تقارير بعد',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate padding matching student dashboard
    final topPadding = MediaQuery.of(context).padding.top + 20.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF8b0628),
        child: RefreshIndicator(
          onRefresh: () => _loadReports(forceRefresh: true),
          color: const Color(0xFFD4AF37),
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(8.0, topPadding, 8.0, bottomPadding),
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final report = _reports[index];
              final attendanceColor = _getAttendanceColor(report.attendance);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255),
                      Color.fromARGB(255, 240, 240, 240),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(60, 0, 0, 0),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: attendanceColor.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () => _showReportDetails(report),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                report.studentName,
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: attendanceColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                report.attendance,
                                style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: attendanceColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              report.date,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              report.time,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'حصة ${report.sessionNumber}',
                                style: const TextStyle(
                                  fontFamily: 'Qatar',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (report.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
