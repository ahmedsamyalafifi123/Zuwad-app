class Student {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final int? teacherId;
  final String? teacherName;
  final String? teacherGender;
  final int? supervisorId;
  final String? supervisorName;
  final String? teacherImage;
  final int? lessonsNumber;
  final int? remainingLessons;
  final String? lessonDuration;
  final String? paymentStatus;
  final double? amount;
  final String? currency;
  final String? notes;
  final String? mId;
  final String? lessonsName;
  final String? birthday;
  final String? country;
  final String? profileImageUrl;

  Student({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.teacherId,
    this.teacherName,
    this.teacherGender,
    this.supervisorId,
    this.supervisorName,
    this.teacherImage,
    this.lessonsNumber,
    this.remainingLessons,
    this.lessonDuration,
    this.paymentStatus,
    this.amount,
    this.currency,
    this.notes,
    this.mId,
    this.lessonsName,
    this.birthday,
    this.country,
    this.profileImageUrl,
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
      teacherGender: userMeta['teacher_gender']?.toString(),
      supervisorId: int.tryParse(userMeta['supervisor_id']?.toString() ?? '0'),
      supervisorName: userMeta['supervisor_name']?.toString() ?? '',
      teacherImage: userMeta['teacher_profile_image']
          ?.toString(), // Use teacher_profile_image from API
      lessonsNumber:
          int.tryParse(userMeta['lessons_number']?.toString() ?? '0'),
      remainingLessons:
          int.tryParse(userMeta['remaining_lessons']?.toString() ?? '0'),
      lessonDuration: userMeta['lesson_duration']?.toString() ?? '',
      paymentStatus: userMeta['payment_status']?.toString(),
      amount: double.tryParse(userMeta['amount']?.toString() ?? '0'),
      currency: userMeta['currency']?.toString(),
      notes: userMeta['notes']?.toString() ?? '',
      mId: userMeta['m_id']?.toString() ?? '',
      lessonsName: userMeta['lessons_name']?.toString() ?? '',
      birthday: userMeta['dob']?.toString(),
      country: userMeta['country']?.toString(),
      profileImageUrl: userMeta['profile_image_url']?.toString(),
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
      teacherGender: json['teacher_gender']?.toString(),
      supervisorId: int.tryParse(json['supervisor_id']?.toString() ?? '0'),
      supervisorName: json['supervisor_name']?.toString(),
      teacherImage: json['teacher_profile_image']
          ?.toString(), // Use teacher_profile_image from API
      lessonsNumber: int.tryParse(json['lessons_number']?.toString() ?? '0'),
      remainingLessons:
          int.tryParse(json['remaining_lessons']?.toString() ?? '0'),
      lessonDuration: json['lesson_duration']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0'),
      currency: json['currency']?.toString(),
      notes: json['notes']?.toString(),
      mId: json['m_id']?.toString(),
      lessonsName: json['lessons_name']?.toString(),
      birthday: json['dob']?.toString(),
      country: json['country']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    int? teacherId,
    String? teacherName,
    String? teacherGender,
    int? supervisorId,
    String? supervisorName,
    String? teacherImage,
    int? lessonsNumber,
    int? remainingLessons,
    String? lessonDuration,
    String? paymentStatus,
    double? amount,
    String? currency,
    String? notes,
    String? mId,
    String? lessonsName,
    String? birthday,
    String? country,
    String? profileImageUrl,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherGender: teacherGender ?? this.teacherGender,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      teacherImage: teacherImage ?? this.teacherImage,
      lessonsNumber: lessonsNumber ?? this.lessonsNumber,
      remainingLessons: remainingLessons ?? this.remainingLessons,
      lessonDuration: lessonDuration ?? this.lessonDuration,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      mId: mId ?? this.mId,
      lessonsName: lessonsName ?? this.lessonsName,
      birthday: birthday ?? this.birthday,
      country: country ?? this.country,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  static String getDisplayLessonName(String? lessonsName) {
    if (lessonsName == null || lessonsName.isEmpty) return 'المسار العام';
    switch (lessonsName.trim()) {
      case 'قرآن':
        return 'القرآن الكريم';
      case 'لغة عربية':
        return 'اللغة العربية';
      case 'تجويد':
        return 'التجويد';
      case 'تربية اسلامية':
        return 'التربية الاسلامية';
      default:
        return lessonsName;
    }
  }

  String get displayLessonName => getDisplayLessonName(lessonsName);

  String toDebugString() {
    return 'Student{id: $id, name: $name, phone: $phone, teacherId: $teacherId, '
        'teacherName: $teacherName, teacherGender: $teacherGender, lessonsNumber: $lessonsNumber, '
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
      'teacher_gender': teacherGender,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'teacher_profile_image': teacherImage,
      'lessons_number': lessonsNumber,
      'remaining_lessons': remainingLessons,
      'lesson_duration': lessonDuration,
      'payment_status': paymentStatus,
      'amount': amount,
      'currency': currency,
      'notes': notes,
      'm_id': mId,
      'lessons_name': lessonsName,
      'birthday': birthday,
      'country': country,
      'profile_image_url': profileImageUrl,
    };
  }
}
