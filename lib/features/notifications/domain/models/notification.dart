/// Model representing a push notification.
class AppNotification {
  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: json['type'] ?? 'general',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: _parseDate(json['created_at']),
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      String dateStr = date.toString();
      // Remove trailing Z if present and re-add to ensure standard format if needed,
      // or just trust DateTime.parse to handle ISO8601 correctly.
      // The error "2026-01-08T14:16:58ZZ" suggests the API returns "2026-01-08T14:16:58Z"
      // and we were appending another Z.

      // If existing code was appending 'Z', and the API returns 'Z', we get 'ZZ'.
      // Fix: Don't append 'Z' blindly.
      if (dateStr.endsWith('Z')) {
        return DateTime.parse(dateStr).toLocal();
      }
      return DateTime.parse('${dateStr}Z').toLocal();
    } catch (e) {
      // Fallback for simple date format "YYYY-MM-DD HH:MM:SS"
      try {
        return DateTime.parse(date.toString()).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'data': data,
    };
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }
}
