import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ReportFormDialog extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String date;
  final String time;
  final int lessonDuration;
  final int sessionNumber;
  final Future<int> Function(int studentId, String attendance) getSessionNumber;
  final Future<void> Function({
    required int studentId,
    required int teacherId,
    required String date,
    required String time,
    required String attendance,
    required int lessonDuration,
    int? sessionNumber,
    String? evaluation,
    int? grade,
    String? tasmii,
    String? tahfiz,
    String? mourajah,
    String? nextTasmii,
    String? nextMourajah,
    String? notes,
    String? zoomImageUrl,
  }) onSubmit;

  const ReportFormDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.time,
    required this.lessonDuration,
    required this.sessionNumber,
    required this.getSessionNumber,
    required this.onSubmit,
  });

  @override
  State<ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends State<ReportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedAttendance = 'حضور';
  int? _sessionNumber;
  bool _isLoading = false;
  bool _isSubmitting = false;

  final _gradeController = TextEditingController();
  final _tasmiiController = TextEditingController();
  final _tahfizController = TextEditingController();
  final _mourajahController = TextEditingController();
  final _nextTasmiiController = TextEditingController();
  final _nextMourajahController = TextEditingController();
  final _notesController = TextEditingController();

  File? _selectedImage;
  String? _selectedImageUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _attendanceOptions = [
    'حضور',
    'غياب',
    'تأجيل المعلم',
    'تأجيل ولي أمر',
    'تعويض الغياب',
    'تعويض التأجيل',
    'تجريبي',
    'اجازة معلم',
  ];

  final List<String> _evaluationOptions = [
    'ممتاز',
    'جيد جداً',
    'جيد',
    'مقبول',
    'ضعيف',
  ];

  String _selectedEvaluation = 'جيد';

  @override
  void initState() {
    super.initState();
    _sessionNumber = widget.sessionNumber;
    _loadSessionNumber();
  }

  Future<void> _loadSessionNumber() async {
    setState(() => _isLoading = true);
    try {
      final sessionNum = await widget.getSessionNumber(
        widget.studentId,
        _selectedAttendance,
      );
      if (mounted) {
        setState(() {
          _sessionNumber = sessionNum;
        });
      }
    } catch (e) {
      // Use widget's session number on error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitReport(int teacherId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        studentId: widget.studentId,
        teacherId: teacherId,
        date: widget.date,
        time: widget.time,
        attendance: _selectedAttendance,
        lessonDuration: widget.lessonDuration,
        sessionNumber: _sessionNumber,
        evaluation: _selectedEvaluation,
        grade: _gradeController.text.isNotEmpty
            ? int.tryParse(_gradeController.text)
            : null,
        tasmii:
            _tasmiiController.text.isNotEmpty ? _tasmiiController.text : null,
        tahfiz:
            _tahfizController.text.isNotEmpty ? _tahfizController.text : null,
        mourajah: _mourajahController.text.isNotEmpty
            ? _mourajahController.text
            : null,
        nextTasmii: _nextTasmiiController.text.isNotEmpty
            ? _nextTasmiiController.text
            : null,
        nextMourajah: _nextMourajahController.text.isNotEmpty
            ? _nextMourajahController.text
            : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        zoomImageUrl: _selectedImageUrl,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة التقرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildTwoFieldRow({
    required String label1,
    required String label2,
    required TextEditingController controller1,
    required TextEditingController controller2,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller1,
            decoration: InputDecoration(
              labelText: label1,
              labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller2,
            decoration: InputDecoration(
              labelText: label2,
              labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _tasmiiController.dispose();
    _tahfizController.dispose();
    _mourajahController.dispose();
    _nextTasmiiController.dispose();
    _nextMourajahController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                  'إضافة تقرير',
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Student Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.studentName,
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.date,
                          style: const TextStyle(fontFamily: 'Qatar'),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.time,
                          style: const TextStyle(fontFamily: 'Qatar'),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.lessonDuration} د',
                          style: const TextStyle(fontFamily: 'Qatar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Session Number
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.confirmation_number,
                          color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Text(
                        'الحصة رقم: ${_sessionNumber ?? widget.sessionNumber}',
                        style: const TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Attendance and Evaluation Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAttendance,
                      decoration: InputDecoration(
                        labelText: 'الحضور',
                        labelStyle:
                            const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: _attendanceOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                                fontFamily: 'Qatar', fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedAttendance = newValue);
                          _loadSessionNumber();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedEvaluation,
                      decoration: InputDecoration(
                        labelText: 'التقييم',
                        labelStyle:
                            const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: _evaluationOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                                fontFamily: 'Qatar', fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedEvaluation = newValue);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grade
              TextFormField(
                controller: _gradeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'الدرجة',
                  labelStyle: const TextStyle(fontFamily: 'Qatar'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tasmii and Tahfiz Row
              _buildTwoFieldRow(
                label1: 'التسميع',
                label2: 'التحفيظ',
                controller1: _tasmiiController,
                controller2: _tahfizController,
              ),
              const SizedBox(height: 16),

              // Mourajah
              TextFormField(
                controller: _mourajahController,
                decoration: InputDecoration(
                  labelText: 'المراجعة',
                  labelStyle: const TextStyle(fontFamily: 'Qatar'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Next Tasmii and Next Mourajah Row
              _buildTwoFieldRow(
                label1: 'التسميع القادم',
                label2: 'المراجعة القادمة',
                controller1: _nextTasmiiController,
                controller2: _nextMourajahController,
              ),
              const SizedBox(height: 16),

              // Notes and Image Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        labelStyle: const TextStyle(fontFamily: 'Qatar'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صورة الحصة',
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _selectedImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _selectedImage!,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImage = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        color: Colors.grey[400],
                                        size: 28,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'اختر صورة',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () =>
                          _submitReport(0), // Will need teacher ID from parent
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF820c22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'حفظ التقرير',
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
}
