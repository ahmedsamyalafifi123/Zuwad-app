import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/domain/models/teacher.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/pages/login_page.dart';
import '../../../../features/chat/presentation/pages/chat_list_page.dart';
import '../../../../core/utils/gender_helper.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../../../../features/notifications/presentation/pages/notifications_page.dart';
import '../../../../features/notifications/data/repositories/notification_repository.dart';
import '../../../../core/services/notification_service.dart';

class TeacherDashboardPage extends StatelessWidget {
  final Teacher? teacher;

  const TeacherDashboardPage({super.key, this.teacher});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(
            fontFamily: 'Qatar',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          style: TextStyle(fontFamily: 'Qatar'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Qatar',
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(LogoutEvent());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF820c22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontFamily: 'Qatar',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    final teacherName = teacher?.name ?? '';
    final teacherMId = teacher?.mId ?? '';
    final profileImage = teacher?.profileImage;
    final isFemale = GenderHelper.isFemale(teacher?.gender);
    final fallbackAvatar =
        isFemale ? 'assets/images/woman.png' : 'assets/images/man.png';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 234, 234, 234),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(85, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center: title
                  const Text(
                    'المراسلة',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Left: avatar with popup menu
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TeacherNotificationButton(),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          offset: const Offset(0, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'logout') {
                              _showLogoutDialog(context);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: const [
                                  Text(
                                    'تسجيل الخروج',
                                    style: TextStyle(
                                      fontFamily: 'Qatar',
                                      color: Color(0xFF820c22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFF820c22),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26D4AF37),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: profileImage != null &&
                                      profileImage.isNotEmpty
                                  ? Image.network(
                                      profileImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        fallbackAvatar,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      fallbackAvatar,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: page icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.black.withValues(alpha: 0.30),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ChatListPage(
        studentId: teacherMId,
        studentName: teacherName,
        teacherId: '',
        teacherName: '',
        supervisorId: '',
        supervisorName: '',
      ),
    );
  }
}

class _TeacherNotificationButton extends StatefulWidget {
  @override
  State<_TeacherNotificationButton> createState() =>
      _TeacherNotificationButtonState();
}

class _TeacherNotificationButtonState
    extends State<_TeacherNotificationButton> {
  final NotificationRepository _repository = NotificationRepository();
  int _notificationCount = 0;

  StreamSubscription? _subscription;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscription = _notificationService.onNotificationReceived.listen((_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount(isTeacher: true);
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsPage(isTeacher: true),
          ),
        );
        _loadUnreadCount();
      },
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Lottie.asset(
              'assets/images/Bell.json',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              animate: _notificationCount > 0,
            ),
            if (_notificationCount > 0)
              Positioned(
                top: 0,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF820c22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    _notificationCount > 99 ? '99+' : '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Qatar',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
