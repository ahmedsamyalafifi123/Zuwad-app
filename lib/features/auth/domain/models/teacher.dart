class TeacherStudent {
  final int id;
  final String mId;
  final String name;
  final String? gender;
  final String? lessonsName;
  final String? profileImage;
  final String? paymentStatus;

  const TeacherStudent({
    required this.id,
    required this.mId,
    required this.name,
    this.gender,
    this.lessonsName,
    this.profileImage,
    this.paymentStatus,
  });

  factory TeacherStudent.fromJson(Map<String, dynamic> json) {
    return TeacherStudent(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mId: json['m_id']?.toString() ?? '',
      name: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
      gender: json['gender']?.toString(),
      lessonsName: json['lessons_name']?.toString(),
      profileImage: json['profile_image_url']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
    );
  }
}

class Teacher {
  final int id;
  final String mId;
  final String name;
  final String? gender;
  final String? profileImage;
  final String? phone;
  final List<TeacherStudent> students;

  const Teacher({
    required this.id,
    required this.mId,
    required this.name,
    this.gender,
    this.profileImage,
    this.phone,
    this.students = const [],
  });

  factory Teacher.fromApiResponse(Map<String, dynamic> json) {
    final studentsJson = json['students'] as List<dynamic>? ?? [];
    return Teacher(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mId: json['m_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['display_name']?.toString() ?? '',
      gender: json['gender']?.toString(),
      profileImage: json['profile_image_url']?.toString(),
      phone: json['phone']?.toString(),
      students: studentsJson
          .map((s) => TeacherStudent.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
