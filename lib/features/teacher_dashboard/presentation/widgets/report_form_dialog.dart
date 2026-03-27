import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const List<Map<String, dynamic>> QURAN_SURAH = [
  {"id": 114, "name": "الناس", "ayat": 6},
  {"id": 113, "name": "الفلق", "ayat": 5},
  {"id": 112, "name": "الإخلاص", "ayat": 4},
  {"id": 111, "name": "المسد", "ayat": 5},
  {"id": 110, "name": "النصر", "ayat": 3},
  {"id": 109, "name": "الكافرون", "ayat": 6},
  {"id": 108, "name": "الكوثر", "ayat": 3},
  {"id": 107, "name": "الماعون", "ayat": 7},
  {"id": 106, "name": "قريش", "ayat": 4},
  {"id": 105, "name": "الفيل", "ayat": 5},
  {"id": 104, "name": "الهمزة", "ayat": 9},
  {"id": 103, "name": "العصر", "ayat": 3},
  {"id": 102, "name": "التكاثر", "ayat": 8},
  {"id": 101, "name": "القارعة", "ayat": 11},
  {"id": 100, "name": "العاديات", "ayat": 11},
  {"id": 99, "name": "الزلزلة", "ayat": 8},
  {"id": 98, "name": "البينة", "ayat": 8},
  {"id": 97, "name": "القدر", "ayat": 5},
  {"id": 96, "name": "العلق", "ayat": 19},
  {"id": 95, "name": "التين", "ayat": 8},
  {"id": 94, "name": "الشرح", "ayat": 8},
  {"id": 93, "name": "الضحى", "ayat": 11},
  {"id": 92, "name": "الليل", "ayat": 21},
  {"id": 91, "name": "الشمس", "ayat": 15},
  {"id": 90, "name": "البلد", "ayat": 20},
  {"id": 89, "name": "الفجر", "ayat": 30},
  {"id": 88, "name": "الغاشية", "ayat": 26},
  {"id": 87, "name": "الأعلى", "ayat": 19},
  {"id": 86, "name": "الطارق", "ayat": 17},
  {"id": 85, "name": "البروج", "ayat": 22},
  {"id": 84, "name": "الانشقاق", "ayat": 25},
  {"id": 83, "name": "المطففين", "ayat": 36},
  {"id": 82, "name": "الانفطار", "ayat": 19},
  {"id": 81, "name": "التكوير", "ayat": 29},
  {"id": 80, "name": "عبس", "ayat": 42},
  {"id": 79, "name": "النازعات", "ayat": 46},
  {"id": 78, "name": "النبأ", "ayat": 40},
  {"id": 77, "name": "المرسلات", "ayat": 50},
  {"id": 76, "name": "الإنسان", "ayat": 31},
  {"id": 75, "name": "القيامة", "ayat": 40},
  {"id": 74, "name": "المدثر", "ayat": 56},
  {"id": 73, "name": "المزمل", "ayat": 20},
  {"id": 72, "name": "الجن", "ayat": 28},
  {"id": 71, "name": "نوح", "ayat": 28},
  {"id": 70, "name": "المعارج", "ayat": 44},
  {"id": 69, "name": "الحاقة", "ayat": 52},
  {"id": 68, "name": "القلم", "ayat": 52},
  {"id": 67, "name": "الملك", "ayat": 30},
  {"id": 66, "name": "التحريم", "ayat": 12},
  {"id": 65, "name": "الطلاق", "ayat": 12},
  {"id": 64, "name": "التغابن", "ayat": 18},
  {"id": 63, "name": "المنافقون", "ayat": 11},
  {"id": 62, "name": "الجمعة", "ayat": 11},
  {"id": 61, "name": "الصف", "ayat": 14},
  {"id": 60, "name": "الممتحنة", "ayat": 13},
  {"id": 59, "name": "الحشر", "ayat": 24},
  {"id": 58, "name": "المجادلة", "ayat": 22},
  {"id": 57, "name": "الحديد", "ayat": 29},
  {"id": 56, "name": "الواقعة", "ayat": 96},
  {"id": 55, "name": "الرحمن", "ayat": 78},
  {"id": 54, "name": "القمر", "ayat": 55},
  {"id": 53, "name": "النجم", "ayat": 62},
  {"id": 52, "name": "الطور", "ayat": 49},
  {"id": 51, "name": "الذاريات", "ayat": 60},
  {"id": 50, "name": "ق", "ayat": 45},
  {"id": 49, "name": "الحجرات", "ayat": 18},
  {"id": 48, "name": "الفتح", "ayat": 29},
  {"id": 47, "name": "محمد", "ayat": 38},
  {"id": 46, "name": "الأحقاف", "ayat": 35},
  {"id": 45, "name": "الجاثية", "ayat": 37},
  {"id": 44, "name": "الدخان", "ayat": 59},
  {"id": 43, "name": "الزخرف", "ayat": 89},
  {"id": 42, "name": "الشورى", "ayat": 53},
  {"id": 41, "name": "فصلت", "ayat": 54},
  {"id": 40, "name": "غافر", "ayat": 85},
  {"id": 39, "name": "الزمر", "ayat": 75},
  {"id": 38, "name": "ص", "ayat": 88},
  {"id": 37, "name": "الصافات", "ayat": 182},
  {"id": 36, "name": "يس", "ayat": 83},
  {"id": 35, "name": "فاطر", "ayat": 45},
  {"id": 34, "name": "سبأ", "ayat": 54},
  {"id": 33, "name": "الأحزاب", "ayat": 73},
  {"id": 32, "name": "السجدة", "ayat": 30},
  {"id": 31, "name": "لقمان", "ayat": 34},
  {"id": 30, "name": "الروم", "ayat": 60},
  {"id": 29, "name": "العنكبوت", "ayat": 69},
  {"id": 28, "name": "القصص", "ayat": 88},
  {"id": 27, "name": "النمل", "ayat": 93},
  {"id": 26, "name": "الشعراء", "ayat": 227},
  {"id": 25, "name": "الفرقان", "ayat": 77},
  {"id": 24, "name": "النور", "ayat": 64},
  {"id": 23, "name": "المؤمنون", "ayat": 118},
  {"id": 22, "name": "الحج", "ayat": 78},
  {"id": 21, "name": "الأنبياء", "ayat": 112},
  {"id": 20, "name": "طه", "ayat": 135},
  {"id": 19, "name": "مريم", "ayat": 98},
  {"id": 18, "name": "الكهف", "ayat": 110},
  {"id": 17, "name": "الإسراء", "ayat": 111},
  {"id": 16, "name": "النحل", "ayat": 128},
  {"id": 15, "name": "الحجر", "ayat": 99},
  {"id": 14, "name": "إبراهيم", "ayat": 52},
  {"id": 13, "name": "الرعد", "ayat": 43},
  {"id": 12, "name": "يوسف", "ayat": 111},
  {"id": 11, "name": "هود", "ayat": 123},
  {"id": 10, "name": "يونس", "ayat": 109},
  {"id": 9, "name": "التوبة", "ayat": 129},
  {"id": 8, "name": "الأنفال", "ayat": 75},
  {"id": 7, "name": "الأعراف", "ayat": 206},
  {"id": 6, "name": "الأنعام", "ayat": 165},
  {"id": 5, "name": "المائدة", "ayat": 120},
  {"id": 4, "name": "النساء", "ayat": 176},
  {"id": 3, "name": "آل عمران", "ayat": 200},
  {"id": 2, "name": "البقرة", "ayat": 286},
  {"id": 1, "name": "الفاتحة", "ayat": 7},
];

class ReportFormDialog extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String date;
  final String time;
  final int lessonDuration;
  final int sessionNumber;
  final Future<int> Function(int studentId, String attendance) getSessionNumber;
  final Future<String?> Function(File imageFile)? onUploadImage;
  final Future<void> Function({
    required int studentId,
    required int teacherId,
    required String date,
    required String time,
    required String attendance,
    required int lessonDuration,
    int? sessionNumber,
    String? evaluation,
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
    this.onUploadImage,
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
  bool _isUploadingImage = false;

  final _tasmiiController = TextEditingController();
  final _tahfizController = TextEditingController();
  final _mourajahController = TextEditingController();
  final _nextMourajahController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedSurahId;
  int? _selectedAyahFrom;
  int? _selectedAyahTo;

  File? _selectedImage;
  String? _uploadedImageUrl;
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
    'ماهر ⭐⭐⭐⭐⭐',
    'محترف ⭐⭐⭐⭐',
    'رائع ⭐⭐⭐',
    'متميز ⭐⭐',
    'مجتهد ⭐',
  ];

  String _selectedEvaluation = 'رائع ⭐⭐⭐';

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

  String _buildNextTasmiiValue() {
    if (_selectedSurahId == null) return '';
    
    final surah = QURAN_SURAH.firstWhere((s) => s['id'] == _selectedSurahId);
    String result = surah['name'] as String;
    
    if (_selectedAyahFrom != null && _selectedAyahTo != null) {
      result += ' $_selectedAyahFrom-$_selectedAyahTo';
    } else if (_selectedAyahFrom != null) {
      result += ' $_selectedAyahFrom';
    }
    
    return result;
  }

  int _getSurahAyatCount(int? surahId) {
    if (surahId == null) return 0;
    final surah = QURAN_SURAH.firstWhere((s) => s['id'] == surahId);
    return surah['ayat'] as int;
  }

  Future<void> _submitReport(int teacherId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      
      if (_selectedImage != null && widget.onUploadImage != null) {
        setState(() => _isUploadingImage = true);
        try {
          imageUrl = await widget.onUploadImage!(_selectedImage!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في رفع الصورة: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        setState(() => _isUploadingImage = false);
      }
      
      final nextTasmiiValue = _buildNextTasmiiValue();
      
      await widget.onSubmit(
        studentId: widget.studentId,
        teacherId: teacherId,
        date: widget.date,
        time: widget.time,
        attendance: _selectedAttendance,
        lessonDuration: widget.lessonDuration,
        sessionNumber: _sessionNumber,
        evaluation: _selectedEvaluation,
        tasmii: _tasmiiController.text.isNotEmpty ? _tasmiiController.text : null,
        tahfiz: _tahfizController.text.isNotEmpty ? _tahfizController.text : null,
        mourajah: _mourajahController.text.isNotEmpty ? _mourajahController.text : null,
        nextTasmii: nextTasmiiValue.isNotEmpty ? nextTasmiiValue : null,
        nextMourajah: _nextMourajahController.text.isNotEmpty ? _nextMourajahController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        zoomImageUrl: imageUrl,
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

  @override
  void dispose() {
    _tasmiiController.dispose();
    _tahfizController.dispose();
    _mourajahController.dispose();
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
                        Text(widget.date, style: const TextStyle(fontFamily: 'Qatar')),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(widget.time, style: const TextStyle(fontFamily: 'Qatar')),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 8),
                        Text('${widget.lessonDuration} د', style: const TextStyle(fontFamily: 'Qatar')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                      const Icon(Icons.confirmation_number, color: Color(0xFFD4AF37)),
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

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAttendance,
                      decoration: InputDecoration(
                        labelText: 'الحضور',
                        labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _attendanceOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontFamily: 'Qatar', fontSize: 12)),
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
                        labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _evaluationOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontFamily: 'Qatar', fontSize: 11), overflow: TextOverflow.ellipsis),
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

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tasmiiController,
                      decoration: InputDecoration(
                        labelText: 'التسميع',
                        labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _tahfizController,
                      decoration: InputDecoration(
                        labelText: 'التحفيظ',
                        labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _mourajahController,
                decoration: InputDecoration(
                  labelText: 'المراجعة',
                  labelStyle: const TextStyle(fontFamily: 'Qatar'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سيتم تسميع', style: TextStyle(fontFamily: 'Qatar', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedSurahId,
                      decoration: InputDecoration(
                        labelText: 'السورة',
                        labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: QURAN_SURAH.map((surah) {
                        return DropdownMenuItem<int>(
                          value: surah['id'] as int,
                          child: Text('${surah['id']}. ${surah['name']}', style: const TextStyle(fontFamily: 'Qatar', fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSurahId = value;
                          _selectedAyahFrom = null;
                          _selectedAyahTo = null;
                        });
                      },
                    ),
                    if (_selectedSurahId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedAyahFrom,
                              decoration: InputDecoration(
                                labelText: 'من آية',
                                labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: List.generate(_getSurahAyatCount(_selectedSurahId), (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Qatar', fontSize: 12)))),
                              onChanged: (value) => setState(() => _selectedAyahFrom = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedAyahTo,
                              decoration: InputDecoration(
                                labelText: 'إلى آية',
                                labelStyle: const TextStyle(fontFamily: 'Qatar', fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: List.generate(_getSurahAyatCount(_selectedSurahId), (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Qatar', fontSize: 12)))),
                              onChanged: (value) => setState(() => _selectedAyahTo = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nextMourajahController,
                decoration: InputDecoration(
                  labelText: 'المراجعة القادمة',
                  labelStyle: const TextStyle(fontFamily: 'Qatar'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('صورة الحصة', style: TextStyle(fontFamily: 'Qatar', fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImage,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : _selectedImage != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(_selectedImage!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => setState(() { _selectedImage = null; _uploadedImageUrl = null; }),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate, color: Colors.grey[400], size: 28),
                                          const SizedBox(height: 4),
                                          Text('اختر صورة', style: TextStyle(fontFamily: 'Qatar', fontSize: 10, color: Colors.grey[500])),
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting || _isUploadingImage ? null : () => _submitReport(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF820c22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التقرير', style: TextStyle(fontFamily: 'Qatar', fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
