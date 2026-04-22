import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

import '../../../../core/api/wordpress_api.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../services/livekit_service.dart';
import '../../../../core/services/chat_event_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/student.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../meeting/presentation/pages/meeting_page.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/user_message_repository.dart';
import '../../domain/models/schedule.dart';
import '../../domain/models/student_report.dart';
import '../../domain/models/student_event.dart';
import '../../domain/models/user_message.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import 'postpone_page.dart';
import 'alarm_settings_page.dart';
import 'report_details_page.dart';
import '../widgets/wordwall_game_widget.dart';

import 'home_page.dart';
import 'settings_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../widgets/islamic_bottom_nav_bar.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/gender_helper.dart';
import '../../../../core/utils/timezone_helper.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/timezone_utils.dart';
import '../../../../core/utils/version_check_helper.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _currentIndex = 0; // Start with الرئيسة (home/dashboard)

  // Instance-level GlobalKeys — must NOT be static to avoid "Multiple widgets
  // used the same GlobalKey" when the widget is rebuilt or re-inserted.
  final GlobalKey studentMenuKey = GlobalKey();
  final GlobalKey joinLessonKey = GlobalKey();
  final GlobalKey rescheduleKey = GlobalKey();
  final GlobalKey prevAchievementKey = GlobalKey();
  final GlobalKey scheduleNavKey = GlobalKey();
  final GlobalKey alarmSettingsKey = GlobalKey();

  late final List<Widget> _pages;

  // Chat unread count tracking
  final ChatRepository _chatRepository = ChatRepository();
  final ChatEventService _chatEventService = ChatEventService();
  StreamSubscription<ChatEvent>? _chatEventSubscription;
  int _chatUnreadCount = 0;

  // Navigation items configuration for cleaner code
  // Navigation items handled by IslamicBottomNavBar

  @override
  void initState() {
    super.initState();
    // Initialize pages - 4 pages for the 4 nav items
    _pages = [
      // 0: الرئيسة (Dashboard/Main page)
      _DashboardContent(
        studentMenuKey: studentMenuKey,
        joinLessonKey: joinLessonKey,
        rescheduleKey: rescheduleKey,
        prevAchievementKey: prevAchievementKey,
        alarmSettingsKey: alarmSettingsKey,
      ),
      // 1: جدول الحصص (Schedule)
      const HomePage(),
      // 2: المراسلة (Messages)
      BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated && state.student != null) {
            return ChatListPage(
              key: ValueKey('chat_list_${state.student!.id}'),
              studentId: state.student!.id.toString(),
              studentName: state.student!.name,
              teacherId: state.student!.teacherId?.toString() ?? '',
              teacherName: state.student!.teacherName ?? 'المعلم',
              supervisorId: state.student!.supervisorId?.toString() ?? '',
              supervisorName: state.student!.supervisorName ?? 'خدمة العملاء',
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      // 3: الاعدادات (Settings)
      const SettingsPage(),
    ];

    // Fetch student profile data when dashboard loads
    context.read<AuthBloc>().add(GetStudentProfileEvent());

    // Load initial chat unread count
    _loadChatUnreadCount();

    // Subscribe to chat events for real-time updates
    _chatEventSubscription = _chatEventService.onChatUpdate.listen((event) {
      if (mounted) {
        _loadChatUnreadCount();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
      VersionCheckHelper.checkVersion(context);
    });
  }

  @override
  void dispose() {
    _chatEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChatUnreadCount() async {
    try {
      final count = await _chatRepository.getUnreadCount();
      if (mounted) {
        setState(() {
          _chatUnreadCount = count;
        });
      }
    } catch (e) {
      // Silently fail - chat count is not critical
      if (kDebugMode) {
        print('Error loading chat unread count: $e');
      }
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_dashboard_tutorial') ?? false;
    if (!seen) {
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _showTutorial();
        });
      }
    }
  }

  void _showTutorial() {
    // Guard: ensure all target keys have mounted widgets before showing.
    // If any key has no context the tutorial will crash with
    // "It was not possible to obtain target position".
    final keysReady = [
      studentMenuKey,
      joinLessonKey,
      rescheduleKey,
      prevAchievementKey,
      scheduleNavKey,
      alarmSettingsKey,
    ].every((k) => k.currentContext != null);

    if (!keysReady || !mounted) return;

    TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "تخطي",
      textStyleSkip: const TextStyle(
        fontFamily: 'Qatar',
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _markTutorialSeen();
      },
      onClickTarget: (target) {
        if (target.identify == "schedule_nav") {
          setState(() => _currentIndex = 1);
          _markTutorialSeen();
        }
      },
      onSkip: () {
        _markTutorialSeen(skipAll: true);
        return true;
      },
      onClickOverlay: (target) {},
    )..show(context: context);
  }

  Future<void> _markTutorialSeen({bool skipAll = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_dashboard_tutorial', true);
    if (skipAll) {
      await prefs.setBool('seen_schedule_tutorial', true);
    }
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 1. Student Menu
    targets.add(
      TargetFocus(
        identify: "student_menu",
        keyTarget: studentMenuKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "تغيير الطالب",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "اضغط هنا لتبديل حساب الطالب والوصول للقائمة.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => controller.next(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("التالي",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    );

    // 2. Alarm Settings (New Step)
    targets.add(
      TargetFocus(
        identify: "alarm_settings",
        keyTarget: alarmSettingsKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "إعدادات المنبه",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "اضغط هنا لضبط تنبيهات الدروس.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Back Button (Previous) - Flex 1
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => controller.previous(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("السابق",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Next Button - Flex 2
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => controller.next(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("التالي",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // 3. Join Lesson
    targets.add(
      TargetFocus(
        identify: "join_lesson",
        keyTarget: joinLessonKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "إنضم للدرس",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "سيظهر هذا الزر باللون الأخضر قبل موعد الدرس بـ 15 دقيقة.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Back Button (Previous) - Flex 1
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => controller.previous(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("السابق",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Next Button - Flex 2
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => controller.next(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("التالي",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // 3. Reschedule
    targets.add(
      TargetFocus(
        identify: "reschedule",
        keyTarget: rescheduleKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "إعادة جدولة",
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "يمكنك تغيير موعد الدرس حتى قبل الموعد بساعة واحدة.",
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Back Button (Previous) - Flex 1
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => controller.previous(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("السابق",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Finish Button - Flex 2 - Closes the tutorial without navigating
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            _markTutorialSeen();
                            controller.skip();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF820c22),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("إنهاء",
                              style: TextStyle(
                                  fontFamily: 'Qatar',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // 4. Previous Achievement
    return targets;
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to white with dark icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50), // Adjusted height
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ), // Warm cream white (Matching Nav Bar)
                Color.fromARGB(
                  255,
                  234,
                  234,
                  234,
                ), // Subtle gold tint (Matching Nav Bar)
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
                  // Center: Title
                  Text(
                    IslamicBottomNavBar.navItems[_currentIndex]['label']
                        as String,
                    style: const TextStyle(
                      // Title Style
                      fontFamily: 'Qatar',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Left: Notification Icon + Student Avatar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Notification Icon with real unread count
                        _NotificationButton(),
                        const SizedBox(width: 12),
                        // Student Avatar with dropdown menu
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            String? imageUrl;
                            if (state is AuthAuthenticated &&
                                state.student != null) {
                              imageUrl = state.student!.profileImageUrl;
                            }
                            return PopupMenuButton<String>(
                              offset: const Offset(0, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // key: studentMenuKey, // Moved to arrow in dashboard content
                              onSelected: (value) {
                                if (value == 'logout') {
                                  // Show confirmation dialog
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
                                      actionsAlignment:
                                          MainAxisAlignment.center,
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
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
                                            context.read<AuthBloc>().add(
                                                  LogoutEvent(),
                                                );
                                            Navigator.of(
                                              context,
                                            ).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginPage(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF820c22,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                // Avatar Container
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
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                            'assets/images/male_avatar.webp',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/male_avatar.webp',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Right: Page Icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      // Page Icon
                      IslamicBottomNavBar.navItems[_currentIndex]['icon']
                          as IconData,
                      color: Colors.black.withOpacity(
                        0.30,
                      ), // Black 30% opacity
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      extendBody: true,
      extendBodyBehindAppBar: true, // Allow body to show behind rounded corners
      bottomNavigationBar: IslamicBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        chatUnreadCount: _chatUnreadCount,
        itemKeys: {1: scheduleNavKey}, // Schedule is index 1
      ),
    );
  }
}

/// Notification button widget that shows unread count and navigates to NotificationsPage.
class _NotificationButton extends StatefulWidget {
  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
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
      final count = await _repository.getUnreadCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently fail - notification count is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Get current student ID
        int? studentId;
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated && authState.student != null) {
          studentId = authState.student!.id;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotificationsPage(studentId: studentId),
          ),
        );
        // Refresh count when returning from notifications page
        _loadUnreadCount();
      },
      child: Transform.translate(
        offset: const Offset(-10, -5),
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
                    color: const Color(0xFF820c22), // Burgundy
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

class _DashboardContent extends StatefulWidget {
  final GlobalKey studentMenuKey;
  final GlobalKey joinLessonKey;
  final GlobalKey rescheduleKey;
  final GlobalKey prevAchievementKey;
  final GlobalKey alarmSettingsKey;

  const _DashboardContent({
    required this.studentMenuKey,
    required this.joinLessonKey,
    required this.rescheduleKey,
    required this.prevAchievementKey,
    required this.alarmSettingsKey,
  });

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final EventRepository _eventRepository = EventRepository();
  final UserMessageRepository _userMessageRepository = UserMessageRepository();
  StudentSchedule? _nextSchedule;
  Schedule? _nextLesson;
  DateTime?
      _nextLessonDateTime; // Lesson time in student's local timezone (for display)
  DateTime? _nextLessonUtc; // Lesson time in UTC (for countdown & join logic)
  String _teacherName = '';
  String _teacherGender = 'ذكر';
  String? _teacherImage;
  String _lessonName = '';
  bool _isLoading = true;
  Duration? _timeUntilNextLesson;
  Timer? _countdownTimer;

  // Event-related variables
  StudentEvent? _nextEvent;
  DateTime?
      _eventLocalDateTime; // Event time in student's local timezone (for display)
  DateTime? _eventUtc; // Event time in UTC (for countdown logic)
  Timer? _eventCountdownTimer;
  Duration? _timeUntilEvent;
  UserMessage? _latestUserMessage;
  bool _isLoadingUserMessage = false;
  int _userMessagesUnreadCount = 0;

  final AuthRepository _authRepository = AuthRepository();
  StudentReport? _lastReport;
  List<Student> _familyMembers = [];
  bool _loadingFamily = false;
  // final GlobalKey _arrowKey = GlobalKey(); // Replaced by studentMenuKey

  @override
  void initState() {
    super.initState();
    // Stagger API calls to avoid rate limiting: load the primary lesson data
    // first, then secondary data, then family members.
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadNextLesson(forceRefresh: true);
    if (!mounted) return;
    await Future.wait([
      _loadNextEvent(),
      _loadLatestUserMessage(),
    ]);
    if (!mounted) return;
    await _loadFamilyMembers();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _eventCountdownTimer?.cancel();
    super.dispose();
  }

  /// Load the next upcoming event for the student
  Future<void> _loadNextEvent() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      try {
        final student = authState.student!;
        final nextEvent = await _eventRepository.getNextEvent(student.id);

        if (!mounted) return;

        if (nextEvent == null) {
          setState(() {
            _nextEvent = null;
            _eventLocalDateTime = null;
            _eventUtc = null;
            _timeUntilEvent = null;
          });
          return;
        }

        if (mounted) {
          // Parse event datetime (from API which is in Egypt time)
          final egyptDateTime = nextEvent.eventDateTime;
          if (egyptDateTime != null) {
            // Local time for display (student's country timezone)
            _eventLocalDateTime =
                await TimezoneHelper.egyptToLocalAsync(egyptDateTime);
            // UTC time for countdown & join logic (works correctly on all platforms)
            _eventUtc = TimezoneHelper.egyptToUtc(egyptDateTime);
          }

          setState(() {
            _nextEvent = nextEvent;
          });

          // Start countdown timer (always show countdown for future events)
          _startEventCountdown();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading next event: $e');
        }
      }
    }
  }

  Future<void> _loadLatestUserMessage() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.student == null) {
      if (!mounted) return;
      setState(() {
        _latestUserMessage = null;
        _userMessagesUnreadCount = 0;
        _isLoadingUserMessage = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingUserMessage = true;
      });
    }

    try {
      final result = await _userMessageRepository.getUserMessagesWithCount(
        page: 1,
        perPage: 10,
        status: 'all',
      );

      if (!mounted) return;
      final firstMessage = result.messages.isNotEmpty ? result.messages.first : null;
      setState(() {
        _latestUserMessage = firstMessage;
        _userMessagesUnreadCount = result.unreadCount;
        _isLoadingUserMessage = false;
      });

      // Auto-mark as read once the message is seen
      if (firstMessage != null && !firstMessage.isRead) {
        _userMessageRepository.markAsRead(firstMessage.id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user messages: $e');
      }
      if (!mounted) return;
      setState(() {
        _latestUserMessage = null;
        _userMessagesUnreadCount = 0;
        _isLoadingUserMessage = false;
      });
    }
  }

  String _stripHtmlTags(String input) {
    return input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _formatMessageDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final dayName = TimezoneUtils.getArabicDayName(local);
    final time = TimezoneUtils.formatTime(local);
    return '$dayName - $time';
  }

  Future<void> _openUserMessageDetails(UserMessage message) async {
    final details =
        await _userMessageRepository.getMessageDetails(message.id) ?? message;
    final plainMessage = _stripHtmlTags(details.message);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF8F6F1),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: details.isHighPriority
                      ? const Color(0xFF820C22).withValues(alpha: 0.1)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  details.isHighPriority ? Icons.priority_high : Icons.mail_outline,
                  color: details.isHighPriority
                      ? const Color(0xFF820C22)
                      : const Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  details.title,
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_formatMessageDate(details.createdAt).isNotEmpty) ...[
                  Text(
                    _formatMessageDate(details.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SelectableText(
                  plainMessage,
                  style: const TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                fontFamily: 'Qatar',
                fontWeight: FontWeight.bold,
                color: Color(0xFF820C22),
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() {
      _latestUserMessage = details;
      _userMessagesUnreadCount = (_userMessagesUnreadCount - 1).clamp(0, 9999);
    });
    _loadLatestUserMessage();
  }

  /// Start countdown timer for event
  void _startEventCountdown() {
    _eventCountdownTimer?.cancel();

    if (_eventUtc == null) return;

    // Initialize immediately so countdown shows right away
    final now = DateTime.now().toUtc();
    if (_eventUtc!.isAfter(now)) {
      _timeUntilEvent = _eventUtc!.difference(now);
    } else {
      _timeUntilEvent = Duration.zero;
    }

    _eventCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _eventCountdownTimer?.cancel();
        return;
      }

      final now = DateTime.now().toUtc();
      if (_eventUtc!.isAfter(now)) {
        setState(() {
          _timeUntilEvent = _eventUtc!.difference(now);
        });
      } else {
        // Event has started — hide 10 minutes after event ends (start + duration + 10)
        final eventDuration = _nextEvent?.duration ?? 60;
        final hiddenAt = _eventUtc!.add(Duration(minutes: eventDuration + 10));
        if (now.isAfter(hiddenAt)) {
          _eventCountdownTimer?.cancel();
          setState(() {
            _nextEvent = null;
            _timeUntilEvent = null;
          });
        } else {
          setState(() {
            _timeUntilEvent = Duration.zero;
          });
        }
      }
    });
  }

  /// Navigate to meeting page for the event.
  /// Fetches a server-side LiveKit token so it matches the web system exactly.
  Future<void> _joinEvent() async {
    if (_nextEvent == null) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.student == null) return;

    final student = authState.student!;
    final event = _nextEvent!;

    // Capture navigator before async gap so dialog can be dismissed even if widget unmounts
    final navigator = Navigator.of(context);
    bool dialogDismissed = false;

    void dismissDialog() {
      if (!dialogDismissed) {
        dialogDismissed = true;
        navigator.pop();
      }
    }

    // Show loading while fetching server token
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
    );

    try {
      if (kDebugMode) {
        print('[_joinEvent] ▶ event.roomName=${event.roomName}');
        print('[_joinEvent] ▶ event.roomUrl=${event.roomUrl}');
        print('[_joinEvent] ▶ student.name=${student.name} id=${student.id}');
      }

      // Extract actual room name from roomUrl (the room= query param has the correct name)
      // e.g. roomUrl = "/lesson/?room=event_1772749321_9402&..." → "event_1772749321_9402"
      String actualRoomName = event.roomName;
      if (event.roomUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(event.roomUrl.startsWith('http')
              ? event.roomUrl
              : 'https://placeholder.com${event.roomUrl}');
          final roomParam = uri.queryParameters['room'];
          if (roomParam != null && roomParam.isNotEmpty) {
            actualRoomName = roomParam;
          }
        } catch (_) {}
      }
      if (kDebugMode) {
        print('[_joinEvent] ▶ actualRoomName=$actualRoomName');
      }

      // Fetch server-side token — same mechanism as the web system
      final (tokenData, tokenErrorCode) =
          await WordPressApi().getMeetingTokenWithError(
        roomName: actualRoomName,
        studentName: student.name,
      );

      dismissDialog();
      if (!mounted) return;

      final tokenResult = _resolveMeetingToken(tokenData, tokenErrorCode);
      if (tokenResult == null) return;

      if (kDebugMode) {
        print('[_joinEvent] serverToken=${tokenResult.serverToken != null ? "✅ present" : "⚠️ null → local fallback"}');
        print('[_joinEvent] serverUrl=${tokenResult.serverUrl}');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MeetingPage(
            roomName: actualRoomName,
            participantName: student.name,
            participantId: student.id.toString(),
            participantEmail: student.email ?? '',
            lessonName: event.title,
            teacherName: event.teacherName,
            serverToken: tokenResult.serverToken,
            serverUrl: tokenResult.serverUrl,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('[_joinEvent] ❌ EXCEPTION: $e');
        print('[_joinEvent] ❌ stacktrace: $st');
      }
      dismissDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الانضمام للحدث: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNextLesson({bool forceRefresh = false}) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Get student data
        final student = authState.student!;

        _lessonName = student.displayLessonName;
        _teacherName = student.teacherName ?? 'المعلم';
        _teacherGender = student.teacherGender ?? 'ذكر';
        _teacherImage = student.teacherImage;

        // Set timezone based on student's country so times display correctly on all platforms
        TimezoneHelper.setUserCountry(student.country);

        // Get reports to check which schedules already have reports
        final reports = await _reportRepository.getStudentReports(
          student.id,
          forceRefresh: forceRefresh,
        );

        // Sort reports to find the last one
        if (reports.isNotEmpty) {
          reports.sort((a, b) {
            try {
              final dateA = DateTime.parse('${a.date} ${a.time}');
              final dateB = DateTime.parse('${b.date} ${b.time}');
              return dateB.compareTo(dateA); // Descending
            } catch (e) {
              return 0;
            }
          });
          _lastReport = reports.first;
        } else {
          _lastReport = null;
        }

        // Get next schedule with force refresh
        final nextSchedule = await _scheduleRepository.getNextSchedule(
          student.id,
          forceRefresh: forceRefresh,
        );

        if (!mounted) return;

        if (nextSchedule != null) {
          setState(() {
            _nextSchedule = nextSchedule;
            if (nextSchedule.schedules.isNotEmpty) {
              _findNextLesson(nextSchedule.schedules, reports);
              if (_nextLesson != null) {
                // _updateCountdown calls setState, so we should call it outside this setState or ensure it's safe
                // But _findNextLesson calls _updateCountdown internally? No, we call it here.
                // Actually _updateCountdown calls setState, so we shouldn't call it inside setState.
                // Let's defer it to after this frame or just call it directly since we are already in setState context
                // effectively we just want to update the duration.
                // Ideally, _updateCountdown shouldn't call setState if we are already in a build phase or update logic.
                // However, fixing the missing mounted check is the priority.
                // Refactoring: Call _updateCountdown logic without setState, or just let it be but ensure we are mounted.
              }
              _countdownTimer?.cancel();
              _countdownTimer = Timer.periodic(const Duration(seconds: 1), (
                _,
              ) {
                if (mounted) _updateCountdown();
              });
            } else {
              _nextLesson = null;
            }
          });
          // Update countdown explicitly after state change
          if (mounted && _nextLesson != null) {
            _updateCountdown();
          }
        } else {
          setState(() {
            _nextLesson = null;
            _nextSchedule = null;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading next lesson: $e');
        }
        if (mounted) {
          setState(() {
            _nextLesson = null;
            _nextSchedule = null;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _findNextLesson(
      List<Schedule> schedules, List<StudentReport> reports) async {
    if (schedules.isEmpty) {
      _nextLesson = null;
      return;
    }

    // Use Egypt time for comparisons since schedules are stored in Egypt time
    final nowLocal = DateTime.now();
    final now = TimezoneHelper.localToEgypt(nowLocal);

    if (kDebugMode) {
      print('Timezone: Local time: $nowLocal, Egypt time: $now');
    }

    // Create a set of report date+time keys for quick lookup
    // Format: "YYYY-MM-DD|HH:MM" to uniquely identify each lesson
    final reportDateTimes = reports.map((r) {
      try {
        final date = DateTime.parse(r.date);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final timeStr = _normalizeTimeForComparison(r.time);
        return '$dateStr|$timeStr';
      } catch (e) {
        return '${r.date}|${r.time}';
      }
    }).toSet();
    if (kDebugMode) {
      print('Report date+times to exclude: $reportDateTimes');
    }

    // Create a list of all upcoming lessons with their actual DateTime
    List<Map<String, dynamic>> upcomingLessons = [];

    // Track added trial lessons to prevent duplicates (key: "trialDate|trialTime")
    Set<String> addedTrialLessons = {};

    for (var schedule in schedules) {
      DateTime? lessonDateTime;
      String? lessonDateStr;

      // Debug each schedule
      if (kDebugMode) {
        print(
          'Checking schedule: day=${schedule.day}, hour=${schedule.hour}, isPostponed=${schedule.isPostponed}, postponedDate=${schedule.postponedDate}, isTrial=${schedule.isTrial}, trialDate=${schedule.trialDate}',
        );
      }

      if (schedule.isTrial && schedule.trialDate != null) {
        // Handle trial lessons with specific dates
        try {
          if (kDebugMode) {
            print(
              'Processing trial lesson: ${schedule.day} at ${schedule.hour}, trial_date: ${schedule.trialDate}',
            );
          }

          // Use trialDatetime if available, otherwise parse from trialDate + trialTime
          DateTime? trialDateTime;
          if (schedule.trialDatetime != null) {
            try {
              trialDateTime = DateTime.parse(schedule.trialDatetime!);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing trial_datetime: $e');
              }
            }
          }

          // If trialDatetime parsing failed or not available, use trialDate + hour
          if (trialDateTime == null) {
            final trialDate = DateTime.parse(schedule.trialDate!);
            final lessonTime = _parseTimeString(schedule.hour);

            if (lessonTime != null) {
              trialDateTime = DateTime(
                trialDate.year,
                trialDate.month,
                trialDate.day,
                lessonTime.hour,
                lessonTime.minute,
              );
            }
          }

          if (trialDateTime != null) {
            lessonDateTime = trialDateTime;
            lessonDateStr =
                '${trialDateTime.year}-${trialDateTime.month.toString().padLeft(2, '0')}-${trialDateTime.day.toString().padLeft(2, '0')}';

            if (kDebugMode) {
              print('Created trial lesson DateTime: $lessonDateTime');
              print('Current time: $now');
              print(
                  'Is trial lesson in future? ${lessonDateTime.isAfter(now)}');
            }
          } else {
            if (kDebugMode) {
              print('Failed to create trial lesson DateTime');
            }
            continue;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing trial lesson date: $e');
          }
          continue;
        }

        // Check if this trial lesson already has a report (date+time match)
        final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final lessonKey = '$lessonDateStr|$lessonTimeStr';
        if (reportDateTimes.contains(lessonKey)) {
          if (kDebugMode) {
            print(
              'Skipping trial lesson at $lessonKey - report already exists',
            );
          }
          continue;
        }

        // IMPORTANT: Check for duplicate trial lessons
        // Create a unique key for this trial lesson
        final trialKey =
            '${schedule.trialDate}|${_normalizeTimeForComparison(schedule.hour)}';
        if (addedTrialLessons.contains(trialKey)) {
          if (kDebugMode) {
            print(
              'Skipping duplicate trial lesson: $trialKey (already added)',
            );
          }
          continue; // Skip duplicate trial lesson
        }
        // Mark this trial lesson as added
        addedTrialLessons.add(trialKey);
      } else if (schedule.isPostponed && schedule.postponedDate != null) {
        // Handle postponed schedules with specific dates
        try {
          if (kDebugMode) {
            print(
              'Processing postponed schedule: ${schedule.day} at ${schedule.hour}, postponed_date: ${schedule.postponedDate}',
            );
          }
          final postponedDate = DateTime.parse(schedule.postponedDate!);
          lessonDateStr =
              '${postponedDate.year}-${postponedDate.month.toString().padLeft(2, '0')}-${postponedDate.day.toString().padLeft(2, '0')}';
          if (kDebugMode) {
            print(
              'Parsed postponed date: $postponedDate, dateStr: $lessonDateStr',
            );
          }
          final lessonTime = _parseTimeString(schedule.hour);
          if (kDebugMode) {
            print('Parsed lesson time: $lessonTime');
          }
          if (lessonTime != null) {
            lessonDateTime = DateTime(
              postponedDate.year,
              postponedDate.month,
              postponedDate.day,
              lessonTime.hour,
              lessonTime.minute,
            );
            if (kDebugMode) {
              print('Created postponed lesson DateTime: $lessonDateTime');
              print('Current time: $now');
              print(
                'Is postponed lesson in future? ${lessonDateTime.isAfter(now)}',
              );
            }
          } else {
            if (kDebugMode) {
              print('Failed to parse lesson time for postponed schedule');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing postponed date: $e');
          }
          continue;
        }

        // Check if this postponed lesson already has a report (date+time match)
        final lessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        final lessonKey = '$lessonDateStr|$lessonTimeStr';
        if (reportDateTimes.contains(lessonKey)) {
          if (kDebugMode) {
            print(
              'Skipping postponed lesson at $lessonKey - report already exists',
            );
          }
          continue;
        }
      } else {
        // Handle regular recurring schedules
        final dayMap = {
          'الأحد': DateTime.sunday,
          'الاثنين': DateTime.monday,
          'الثلاثاء': DateTime.tuesday,
          'الأربعاء': DateTime.wednesday,
          'الخميس': DateTime.thursday,
          'الجمعة': DateTime.friday,
          'السبت': DateTime.saturday,
        };

        final normalizedDay = _normalizeDay(schedule.day);
        final scheduledDay = dayMap[normalizedDay];
        if (scheduledDay == null) continue;

        final lessonTime = _parseTimeString(schedule.hour);
        if (lessonTime == null) continue;

        // Calculate days until the scheduled day (using Egypt time)
        int daysUntil = (scheduledDay - now.weekday) % 7;
        if (daysUntil == 0) {
          // If it's today, check if we're past the lesson window
          // Get lesson duration for the window check (default to 45 minutes for generous check)
          int lessonDurationForCheck = 45;
          if (_nextSchedule != null &&
              _nextSchedule!.lessonDuration.isNotEmpty) {
            lessonDurationForCheck =
                int.tryParse(_nextSchedule!.lessonDuration) ?? 45;
          }

          // Calculate when today's lesson window ends (10 min after lesson ends)
          final lessonMinutesFromMidnight =
              lessonTime.hour * 60 + lessonTime.minute;
          final nowMinutesFromMidnight = now.hour * 60 + now.minute;
          final lessonWindowEndMinutes =
              lessonMinutesFromMidnight + lessonDurationForCheck + 10;

          // Only push to next week if we're PAST the lesson window, not just past the start time
          if (nowMinutesFromMidnight > lessonWindowEndMinutes) {
            // Lesson window has ended, schedule is for next week
            daysUntil = 7;
          }
        }

        // FIX: Iterate through future weeks to find a slot without a report
        // Check up to 8 weeks ahead (should be enough to find an available slot)
        final regularLessonTimeStr = _normalizeTimeForComparison(schedule.hour);
        bool foundSlot = false;

        for (int weekOffset = 0; weekOffset < 8; weekOffset++) {
          final candidateDateTime = DateTime(
            now.year,
            now.month,
            now.day + daysUntil + (weekOffset * 7),
            lessonTime.hour,
            lessonTime.minute,
          );

          // Calculate the date string for comparison with reports
          final candidateDateStr =
              '${candidateDateTime.year}-${candidateDateTime.month.toString().padLeft(2, '0')}-${candidateDateTime.day.toString().padLeft(2, '0')}';
          final candidateKey = '$candidateDateStr|$regularLessonTimeStr';

          if (reportDateTimes.contains(candidateKey)) {
            if (kDebugMode) {
              print(
                'Skipping regular lesson at $candidateKey - report already exists, checking next week...',
              );
            }
            continue; // Check next week's occurrence
          }

          // Found a slot without a report!
          lessonDateTime = candidateDateTime;
          lessonDateStr = candidateDateStr;
          foundSlot = true;
          if (kDebugMode) {
            print('Found available slot at $candidateKey');
          }
          break;
        }

        if (!foundSlot) {
          if (kDebugMode) {
            print(
              'No available slot found for ${schedule.day} at ${schedule.hour} in next 8 weeks',
            );
          }
          continue; // Skip this schedule if no slot found
        }
      }
      // Include future lessons AND lessons currently in progress
      // A lesson is "in progress" if it started within (lessonDuration + 10) minutes ago
      if (lessonDateTime != null) {
        // Get lesson duration - use _nextSchedule if available, default to 45 minutes
        // for generous window filtering (we'll use the actual duration later for button logic)
        int scheduleLessonDuration = 45; // Default generous window
        if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
          scheduleLessonDuration =
              int.tryParse(_nextSchedule!.lessonDuration) ?? 45;
        }

        // Calculate when the lesson window ends (10 min after lesson ends)
        final lessonWindowEnd = lessonDateTime.add(
          Duration(minutes: scheduleLessonDuration + 10),
        );

        // Include if lesson is in the future OR if we're within the lesson window
        if (lessonDateTime.isAfter(now) || now.isBefore(lessonWindowEnd)) {
          if (kDebugMode) {
            print(
              'Adding upcoming/in-progress lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime, isPostponed: ${schedule.isPostponed}, isTrial: ${schedule.isTrial}',
            );
          }
          upcomingLessons.add({
            'schedule': schedule,
            'dateTime': lessonDateTime,
          });
        } else {
          if (kDebugMode) {
            print(
              'Skipping past lesson: ${schedule.day} at ${schedule.hour}, dateTime: $lessonDateTime (window ended at: $lessonWindowEnd)',
            );
          }
        }
      }
    }

    // Sort by date/time and get the earliest one
    if (upcomingLessons.isNotEmpty) {
      if (kDebugMode) {
        print(
          'Found ${upcomingLessons.length} upcoming lessons before sorting',
        );
      }
      upcomingLessons.sort(
        (a, b) =>
            (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
      );

      if (kDebugMode) {
        print('Sorted upcoming lessons:');
        for (int i = 0; i < upcomingLessons.length; i++) {
          final lesson = upcomingLessons[i];
          final schedule = lesson['schedule'] as Schedule;
          final dateTime = lesson['dateTime'] as DateTime;
          print(
            '  $i: ${schedule.day} at ${schedule.hour}, dateTime: $dateTime, isPostponed: ${schedule.isPostponed}, isTrial: ${schedule.isTrial}',
          );
        }
      }

      _nextLesson = upcomingLessons.first['schedule'] as Schedule;
      final egyptDateTime = upcomingLessons.first['dateTime'] as DateTime;
      // Local time for display (student's country timezone)
      _nextLessonDateTime =
          await TimezoneHelper.egyptToLocalAsync(egyptDateTime);
      // UTC time for countdown & join logic (works correctly on all platforms)
      _nextLessonUtc = TimezoneHelper.egyptToUtc(egyptDateTime);
      if (kDebugMode) {
        print(
            'Selected next lesson: ${_nextLesson!.day} at ${_nextLesson!.hour}');
        print('  Egypt time: $egyptDateTime');
        print('  UTC time: $_nextLessonUtc');
        print('  Local display time: $_nextLessonDateTime');
        print('  DateTime.now().toUtc(): ${DateTime.now().toUtc()}');
      }
    } else {
      if (kDebugMode) print('No upcoming lessons found');
      _nextLesson = null;
      _nextLessonDateTime = null;
      _nextLessonUtc = null;
    }
  }

  void _updateCountdown() {
    // Use UTC for countdown so it works correctly on all platforms (web/native)
    if (_nextLessonUtc != null) {
      final now = DateTime.now().toUtc();
      final previousDuration = _timeUntilNextLesson;
      Duration? newDuration;

      if (_nextLessonUtc!.isAfter(now)) {
        // Lesson hasn't started yet - show countdown
        newDuration = _nextLessonUtc!.difference(now);
      } else {
        // Lesson has started or is in progress
        int lessonDuration = 30;
        if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
          lessonDuration = int.tryParse(_nextSchedule!.lessonDuration) ?? 30;
        }

        // Calculate lesson end time + 10 minutes (in UTC)
        final lessonEndPlusTenMin = _nextLessonUtc!.add(
          Duration(minutes: lessonDuration + 10),
        );

        if (now.isBefore(lessonEndPlusTenMin)) {
          // Within the lesson period - show 0:0:0
          newDuration = Duration.zero;
        } else {
          // Past the lesson period - load next lesson
          newDuration = null;
        }
      }

      if ((previousDuration == null ||
              previousDuration.inSeconds != newDuration?.inSeconds) &&
          mounted) {
        setState(() {
          _timeUntilNextLesson = newDuration;
        });
      }
    }
  }

  DateTime? _parseTimeString(String timeString) {
    try {
      final parts = timeString.trim().split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      final int minute = int.tryParse(timeParts[1]) ?? 0;

      String ampm = parts[1].toUpperCase();
      if (ampm == 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  String _normalizeDay(String day) {
    switch (day.trim()) {
      case 'الاحد':
        return 'الأحد';
      case 'الإثنين':
        return 'الاثنين';
      case 'الاربعاء':
        return 'الأربعاء';
      case 'الجمعه':
        return 'الجمعة';
      default:
        return day.trim();
    }
  }

  /// Normalizes time string to "HH:MM" format for comparison (strips seconds)
  String _normalizeTimeForComparison(String timeString) {
    try {
      // First try parsing with _parseTimeString (handles AM/PM)
      final parsed = _parseTimeString(timeString);
      if (parsed != null) {
        return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
      // Fallback: if it's already in HH:MM:SS or HH:MM format, extract HH:MM
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  Widget _buildNextLessonSection() {
    // Try to get latest from Bloc to ensure reactivity
    String? teacherImage = _teacherImage;
    String teacherName = _teacherName;
    String teacherGender = _teacherGender;

    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      teacherImage = authState.student!.teacherImage;
      teacherName = authState.student!.teacherName ?? teacherName;
      teacherGender = authState.student!.teacherGender ?? teacherGender;
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFf6c302), // Gold color for better visibility
          backgroundColor: const Color(0x33FFFFFF), // 0.2 opacity white
        ),
      );
    }

    if (_nextLesson == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'لا يوجد دروس مجدولة',
            style: TextStyle(
              fontFamily: 'Qatar',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Determine if user can join the lesson
    int lessonDuration = 30;
    if (_nextSchedule != null && _nextSchedule!.lessonDuration.isNotEmpty) {
      lessonDuration =
          int.tryParse(_nextSchedule!.lessonDuration) ?? lessonDuration;
    }

    bool canJoin = false;
    bool canPostpone = true;

    // Calculate actual time difference using UTC so it's correct on all platforms
    if (_nextLessonUtc != null) {
      final now = DateTime.now().toUtc();
      final actualDifference = _nextLessonUtc!.difference(now);
      final minutesUntilStart = actualDifference.inMinutes;
      final minutesAfterStart =
          -minutesUntilStart; // Positive after lesson starts

      // إنضم للدرس (Join Lesson):
      // Active from 15 minutes BEFORE lesson start until 10 minutes AFTER lesson ends
      // Lesson ends at: lessonDuration minutes after start
      // So active when: minutesUntilStart <= 15 AND minutesAfterStart <= (lessonDuration + 10)
      if (minutesUntilStart <= 15 &&
          minutesAfterStart <= (lessonDuration + 10)) {
        canJoin = true;
      }

      // تأجيل الدرس (Postpone Lesson):
      // Disabled from 1 hour (60 minutes) BEFORE lesson until 10 minutes AFTER lesson ends
      // So disabled when: minutesUntilStart <= 60 AND minutesAfterStart <= (lessonDuration + 10)
      if (minutesUntilStart <= 60 &&
          minutesAfterStart <= (lessonDuration + 10)) {
        canPostpone = false;
      }
    }

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isDesktop = screenWidth >= 600;

    // Responsive sizes
    final containerPadding = isSmallScreen ? 12.0 : 16.0;
    final avatarRadius = isSmallScreen ? 16.0 : 20.0;
    final subjectFontSize = isSmallScreen ? 14.0 : 16.0;
    final dayFontSize = isSmallScreen ? 14.0 : 16.0;
    final timeFontSize = isSmallScreen ? 12.0 : 14.0;
    final teacherLabelSize = isSmallScreen ? 10.0 : 11.0;
    final teacherNameSize = isSmallScreen ? 11.0 : 13.0;

    // Desktop: Larger buttons
    final buttonFontSize = isDesktop ? 16.0 : (isSmallScreen ? 12.0 : 14.0);
    final buttonPaddingH = isDesktop ? 24.0 : (isSmallScreen ? 10.0 : 16.0);
    final buttonPaddingV = isDesktop ? 16.0 : (isSmallScreen ? 4.0 : 8.0);

    return Column(
      children: [
        // Gradient box with lesson info (like bottom nav bar)
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            // Gradient background like bottom nav bar
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255), // Warm cream white
                Color.fromARGB(255, 230, 230, 230), // Subtle gold tint
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(140, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Main row: Subject (right) | Avatar+Teacher (center) | Day+Time (left)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Right: Subject name
                  Expanded(
                    flex: 2,
                    child: Text(
                      _lessonName,
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: subjectFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Center: Avatar + المعلم + Teacher name (in a row)
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: const Color.fromARGB(
                            255,
                            230,
                            230,
                            230,
                          ),
                          backgroundImage: (teacherImage != null &&
                                  teacherImage.isNotEmpty)
                              ? NetworkImage(teacherImage)
                              : AssetImage(
                                  GenderHelper.getTeacherImage(teacherGender),
                                ) as ImageProvider,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              GenderHelper.getTeacherTitle(teacherGender),
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: teacherLabelSize,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              teacherName.split(' ').first,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: teacherNameSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Left: Day + Time - pushed to the far left
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // Push to far left in RTL
                      children: [
                        Text(
                          _nextLessonDateTime != null
                              ? TimezoneUtils.getArabicDayName(
                                  _nextLessonDateTime!,
                                )
                              : _nextLesson!.day,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: dayFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2), // Reduced spacing
                        Text(
                          _nextLessonDateTime != null
                              ? TimezoneUtils.formatTime(_nextLessonDateTime!)
                              : _nextLesson!.hour,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: timeFontSize,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Countdown section
              if (_timeUntilNextLesson != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      // Background Text Layer
                      Transform.translate(
                        offset: const Offset(
                          0,
                          -2,
                        ), // Slight vertical adjustment
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'الوقـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــت', // Extended line
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.0,
                                letterSpacing:
                                    0.3, // Tighten slightly to connect
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                            SizedBox(
                              height: 8,
                            ), // Space between lines to match boxes
                            Text(
                              'المتبقـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــي', // Extended line
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.0,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),
                      // Foreground Countdown Layer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Padding to avoid covering the words "الوقت/المتبقي"
                          // Adjust this width based on the visual length of "الوقـ/المتبقـ"
                          const SizedBox(width: 50),

                          // Days (shown if > 0)
                          if (_timeUntilNextLesson!.inDays > 0) ...[
                            _buildCountdownItem(
                              _timeUntilNextLesson!.inDays,
                              'يوم',
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Hours
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inHours % 24,
                            'ساعة',
                          ),
                          const SizedBox(width: 8),
                          // Minutes
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inMinutes % 60,
                            'دقيقة',
                          ),
                          const SizedBox(width: 8),
                          // Seconds
                          _buildCountdownItem(
                            _timeUntilNextLesson!.inSeconds % 60,
                            'ثانية',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Buttons below the box - smaller and aligned to right side
        SizedBox(height: isSmallScreen ? 8 : 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Start = right in RTL
            mainAxisSize: MainAxisSize.min,
            children: [
              // إنضم للدرس button - green gradient when can join, light yellow when can't
              Container(
                key: widget.joinLessonKey,
                decoration: BoxDecoration(
                  gradient: canJoin
                      ? const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 101, 206, 107), // Light green
                            Color.fromARGB(255, 63, 151, 66), // Green
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            Color.fromARGB(0, 255, 255, 255), // Light yellow
                            Color.fromARGB(0, 240, 191, 12), // Lighter yellow
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color.fromARGB(157, 255, 255, 255),
                    width: 1.5,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: canJoin ? _joinLesson : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      vertical: buttonPaddingV,
                      horizontal: buttonPaddingH,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'إنضم للدرس',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                      color: canJoin
                          ? Colors.white
                          : const Color.fromARGB(157, 255, 255, 255),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 6 : 10),
              // تأجيل الدرس (white border only) - smaller button
              OutlinedButton(
                key: widget.rescheduleKey,
                onPressed: canPostpone ? _openPostponePage : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: canPostpone
                        ? Colors.white
                        : const Color.fromARGB(255, 117, 117, 117),
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: buttonPaddingV,
                    horizontal: buttonPaddingH,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'إعادة جدولة',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.bold,
                    color: canPostpone ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),

              // الانجاز السابق button
              if (_lastReport != null) ...[
                SizedBox(width: isSmallScreen ? 6 : 10),
                Container(
                  key: widget.prevAchievementKey,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 253, 247, 89), // Light yellow
                        Color.fromARGB(255, 240, 191, 12), // Lighter yellow
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportDetailsPage(
                            report: _lastReport!,
                            teacherGender: teacherGender,
                            teacherImage: teacherImage,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor:
                          Colors.black, // darker text for yellow bg
                      padding: EdgeInsets.symmetric(
                        vertical: buttonPaddingV,
                        horizontal: buttonPaddingH,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'الانجاز السابق',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: Colors.white, height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildCountdownItem(int value, String label) {
    return Container(
      width: 40, // Fixed width for consistency
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ), // horizontal padding removed as width is fixed
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.0, // Reduced line height
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Qatar',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the Events Section - Shows upcoming events with countdown and join button
  Widget _buildEventsSection() {
    if (_nextEvent == null) return const SizedBox.shrink();

    final event = _nextEvent!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isDesktop = screenWidth >= 600;
    final containerPadding = isSmallScreen ? 12.0 : 16.0;
    final buttonFontSize = isDesktop ? 16.0 : (isSmallScreen ? 12.0 : 14.0);
    final buttonPaddingH = isDesktop ? 24.0 : (isSmallScreen ? 16.0 : 24.0);
    final buttonPaddingV = isDesktop ? 16.0 : (isSmallScreen ? 8.0 : 12.0);
    final subjectFontSize = isSmallScreen ? 16.0 : 18.0;
    final dayFontSize = isSmallScreen ? 14.0 : 16.0;
    final timeFontSize = isSmallScreen ? 12.0 : 14.0;

    // Use the converted local time for display
    String formattedDate = event.date;
    String formattedTime = event.time;

    if (_eventLocalDateTime != null) {
      formattedDate = TimezoneUtils.getArabicDayName(_eventLocalDateTime!);
      formattedTime = TimezoneUtils.formatTime(_eventLocalDateTime!);
    }

    // Always show countdown if we have time data
    bool shouldShowCountdown = _timeUntilEvent != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - Same style as "العب مع زواد"
          const Row(
            children: [
              Icon(Icons.event_available, color: Color(0xFFD4AF37), size: 32),
              SizedBox(width: 8),
              Text(
                'فعالية قادمة',
                style: TextStyle(
                  fontFamily: 'Qatar',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Event Card - Same white gradient style as lesson card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              // Gradient background like lesson card
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 255, 255, 255), // Warm cream white
                  Color.fromARGB(255, 230, 230, 230), // Subtle gold tint
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromARGB(140, 0, 0, 0),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Event Media - full-bleed at the top
                  if (event.mediaUrl != null && event.mediaUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: event.mediaType == 'video'
                          ? _InlineVideoPlayer(
                              videoUrl: event.mediaUrl!,
                              height: isSmallScreen ? 160.0 : 200.0,
                            )
                          : Image.network(
                              event.mediaUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: isSmallScreen ? 160.0 : 200.0,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],

                  // Padded content below media
                  Padding(
                    padding: EdgeInsets.all(containerPadding),
                    child: Column(
                      children: [
                        // Event Title - Same style as lesson subject
                        Text(
                          event.title,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: subjectFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Date and Time Row - Same style as lesson card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: const Color(0xFFD4AF37),
                              size: isSmallScreen ? 16 : 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: dayFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              color: const Color(0xFFD4AF37),
                              size: isSmallScreen ? 16 : 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: timeFontSize,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Countdown Timer - Always show if event is in the future
                        if (shouldShowCountdown) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 60,
                            child: Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                // Background Text Layer
                                Transform.translate(
                                  offset: const Offset(0, -2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'الوقــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــت',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.0,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'المتبقــــــــــــــــــــــــــــــــــــــــــــــــــــــــــي',
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.0,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ],
                                  ),
                                ),
                                // Foreground Countdown Layer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 50),
                                    if (_timeUntilEvent!.inDays > 0) ...[
                                      _buildCountdownItem(
                                        _timeUntilEvent!.inDays,
                                        'يوم',
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    _buildCountdownItem(
                                      _timeUntilEvent!.inHours % 24,
                                      'ساعة',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCountdownItem(
                                      _timeUntilEvent!.inMinutes % 60,
                                      'دقيقة',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCountdownItem(
                                      _timeUntilEvent!.inSeconds % 60,
                                      'ثانية',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Buttons below the card - Same style as lesson buttons
          SizedBox(height: isSmallScreen ? 8 : 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Join Event Button - Same green gradient style as "إنضم للدرس"
                Container(
                  decoration: BoxDecoration(
                    gradient: event.canJoin
                        ? const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 101, 206, 107),
                              Color.fromARGB(255, 63, 151, 66),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [
                              Color.fromARGB(0, 255, 255, 255),
                              Color.fromARGB(0, 240, 191, 12),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromARGB(157, 255, 255, 255),
                      width: 1.5,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: event.canJoin ? _joinEvent : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      disabledForegroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        vertical: buttonPaddingV,
                        horizontal: buttonPaddingH,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.video_call,
                          color: event.canJoin
                              ? Colors.white
                              : const Color.fromARGB(157, 255, 255, 255),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'انضم للحدث',
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.bold,
                            color: event.canJoin
                                ? Colors.white
                                : const Color.fromARGB(157, 255, 255, 255),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection() {
    if (_isLoadingUserMessage && _latestUserMessage == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_latestUserMessage == null) return const SizedBox.shrink();

    final message = _latestUserMessage!;
    final bodyText = _stripHtmlTags(message.message);
    final isHighPriority = message.isHighPriority;
    final accentColor =
        isHighPriority ? const Color(0xFF820C22) : const Color(0xFFD4AF37);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _openUserMessageDetails(message),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent left strip
                  Container(
                    width: 5,
                    color: accentColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isHighPriority
                                    ? Icons.campaign_rounded
                                    : Icons.mail_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  message.title,
                                  style: const TextStyle(
                                    fontFamily: 'Qatar',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              if (_userMessagesUnreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF820C22),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$_userMessagesUnreadCount',
                                    style: const TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_formatMessageDate(message.createdAt).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatMessageDate(message.createdAt),
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 11,
                                color: accentColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            bodyText,
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPostponePage() async {
    if (_nextSchedule == null) return;

    // Fetch teacher free slots from repository
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated || authState.student == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('خطأ في بيانات الطالب')));
        return;
      }

      final student = authState.student!;
      final teacherId = student.teacherId ?? 0;
      if (teacherId == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لا يوجد معلم مسجل')));
        return;
      }

      // Get student's lesson duration
      final lessonDuration = int.tryParse(student.lessonDuration ?? '0') ?? 0;

      final slots = await _scheduleRepository.getTeacherFreeSlots(teacherId);

      // Get current lesson information
      String? currentLessonDate;
      String? currentLessonTime;
      String? currentLessonDay;

      if (_nextLesson != null) {
        currentLessonDay = _nextLesson!.day;
        currentLessonTime = _nextLesson!.hour;

        // Calculate the date of the current lesson
        final now = TimezoneHelper.nowInEgypt();
        final dayMap = {
          'الأحد': DateTime.sunday % 7,
          'الاثنين': DateTime.monday % 7,
          'الثلاثاء': DateTime.tuesday % 7,
          'الأربعاء': DateTime.wednesday % 7,
          'الخميس': DateTime.thursday % 7,
          'الجمعة': DateTime.friday % 7,
          'السبت': DateTime.saturday % 7,
        };

        final currentDayValue = now.weekday % 7;
        final lessonDayValue = dayMap[currentLessonDay] ?? currentDayValue;

        int daysUntilLesson = (lessonDayValue - currentDayValue) % 7;
        if (daysUntilLesson == 0) {
          // Check if lesson is today but in the future
          final lessonTime = _parseTimeString(currentLessonTime);
          if (lessonTime != null &&
              (lessonTime.hour < now.hour ||
                  (lessonTime.hour == now.hour &&
                      lessonTime.minute <= now.minute))) {
            daysUntilLesson = 7; // Next week
          }
        }

        final lessonDate = now.add(Duration(days: daysUntilLesson));
        currentLessonDate =
            '${lessonDate.year}-${lessonDate.month.toString().padLeft(2, '0')}-${lessonDate.day.toString().padLeft(2, '0')}';
      }

      if (!mounted) return;

      // Show as modal bottom sheet to keep nav bar visible
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 255, 255, 255), // Warm cream white
                  Color.fromARGB(255, 230, 230, 230), // Subtle gold tint
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: PostponePage(
              teacherId: teacherId,
              freeSlots: slots,
              studentLessonDuration: lessonDuration,
              currentLessonDay: currentLessonDay,
              currentLessonTime: currentLessonTime,
              currentLessonDate: currentLessonDate,
              scrollController: scrollController,
              isTrial: _nextLesson?.isTrial ?? false,
              onSuccess: () {
                // Refresh schedules after successful postpone
                if (mounted) {
                  _loadNextLesson(forceRefresh: true);
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error opening postpone page: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ أثناء جلب الأوقات الحرة')),
      );
    }
  }

  Future<void> _openAlarmSettings() async {
    try {
      if (!mounted) return;

      // Show as modal bottom sheet to keep nav bar visible
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 255, 255, 255), // Warm cream white
                  Color.fromARGB(255, 230, 230, 230), // Subtle gray tint
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: AlarmSettingsPage(
              scrollController: scrollController,
              onSuccess: () {
                // Optionally refresh or show success feedback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ إعدادات المنبه')),
                  );
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error opening alarm settings: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ أثناء فتح إعدادات المن به')),
      );
    }
  }

  bool _isFetchingFamily = false;

  Future<void> _loadFamilyMembers() async {
    if (_isFetchingFamily) return;
    _isFetchingFamily = true;
    try {
      if (kDebugMode) {
        print('_loadFamilyMembers: Starting to load family members...');
      }
      final members = await _authRepository.getFamilyMembers();
      if (kDebugMode) {
        print('_loadFamilyMembers: Received ${members.length} family members');
        for (var m in members) {
          print('_loadFamilyMembers: Member: id=${m.id}, name=${m.name}');
        }
      }
      if (mounted) {
        setState(() {
          _familyMembers = members;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading family members: $e');
      }
    } finally {
      _isFetchingFamily = false;
    }
  }

  Future<void> _switchAccount(Student newStudent) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );

      // Clear caches for the new student to ensure fresh data
      await _scheduleRepository.clearCache(newStudent.id);
      await _reportRepository.clearCache(newStudent.id);

      if (!mounted) return;

      await _authRepository.switchUser(newStudent);

      if (!mounted) return;

      // Clear local state before refreshing
      setState(() {
        _nextSchedule = null;
        _nextLesson = null;
        _nextLessonDateTime = null;
        _nextLessonUtc = null;
        _lastReport = null;
        _familyMembers = []; // Clear family members so they reload
        _timeUntilNextLesson = null;
        _countdownTimer?.cancel();
        _latestUserMessage = null;
        _userMessagesUnreadCount = 0;
        _isLoadingUserMessage = false;
        _isLoading = true;
      });

      // Refresh profile - this will update the AuthBloc state
      context.read<AuthBloc>().add(GetStudentProfileEvent());

      // Pop loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Wait for AuthBloc to update with new student data
      // Poll for the new student ID with a timeout
      int attempts = 0;
      const maxAttempts = 10;
      bool foundNewStudent = false;

      while (attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;

        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated &&
            authState.student != null &&
            authState.student!.id == newStudent.id) {
          foundNewStudent = true;
          break;
        }
        attempts++;
      }

      if (!mounted) return;

      if (foundNewStudent) {
        // Now load dashboard data with the new student
        await _loadNextLesson(forceRefresh: true);
        await _loadNextEvent();
        await _loadLatestUserMessage();
      } else {
        // Force load anyway after timeout
        await _loadNextLesson(forceRefresh: true);
        await _loadNextEvent();
        await _loadLatestUserMessage();
      }
    } catch (e) {
      if (mounted) {
        // Pop loading dialog if still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تغيير الحساب: $e')));
      }
    }
  }

  Future<void> _showAccountSelection(BuildContext context) async {
    if (_familyMembers.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingFamily = true;
        });
      }
      await _loadFamilyMembers();
      if (mounted) {
        setState(() {
          _loadingFamily = false;
        });
      }
    }

    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final currentStudentId =
        authState is AuthAuthenticated ? authState.student?.id : null;

    final RenderBox button =
        (widget.studentMenuKey.currentContext?.findRenderObject() ??
            context.findRenderObject()) as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Get button position in overlay coordinates
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    // Position the menu below the button
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx, // left
      buttonPosition.dy +
          buttonSize.height +
          8, // top - below button with 8px gap
      overlay.size.width - buttonPosition.dx - buttonSize.width, // right
      0, // bottom - let it grow upward if needed
    );

    final items = _familyMembers.isEmpty
        ? [
            const PopupMenuItem<Student>(
              enabled: false,
              child: Text(
                'لا توجد حسابات مرتبطة',
                style: TextStyle(fontFamily: 'Qatar', fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
          ]
        : _familyMembers.map((student) {
            final isSelected = student.id == currentStudentId;
            return PopupMenuItem<Student>(
              value: student,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1,
                        ),
                        image: DecorationImage(
                          image: student.profileImageUrl != null &&
                                  student.profileImageUrl!.isNotEmpty
                              ? NetworkImage(student.profileImageUrl!)
                              : const AssetImage(
                                  'assets/images/male_avatar.webp',
                                ) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontFamily: 'Qatar',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (student.lessonsName != null &&
                              student.lessonsName!.isNotEmpty)
                            Text(
                              student.displayLessonName,
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }).toList();

    showMenu<Student>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: items,
    ).then((Student? selected) {
      if (selected != null && selected.id != currentStudentId) {
        _switchAccount(selected);
      }
    });
  }

  Future<void> _joinLesson() async {
    if (_nextLesson == null) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.student == null) return;
    final student = authState.student!;

    // Capture navigator before async gap so dialog can be dismissed even if widget unmounts
    final navigator = Navigator.of(context);
    bool dialogDismissed = false;

    void dismissDialog() {
      if (!dialogDismissed) {
        dialogDismissed = true;
        navigator.pop();
      }
    }

    // Show loading while fetching server token
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
    );

    try {
      final roomName = _generateRoomName();
      if (kDebugMode) {
        print('[_joinLesson] roomName=$roomName studentName=${student.name}');
      }

      // Fetch server-side token — same as _joinEvent so the room matches
      final (tokenData, tokenErrorCode) =
          await WordPressApi().getMeetingTokenWithError(
        roomName: roomName,
        studentName: student.name,
      );

      dismissDialog();
      if (!mounted) return;

      final tokenResult = _resolveMeetingToken(tokenData, tokenErrorCode);
      if (tokenResult == null) return;

      if (kDebugMode) {
        print('[_joinLesson] serverToken=${tokenResult.serverToken != null ? "✅ present" : "⚠️ null → local fallback"}');
        print('[_joinLesson] serverUrl=${tokenResult.serverUrl}');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MeetingPage(
            roomName: roomName,
            participantName: student.name,
            participantId: student.id.toString(),
            participantEmail: student.email ?? '',
            lessonName: _lessonName,
            teacherName: _teacherName,
            serverToken: tokenResult.serverToken,
            serverUrl: tokenResult.serverUrl,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('[_joinLesson] ❌ EXCEPTION: $e');
        print('[_joinLesson] ❌ stacktrace: $st');
      }
      dismissDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الانضمام للدرس: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateRoomName() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.student != null) {
      final student = authState.student!;

      return LiveKitService().generateRoomName(
        studentId: student.id.toString(),
        teacherId: student.teacherId?.toString() ?? '0',
      );
    }
    return 'default_room';
  }

  /// Resolves the result of [WordPressApi.getMeetingTokenWithError] into a
  /// usable `({serverToken, serverUrl})` pair or `null` when the caller must
  /// abort (the appropriate SnackBar has already been shown).
  ///
  /// Error code semantics:
  ///  - `null`  — no HTTP response (network failure) → local-token fallback
  ///  - `-1`    — HTTP 200 with malformed body → local-token fallback
  ///  - `401`   — authentication expired → hard block, prompt re-login
  ///  - other   — server/infra error → local-token fallback
  ({String? serverToken, String? serverUrl})? _resolveMeetingToken(
    Map<String, dynamic>? tokenData,
    int? errorCode,
  ) {
    // Happy path — server supplied a valid token.
    if (tokenData != null) {
      return (
        serverToken: tokenData['token'] as String?,
        serverUrl: tokenData['server_url'] as String?,
      );
    }

    // Session expired and token refresh also failed — user must re-login.
    if (errorCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // For all other failures (403, 500, 404, -1, network, etc.) fall back to
    // a locally-generated JWT. The LiveKit API key/secret are already embedded
    // in the app (LiveKitConfig), so this exposes nothing new and ensures
    // every student can reach their lesson even when the token endpoint has
    // issues.
    if (kDebugMode) {
      print(
          '[_resolveMeetingToken] ⚠️ server token unavailable (code=$errorCode) — using local JWT fallback');
    }
    return (serverToken: null, serverUrl: null);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding to account for the nav bar
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;
    // Calculate top padding for header
    final topPadding =
        MediaQuery.of(context).padding.top + 20.0; // Header height + spacing

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF8b0628),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const LoadingWidget();
            } else if (state is AuthAuthenticated && state.student != null) {
              final student = state.student!;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _familyMembers = [];
                    _isFetchingFamily = false;
                  });
                  context.read<AuthBloc>().add(GetStudentProfileEvent());
                  await Future.wait([
                    _loadNextLesson(forceRefresh: true),
                    _loadNextEvent(),
                    _loadLatestUserMessage(),
                  ]);
                  await _loadFamilyMembers();
                },
                color: const Color(0xFFD4AF37),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    0.0,
                    topPadding,
                    0.0,
                    bottomPadding,
                  ),
                  child: Column(
                    // Outer column for full width header
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome header
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20.0, left: 24.0),
                        padding: const EdgeInsets.only(
                          right: 16.0,
                          top: 12.0,
                          bottom: 12.0,
                          left: 20.0,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ), // Warm cream white
                              Color.fromARGB(
                                255,
                                234,
                                234,
                                234,
                              ), // Subtle gold tint
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.zero,
                            bottomLeft: Radius.circular(50),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB(120, 0, 0, 0),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 1,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(
                                  0x33FFFFFF,
                                ), // 0.2 opacity white
                                backgroundImage:
                                    student.profileImageUrl != null &&
                                            student.profileImageUrl!.isNotEmpty
                                        ? NetworkImage(student.profileImageUrl!)
                                        : const AssetImage(
                                            'assets/images/male_avatar.webp',
                                          ) as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً، ${student.name}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Black text
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        28,
                                        0,
                                        0,
                                        0,
                                      ), // Very light grey bg
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          student.displayLessonName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87, // Dark text
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12), // Separate arrow
                            GestureDetector(
                              onTap: () {
                                if (widget.studentMenuKey.currentContext !=
                                    null) {
                                  _showAccountSelection(
                                    widget.studentMenuKey.currentContext!,
                                  );
                                }
                              },
                              child: Container(
                                key: widget.studentMenuKey,
                                margin: const EdgeInsets.only(top: 24.0),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    28,
                                    0,
                                    0,
                                    0,
                                  ), // Very light grey bg
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                child: _loadingFamily
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 24,
                                        color: Colors.black54,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),

                      // Responsive Wrapper for the rest of the content
                      ResponsiveContentWrapper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Action Buttons Section
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // First button - الدروس القادمة
                                  _buildQuickActionButton(
                                    imagePath: 'assets/images/lottie.json',
                                    label: 'الدروس القادمة',
                                    onTap: () {
                                      // TODO: Navigate to upcoming lessons
                                    },
                                  ),
                                  const Spacer(),
                                  // Simple Alarm Button with Bell Lottie above text - aligned to bottom
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: InkWell(
                                      key: widget.alarmSettingsKey,
                                      onTap: _openAlarmSettings,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Lottie.asset(
                                              'assets/images/alarm.json',
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.contain,
                                            ),
                                            Transform.translate(
                                              offset: const Offset(0, -15),
                                              child: Text(
                                                'اعدادات المنبه',
                                                style: TextStyle(
                                                  fontFamily: 'Qatar',
                                                  fontSize: 12,
                                                  color: Color.fromARGB(
                                                    221,
                                                    255,
                                                    255,
                                                    255,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Next Lesson Section
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildNextLessonSection(),
                            ),

                            const SizedBox(height: 20),

                            // Events Section - Shows only if there's an upcoming event
                            if (_nextEvent != null) ...[
                              _buildEventsSection(),
                              const SizedBox(height: 20),
                            ],

                            if (_latestUserMessage != null ||
                                _isLoadingUserMessage) ...[
                              _buildMessagesSection(),
                              const SizedBox(height: 20),
                            ],

                            // Wordwall Game Section Header
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.brightness_low_outlined,
                                      color: Color(0xFFD4AF37), size: 32),
                                  SizedBox(width: 8),
                                  Text(
                                    'العب مع زواد',
                                    style: TextStyle(
                                      fontFamily: 'Qatar',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Wordwall Game Section
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0), // Widget has its own margin
                              child:
                                  WordwallGameWidget(lastReport: _lastReport),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'حدث خطأ في تحميل البيانات',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'إعادة المحاولة',
                      onPressed: () {
                        context.read<AuthBloc>().add(GetStudentProfileEvent());
                      },
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // White card - positioned in the middle
            Positioned(
              top: 35, // Half of image height (70/2) to leave space for image
              left: 0,
              right: 0,
              bottom:
                  20, // Half of yellow pill height (35/2) to leave space for pill
              child: Container(
                decoration: BoxDecoration(
                  // Gradient background matching bottom nav bar
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255), // Warm cream white
                      Color.fromARGB(255, 234, 234, 234), // Subtle gray tint
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Lottie animation at TOP - half outside, half inside white card
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Lottie.asset(
                  imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  repeat: true, // Run continuously
                ),
              ),
            ),
            // Yellow pill at BOTTOM - half inside, half outside white card
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: Container(
                height: 25,
                decoration: BoxDecoration(
                  color: const Color(0xFFf6c302), // Yellow background
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        135,
                        0,
                        0,
                        0,
                      ).withOpacity(0.2),
                      blurRadius: 5,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Qatar',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.black,
                    ),
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

/// Inline video player — initializes immediately to show first frame as thumbnail.
/// Fixed height always; tapping plays/pauses inline without resizing.
class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double height;

  const _InlineVideoPlayer({required this.videoUrl, required this.height});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      // Seek to first frame so it shows as thumbnail (don't autoplay)
      await ctrl.seekTo(Duration.zero);
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 40),
                SizedBox(height: 8),
                Text(
                  'تعذّر تشغيل الفيديو',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ),
        ),
      );
    }

    // Use AspectRatio so the full video is visible — no cropping
    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_controller!),
            // Play/pause overlay - always visible when paused
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller!,
              builder: (_, value, __) {
                if (value.isPlaying) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.black38,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 96,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
