import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../../auth/domain/models/teacher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../../core/utils/gender_helper.dart';
import '../../../../core/services/notification_service.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import 'teacher_home_page.dart';
import 'teacher_schedules_page.dart';
import 'teacher_reports_history_page.dart';
import 'dart:async';

class TeacherDashboardPage extends StatefulWidget {
  final Teacher? teacher;

  const TeacherDashboardPage({super.key, this.teacher});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _currentIndex = 0;

  final NotificationRepository _notificationRepo = NotificationRepository();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _notificationSubscription;
  int _notificationCount = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      TeacherHomePage(teacher: widget.teacher!),
      TeacherSchedulesPage(teacher: widget.teacher!),
      _TeacherMessagesAndReportsPage(teacher: widget.teacher!),
    ];

    _loadNotificationCount();
    _notificationSubscription =
        _notificationService.onNotificationReceived.listen((_) {
      _loadNotificationCount();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await _notificationRepo.getUnreadCount(isTeacher: true);
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

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

    final teacherName = widget.teacher?.name ?? '';
    final teacherMId = widget.teacher?.mId ?? '';
    final profileImage = widget.teacher?.profileImage;
    final isFemale = GenderHelper.isFemale(widget.teacher?.gender);
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
                  Text(
                    _getTitleForIndex(_currentIndex),
                    style: const TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Left: notification + avatar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsPage(isTeacher: true),
                              ),
                            );
                            _loadNotificationCount();
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
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      child: Text(
                                        _notificationCount > 99
                                            ? '99+'
                                            : '$_notificationCount',
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
                        ),
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
                      _getIconForIndex(_currentIndex),
                      color: Colors.black.withOpacity(0.30),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _pages[_currentIndex],
      extendBody: true,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _TeacherBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'الرئيسة';
      case 1:
        return 'الجداول';
      case 2:
        return 'المراسلة';
      default:
        return '';
    }
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.home_rounded;
      case 1:
        return Icons.calendar_month_rounded;
      case 2:
        return Icons.chat_bubble_rounded;
      default:
        return Icons.home_rounded;
    }
  }
}

class _TeacherBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _TeacherBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255),
                      Color.fromARGB(255, 234, 234, 234),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, 'الرئيسة'),
                            _buildNavItem(
                                1, Icons.calendar_month_rounded, 'الجداول'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 70),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(
                                2, Icons.chat_bubble_rounded, 'المراسلة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -15,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/zuwad.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSelected ? 22 : 20,
              color: isSelected
                  ? const Color.fromARGB(255, 224, 173, 5)
                  : const Color(0xFF8B0628),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color.fromARGB(255, 0, 0, 0)
                    : const Color(0xFF8B0628),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherMessagesAndReportsPage extends StatefulWidget {
  final Teacher teacher;

  const _TeacherMessagesAndReportsPage({required this.teacher});

  @override
  State<_TeacherMessagesAndReportsPage> createState() =>
      _TeacherMessagesAndReportsPageState();
}

class _TeacherMessagesAndReportsPageState
    extends State<_TeacherMessagesAndReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF820c22),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontFamily: 'Qatar',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'المراسلة'),
              Tab(text: 'التقارير'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChatListPage(
                studentId: widget.teacher.mId,
                studentName: widget.teacher.name,
                teacherId: '',
                teacherName: '',
                supervisorId: '',
                supervisorName: '',
              ),
              TeacherReportsHistoryPage(teacher: widget.teacher),
            ],
          ),
        ),
      ],
    );
  }
}
