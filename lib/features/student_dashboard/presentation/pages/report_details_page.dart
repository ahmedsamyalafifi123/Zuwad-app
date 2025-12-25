import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/student_report.dart';

class ReportDetailsPage extends StatelessWidget {
  final StudentReport report;

  const ReportDetailsPage({super.key, required this.report});

  /// Format time from 24h (HH:mm:ss) to 12h format (Arabic)
  String _formatTime(String time) {
    if (time.isEmpty) return 'غير متوفر';

    try {
      // Parse the time string (expected format: HH:mm:ss or HH:mm)
      final parts = time.split(':');
      if (parts.isEmpty) return time;

      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      String period = hour >= 12 ? 'مساءً' : 'صباحاً';
      int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time; // Return original if parsing fails
    }
  }

  /// Get display value - show "غير متوفر" if empty
  String _getDisplayValue(String value) {
    return value.trim().isEmpty ? 'غير متوفر' : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'تفاصيل التقرير',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildDetailsCard('تفاصيل الحصة', [
              DetailItem(
                  label: 'رقم الجلسة', value: report.sessionNumber.toString()),
              DetailItem(
                  label: 'التاريخ', value: _getDisplayValue(report.date)),
              DetailItem(label: 'الوقت', value: _formatTime(report.time)),
              DetailItem(
                  label: 'مدة الدرس', value: '${report.lessonDuration} دقيقة'),
              DetailItem(
                  label: 'الحضور', value: _getDisplayValue(report.attendance)),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('التقييم', [
              DetailItem(
                  label: 'التقييم', value: _getDisplayValue(report.evaluation)),
              DetailItem(label: 'الدرجة', value: '${report.grade}'),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('محتوى الدرس', [
              DetailItem(
                  label: 'التسميع', value: _getDisplayValue(report.tasmii)),
              DetailItem(
                  label: 'التحفيظ', value: _getDisplayValue(report.tahfiz)),
              DetailItem(
                  label: 'المراجعة', value: _getDisplayValue(report.mourajah)),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('الواجب القادم', [
              DetailItem(
                  label: 'التسميع القادم',
                  value: _getDisplayValue(report.nextTasmii)),
              DetailItem(
                  label: 'المراجعة القادمة',
                  value: _getDisplayValue(report.nextMourajah)),
            ]),
            if (report.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailsCard('ملاحظات', [
                DetailItem(label: 'ملاحظات المعلم', value: report.notes),
              ]),
            ],
            if (report.zoomImageUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildZoomImage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1A8B0628), // 0.1 opacity primary
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment,
                  color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'تقرير الحصة رقم ${report.sessionNumber.toString()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تاريخ: ${report.date}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String title, List<DetailItem> details) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // 0.1 opacity grey
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final detail = details[index];
              final isNotAvailable = detail.value == 'غير متوفر';
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        detail.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isNotAvailable ? Colors.grey : Colors.black,
                          fontStyle: isNotAvailable
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZoomImage() {
    // Clean up the URL
    String imageUrl =
        report.zoomImageUrl.replaceAll(r'\\', '').replaceAll(r'\/', '/').trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // 0.1 opacity grey
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'صورة الحصة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey[100],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تعذر تحميل الصورة',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DetailItem {
  final String label;
  final String value;

  DetailItem({required this.label, required this.value});
}
