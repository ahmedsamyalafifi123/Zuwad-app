import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/user_message.dart';

class UserMessageRepository {
  final WordPressApi _api = WordPressApi();

  Future<List<UserMessage>> getUserMessages({
    int page = 1,
    int perPage = 20,
    String status = 'all',
  }) async {
    final response = await _api.getUserMessages(
      page: page,
      perPage: perPage,
      status: status,
    );

    final data = response['data'];
    if (data is! List) return [];

    final messages = data
        .whereType<Map>()
        .map((json) => UserMessage.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    messages.sort((a, b) {
      if (a.isHighPriority != b.isHighPriority) {
        return a.isHighPriority ? -1 : 1;
      }

      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return messages;
  }

  Future<UserMessage?> getMessageDetails(int messageId) async {
    final data = await _api.getUserMessageDetails(messageId);
    if (data == null) return null;
    return UserMessage.fromJson(data);
  }

  Future<bool> markAsRead(int messageId) async {
    return _api.markUserMessageAsRead(messageId);
  }

  Future<int> getUnreadCount() async {
    return _api.getUserMessagesUnreadCount();
  }
}
