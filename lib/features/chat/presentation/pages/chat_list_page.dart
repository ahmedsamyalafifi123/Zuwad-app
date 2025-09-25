import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final String supervisorId;
  final String supervisorName;

  const ChatListPage({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.supervisorId,
    required this.supervisorName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المحادثات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              _buildChatTile(
                context,
                icon: Icons.school,
                title: 'المعلم',
                subtitle: teacherName,
                onTap: () => _openChat(
                  context,
                  recipientId: teacherId,
                  recipientName: teacherName,
                ),
              ),
              const SizedBox(height: 16),
              _buildChatTile(
                context,
                icon: Icons.support_agent,
                title: 'المشرف',
                subtitle: supervisorName,
                onTap: () => _openChat(
                  context,
                  recipientId: supervisorId,
                  recipientName: supervisorName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(
    BuildContext context, {
    required String recipientId,
    required String recipientName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          recipientId: recipientId,
          recipientName: recipientName,
          studentId: studentId,
          studentName: studentName,
        ),
      ),
    );
  }
}
