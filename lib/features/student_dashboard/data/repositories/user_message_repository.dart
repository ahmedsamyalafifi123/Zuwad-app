import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/user_message.dart';

class UserMessageRepository {
  final WordPressApi _api = WordPressApi();

  /// Returns messages and the unread count in a single API call.
  /// The unread count is extracted from `meta.unread_count` in the response.
  Future<({List<UserMessage> messages, int unreadCount})> getUserMessagesWithCount({
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
    final messages = <UserMessage>[];

    if (data is List) {
      messages.addAll(
        data
            .whereType<Map>()
            .map((json) => UserMessage.fromJson(Map<String, dynamic>.from(json))),
      );

      messages.sort((a, b) {
        if (a.isHighPriority != b.isHighPriority) {
          return a.isHighPriority ? -1 : 1;
        }
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }

    int unreadCount = 0;
    final meta = response['meta'];
    if (meta is Map) {
      final raw = meta['unread_count'];
      unreadCount = raw is int ? raw : int.tryParse('$raw') ?? 0;
    }

    return (messages: messages, unreadCount: unreadCount);
  }

  Future<UserMessage?> getMessageDetails(int messageId) async {
    final data = await _api.getUserMessageDetails(messageId);
    if (data == null) return null;
    return UserMessage.fromJson(data);
  }

  Future<bool> markAsRead(int messageId) async {
    return _api.markUserMessageAsRead(messageId);
  }
}
