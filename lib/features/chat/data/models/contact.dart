/// Model representing a chat contact from the API.
///
/// Contacts are users that the current user can chat with,
/// based on their role relationships (student-teacher, teacher-supervisor, etc.)
class Contact {
  final int id;
  final String name;
  final String role;
  final String relation;
  final String? profileImage;

  const Contact({
    required this.id,
    required this.name,
    required this.role,
    required this.relation,
    this.profileImage,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      relation: json['relation'] ?? '',
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'relation': relation,
      'profile_image': profileImage,
    };
  }

  @override
  String toString() => 'Contact(id: $id, name: $name, role: $role)';
}
