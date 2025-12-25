class FreeSlot {
  final int id;
  final int userId;
  final int dayOfWeek; // 0=Sunday .. 6=Saturday
  final String startTime; // e.g. "10:45:00"
  final String endTime;

  FreeSlot({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory FreeSlot.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int
    int parseIntSafe(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    // API returns teacher_id, not user_id
    final userId = json['user_id'] ?? json['teacher_id'];

    return FreeSlot(
      id: parseIntSafe(json['id'], 0),
      userId: parseIntSafe(userId, 0),
      dayOfWeek: parseIntSafe(json['day_of_week'], 0),
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
    );
  }
}
