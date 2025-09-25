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
    return FreeSlot(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      dayOfWeek: json['day_of_week'] is int ? json['day_of_week'] : int.parse(json['day_of_week'].toString()),
      startTime: json['start_time'].toString(),
      endTime: json['end_time'].toString(),
    );
  }
}
