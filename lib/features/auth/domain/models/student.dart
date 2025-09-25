class Student {
  final int id;
  final String name;
  final String phone;
  final int? teacherId;
  final String? teacherName;
  final int? supervisorId;
  final String? supervisorName;
  final int? lessonsNumber;
  final String? lessonDuration;
  final String? notes;
  final String? mId;
  final String? lessonsName;
  
  Student({
    required this.id,
    required this.name,
    required this.phone,
    this.teacherId,
    this.teacherName,
    this.supervisorId,
    this.supervisorName,
    this.lessonsNumber,
    this.lessonDuration,
    this.notes,
    this.mId,
    this.lessonsName,
  });
  
  factory Student.fromJson(Map<String, dynamic> json, Map<String, dynamic> userMeta) {
    // Get the user ID from SharedPreferences
    return Student(
      id: json['id'] ?? 0, // Provide a default value if id is null
      name: json['name'] ?? userMeta['name'] ?? '',
      phone: json['phone'] ?? userMeta['phone'] ?? '',
      teacherId: int.tryParse(userMeta['teacher_id']?.toString() ?? '0'),
      teacherName: userMeta['teacher_name']?.toString() ?? '',
      supervisorId: int.tryParse(userMeta['supervisor_id']?.toString() ?? '0'),
      supervisorName: userMeta['supervisor_name']?.toString() ?? '',
      lessonsNumber: int.tryParse(userMeta['lessons_number']?.toString() ?? '0'),
      lessonDuration: userMeta['lesson_duration']?.toString() ?? '',
      notes: userMeta['notes']?.toString() ?? '',
      mId: userMeta['m_id']?.toString() ?? '',
      lessonsName: userMeta['lessons_name']?.toString() ?? '',
    );
  }
  
  Student copyWith({
    int? id,
    String? name,
    String? phone,
    int? teacherId,
    String? teacherName,
    int? supervisorId,
    String? supervisorName,
    int? lessonsNumber,
    String? lessonDuration,
    String? notes,
    String? mId,
    String? lessonsName,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      lessonsNumber: lessonsNumber ?? this.lessonsNumber,
      lessonDuration: lessonDuration ?? this.lessonDuration,
      notes: notes ?? this.notes,
      mId: mId ?? this.mId,
      lessonsName: lessonsName ?? this.lessonsName,
    );
  }
  
  String toDebugString() {
    return 'Student{id: $id, name: $name, phone: $phone, teacherId: $teacherId, '
        'teacherName: $teacherName, lessonsNumber: $lessonsNumber, '
        'lessonDuration: $lessonDuration, notes: $notes, mId: $mId, '
        'lessonsName: $lessonsName}';
  }
}
