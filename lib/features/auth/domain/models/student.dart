class Student {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final int? teacherId;
  final String? teacherName;
  final int? supervisorId;
  final String? supervisorName;
  final int? lessonsNumber;
  final String? lessonDuration;
  final String? paymentStatus;
  final double? amount;
  final String? currency;
  final String? notes;
  final String? mId;
  final String? lessonsName;

  Student({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.teacherId,
    this.teacherName,
    this.supervisorId,
    this.supervisorName,
    this.lessonsNumber,
    this.lessonDuration,
    this.paymentStatus,
    this.amount,
    this.currency,
    this.notes,
    this.mId,
    this.lessonsName,
  });

  /// Parse from legacy API response (two separate calls)
  factory Student.fromJson(
      Map<String, dynamic> json, Map<String, dynamic> userMeta) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? userMeta['name'] ?? '',
      phone: json['phone'] ?? userMeta['phone'] ?? '',
      email: userMeta['email']?.toString(),
      teacherId: int.tryParse(userMeta['teacher_id']?.toString() ?? '0'),
      teacherName: userMeta['teacher_name']?.toString() ?? '',
      supervisorId: int.tryParse(userMeta['supervisor_id']?.toString() ?? '0'),
      supervisorName: userMeta['supervisor_name']?.toString() ?? '',
      lessonsNumber:
          int.tryParse(userMeta['lessons_number']?.toString() ?? '0'),
      lessonDuration: userMeta['lesson_duration']?.toString() ?? '',
      paymentStatus: userMeta['payment_status']?.toString(),
      amount: double.tryParse(userMeta['amount']?.toString() ?? '0'),
      currency: userMeta['currency']?.toString(),
      notes: userMeta['notes']?.toString() ?? '',
      mId: userMeta['m_id']?.toString() ?? '',
      lessonsName: userMeta['lessons_name']?.toString() ?? '',
    );
  }

  /// Parse from v2 API response (single call with flat structure)
  factory Student.fromApiV2(Map<String, dynamic> json) {
    // API returns display_name as the primary name field
    String studentName = json['display_name']?.toString() ??
        json['name']?.toString() ??
        json['student_name']?.toString() ??
        '';

    return Student(
      id: json['id'] ?? 0,
      name: studentName,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      teacherId: int.tryParse(json['teacher_id']?.toString() ?? '0'),
      teacherName: json['teacher_name']?.toString(),
      supervisorId: int.tryParse(json['supervisor_id']?.toString() ?? '0'),
      supervisorName: json['supervisor_name']?.toString(),
      lessonsNumber: int.tryParse(json['lessons_number']?.toString() ?? '0'),
      lessonDuration: json['lesson_duration']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0'),
      currency: json['currency']?.toString(),
      notes: json['notes']?.toString(),
      mId: json['m_id']?.toString(),
      lessonsName: json['lessons_name']?.toString(),
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    int? teacherId,
    String? teacherName,
    int? supervisorId,
    String? supervisorName,
    int? lessonsNumber,
    String? lessonDuration,
    String? paymentStatus,
    double? amount,
    String? currency,
    String? notes,
    String? mId,
    String? lessonsName,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      lessonsNumber: lessonsNumber ?? this.lessonsNumber,
      lessonDuration: lessonDuration ?? this.lessonDuration,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      mId: mId ?? this.mId,
      lessonsName: lessonsName ?? this.lessonsName,
    );
  }

  String toDebugString() {
    return 'Student{id: $id, name: $name, phone: $phone, teacherId: $teacherId, '
        'teacherName: $teacherName, lessonsNumber: $lessonsNumber, '
        'lessonDuration: $lessonDuration, paymentStatus: $paymentStatus, '
        'amount: $amount, currency: $currency, mId: $mId}';
  }

  /// Convert to JSON for serialization/caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'lessons_number': lessonsNumber,
      'lesson_duration': lessonDuration,
      'payment_status': paymentStatus,
      'amount': amount,
      'currency': currency,
      'notes': notes,
      'm_id': mId,
      'lessons_name': lessonsName,
    };
  }
}
