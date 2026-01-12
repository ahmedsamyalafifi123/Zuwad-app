import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/contact.dart';
import '../../data/models/conversation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'package:zuwad/features/auth/presentation/bloc/auth_state.dart';
import 'package:zuwad/core/utils/gender_helper.dart';
import 'chat_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Chat list page showing available contacts and recent conversations.
///
/// Fetches contacts dynamically from the API based on user role relationships:
/// - Students can chat with their teacher and supervisor
/// - Teachers can chat with their students and supervisor
/// - Supervisors can chat with their teachers and students
class ChatListPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  // These are kept for backward compatibility but will be overridden by API data
  final String teacherId;
  final String teacherName;
  final String supervisorId;
  final String supervisorName;

  const ChatListPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatRepository _chatRepository = ChatRepository();

  List<Contact> _contacts = [];
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Set up periodic refresh every 30 seconds for unread counts
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadConversations(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load contacts and conversations in parallel
      final results = await Future.wait([
        _chatRepository.getContacts(),
        _chatRepository.getConversations(),
      ]);

      if (mounted) {
        setState(() {
          _contacts = results[0] as List<Contact>;
          _conversations = results[1] as List<Conversation>;
          _isLoading = false;
        });

        if (kDebugMode) {
          print(
              'Loaded ${_contacts.length} contacts and ${_conversations.length} conversations');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'فشل في تحميل جهات الاتصال';
        });
        if (kDebugMode) {
          print('Error loading chat data: $e');
        }
      }
    }
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final conversations = await _chatRepository.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          if (showLoading) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getUnreadCountForContact(int contactId) {
    // Find conversation with this contact and return unread count
    final conversation =
        _conversations.where((c) => c.otherUser.id == contactId).firstOrNull;
    return conversation?.unreadCount ?? 0;
  }

  String? _getLastMessageForContact(int contactId) {
    final conversation =
        _conversations.where((c) => c.otherUser.id == contactId).firstOrNull;
    return conversation?.lastMessage;
  }

  String _getLastMessageTimeForContact(int contactId) {
    final conversation =
        _conversations.where((c) => c.otherUser.id == contactId).firstOrNull;

    if (conversation?.lastMessageAt == null) return '';

    final now = DateTime.now();
    final msgTime = conversation!.lastMessageAt!;
    final diff = now.difference(msgTime);

    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inHours < 1) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inDays < 1) {
      return 'منذ ${diff.inHours} س';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} ي';
    } else {
      return '${msgTime.day}/${msgTime.month}';
    }
  }

  Widget _buildFallbackAvatar(String role, String gender) {
    if (role.toLowerCase() == 'teacher') {
      return ClipOval(
        child: Image.asset(
          GenderHelper.getTeacherImage(gender),
          fit: BoxFit.cover,
        ),
      );
    }

    // For other roles, use icons
    IconData icon;
    switch (role.toLowerCase()) {
      case 'supervisor':
        icon = Icons.support_agent_rounded;
        break;
      case 'student':
        icon = Icons.person_rounded;
        break;
      default:
        icon = Icons.chat_bubble_rounded;
    }

    return Icon(
      icon,
      color: AppTheme.primaryColor,
      size: 28,
    );
  }

  String _getRoleName(String role, String relation, {String? gender}) {
    // Use relation first as it's more specific
    switch (relation.toLowerCase()) {
      case 'teacher':
        return (gender == 'أنثى') ? 'المعلمة' : 'المعلم';
      case 'supervisor':
        return 'المشرف';
      case 'student':
        return 'الطالب';
    }

    // Fallback to role
    switch (role.toLowerCase()) {
      case 'teacher':
        return (gender == 'أنثى') ? 'المعلمة' : 'المعلم';
      case 'supervisor':
        return 'المشرف';
      case 'student':
        return 'الطالب';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF8b0628),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_contacts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16.0, MediaQuery.of(context).padding.top + 20.0, 16.0, 16.0),
      children: [
        ..._contacts.map((contact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildContactTile(contact),
            )),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات متاحة',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم عرض جهات الاتصال هنا',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    final unreadCount = _getUnreadCountForContact(contact.id);
    final lastMessage = _getLastMessageForContact(contact.id);
    final lastMessageTime = _getLastMessageTimeForContact(contact.id);

    // Get gender if contact is teacher
    String gender = 'ذكر';
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        // Only use student's teacherGender if this contact is THE teacher
        // We assume 'teacher' relation implies it's the student's teacher
        if (contact.relation.toLowerCase() == 'teacher' ||
            contact.role.toLowerCase() == 'teacher') {
          gender = authState.student!.teacherGender ?? 'ذكر';
        }
      }
    } catch (_) {}

    final roleName =
        _getRoleName(contact.role, contact.relation, gender: gender);

    // Override display name for supervisor
    String displayName = contact.name;
    if (contact.role.toLowerCase() == 'supervisor' ||
        contact.relation.toLowerCase() == 'supervisor') {
      displayName = 'خدمة العملاء';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15), // ~0.06 opacity
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(contact, displayNameOverride: displayName),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primaryColor.withAlpha(25), // ~0.1 opacity
                        shape: BoxShape.circle,
                      ),
                      child: contact.profileImage != null
                          ? ClipOval(
                              child: Image.network(
                                contact.profileImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackAvatar(
                                  contact.role,
                                  gender,
                                ),
                              ),
                            )
                          : _buildFallbackAvatar(
                              contact.role,
                              gender,
                            ),
                    ),
                    // Unread badge
                    if (unreadCount > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf6c302),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Contact info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageTime.isNotEmpty)
                            Text(
                              lastMessageTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: unreadCount > 0
                                    ? AppTheme.primaryColor
                                    : Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withAlpha(20), // ~0.08 opacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (lastMessage != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(Contact contact, {String? displayNameOverride}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          recipientId: contact.id.toString(),
          recipientName: displayNameOverride ?? contact.name,
          studentId: widget.studentId,
          studentName: widget.studentName,
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      if (mounted) {
        _loadConversations(showLoading: false);
      }
    });
  }
}
