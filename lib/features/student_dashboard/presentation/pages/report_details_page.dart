import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/student_report.dart';

class ReportDetailsPage extends StatelessWidget {
  final StudentReport report;

  const ReportDetailsPage({super.key, required this.report});

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
              DetailItem(label: 'التاريخ', value: report.date),
              DetailItem(label: 'الوقت', value: report.time),
              DetailItem(
                  label: 'مدة الدرس', value: '${report.lessonDuration} دقيقة'),
              DetailItem(label: 'الحضور', value: report.attendance),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('التقييم', [
              DetailItem(label: 'التقييم', value: report.evaluation),
              DetailItem(label: 'الدرجة', value: '${report.grade}'),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('محتوى الدرس', [
              DetailItem(label: 'التسميع', value: report.tasmii),
              DetailItem(label: 'التحفيظ', value: report.tahfiz),
              DetailItem(label: 'المراجعة', value: report.mourajah),
            ]),
            const SizedBox(height: 16),
            _buildDetailsCard('الواجب القادم', [
              DetailItem(label: 'التسميع القادم', value: report.nextTasmii),
              DetailItem(label: 'المراجعة القادمة', value: report.nextMourajah),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
              report.zoomImageUrl.replaceAll(r'\\', ''),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading image: $error');
                debugPrint('Failed image URL: ${report.zoomImageUrl}');
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 48,
                    ),
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
