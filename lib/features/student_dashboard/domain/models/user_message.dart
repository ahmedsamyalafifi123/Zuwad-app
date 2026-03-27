class UserMessage {
  final int id;
  final String title;
  final String message;
  final String priority;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? expiryDate;

  const UserMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.isRead,
    this.createdAt,
    this.readAt,
    this.expiryDate,
  });

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      try {
        final normalized = text.replaceFirst(' ', 'T');
        final hasTimezoneSuffix = normalized.endsWith('Z') ||
            RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(normalized);
        return DateTime.parse(
          hasTimezoneSuffix ? normalized : '${normalized}Z',
        );
      } catch (_) {
        return null;
      }
    }

    bool parseBool(dynamic value) {
      return value == true || value == 1 || value == '1';
    }

    return UserMessage(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'normal',
      isRead: parseBool(json['is_read']),
      createdAt: parseDate(json['created_at']),
      readAt: parseDate(json['read_at']),
      expiryDate: parseDate(json['expiry_date']),
    );
  }

  bool get isHighPriority => priority.toLowerCase() == 'high';
}
