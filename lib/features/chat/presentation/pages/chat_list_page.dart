import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/services/chat_event_service.dart';
import '../../data/models/contact.dart';
import '../../data/models/conversation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/student.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'package:zuwad/features/auth/presentation/bloc/auth_state.dart';
import 'package:zuwad/core/utils/gender_helper.dart';
import 'chat_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final AuthRepository _authRepository = AuthRepository();
  final ChatEventService _chatEventService = ChatEventService();

  List<Contact> _contacts = [];
  List<Conversation> _conversations = [];
  Map<int, String> _teacherSubjectsById = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  StreamSubscription<ChatEvent>? _chatEventSubscription;

  // Tutorial Keys
  final GlobalKey _teacherKey = GlobalKey();
  final GlobalKey _supervisorKey = GlobalKey();

  bool _isTeacherContact(Contact c) {
    final role = c.role.toLowerCase();
    final relation = c.relation.toLowerCase();
    return role == 'teacher' || relation == 'teacher';
  }

  bool _isSupervisorContact(Contact c) {
    final role = c.role.toLowerCase();
    final relation = c.relation.toLowerCase();
    return role == 'supervisor' ||
        role == 'mini-visor' ||
        relation == 'supervisor' ||
        relation == 'mini-visor';
  }

  Future<List<Student>> _resolveFamilyMembersWithTeacherData(
    List<Student> familyMembers,
  ) async {
    if (familyMembers.isEmpty) return familyMembers;

    final resolved = await Future.wait(
      familyMembers.map((member) async {
        final profile = await _authRepository.getStudentProfileById(member.id);
        return profile ?? member;
      }),
    );

    return resolved;
  }

  Map<int, String> _buildTeacherSubjectsMap(List<Student> familyMembers) {
    final Map<int, Set<String>> subjectsByTeacher = {};

    for (final student in familyMembers) {
      final teacherId = student.teacherId ?? 0;
      if (teacherId <= 0) continue;

      final lessonName = student.lessonsName;
      if (lessonName == null || lessonName.trim().isEmpty) continue;

      final displaySubject = Student.getDisplayLessonName(lessonName.trim());
      if (displaySubject.isEmpty) continue;

      subjectsByTeacher.putIfAbsent(teacherId, () => <String>{});
      subjectsByTeacher[teacherId]!.add(displaySubject);
    }

    return subjectsByTeacher.map(
      (teacherId, subjects) => MapEntry(teacherId, subjects.join('، ')),
    );
  }

  List<Contact> _normalizeContactsForSelectedStudent(
    List<Contact> contacts,
    List<Student> familyMembers,
  ) {
    final familyTeacherById = <int, Student>{};
    for (final member in familyMembers) {
      final id = member.teacherId ?? 0;
      if (id > 0) {
        familyTeacherById.putIfAbsent(id, () => member);
      }
    }

    final fallbackTeacherId = int.tryParse(widget.teacherId);
    if (familyTeacherById.isEmpty &&
        fallbackTeacherId != null &&
        fallbackTeacherId > 0) {
      familyTeacherById[fallbackTeacherId] = Student(
        id: int.tryParse(widget.studentId) ?? 0,
        name: widget.studentName,
        phone: '',
        teacherId: fallbackTeacherId,
        teacherName: widget.teacherName,
      );
    }

    final supervisorId = int.tryParse(widget.supervisorId);
    final normalized = List<Contact>.from(contacts);

    final familyTeacherIds = familyTeacherById.keys.toSet();
    if (familyTeacherIds.isNotEmpty) {
      normalized.removeWhere(
        (c) => _isTeacherContact(c) && !familyTeacherIds.contains(c.id),
      );

      for (final teacherId in familyTeacherIds) {
        final hasTeacher = normalized.any((c) => c.id == teacherId);
        if (hasTeacher) continue;

        final source = familyTeacherById[teacherId];
        normalized.add(
          Contact(
            id: teacherId,
            name: (source?.teacherName != null && source!.teacherName!.isNotEmpty)
                ? source.teacherName!
                : (widget.teacherName.isNotEmpty ? widget.teacherName : 'المعلم'),
            role: 'teacher',
            relation: 'teacher',
            profileImage: source?.teacherImage,
          ),
        );
      }
    }

    if (supervisorId != null && supervisorId > 0) {
      normalized
          .removeWhere((c) => _isSupervisorContact(c) && c.id != supervisorId);
      final hasSelectedSupervisor = normalized.any((c) => c.id == supervisorId);
      if (!hasSelectedSupervisor) {
        normalized.add(
          Contact(
            id: supervisorId,
            name: widget.supervisorName.isNotEmpty
                ? widget.supervisorName
                : 'خدمة العملاء',
            role: 'supervisor',
            relation: 'supervisor',
          ),
        );
      }
    }

    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen to chat events for real-time updates
    _chatEventSubscription = _chatEventService.onChatUpdate.listen((event) {
      if (mounted) {
        if (kDebugMode) {
          print('ChatListPage received event: ${event.type}');
        }
        // Refresh conversations on any chat event
        _loadConversations(showLoading: false);
      }
    });

    // Set up periodic refresh every 30 seconds for unread counts (fallback)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadConversations(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final studentChanged = oldWidget.studentId != widget.studentId;
    final teacherChanged = oldWidget.teacherId != widget.teacherId;
    final supervisorChanged = oldWidget.supervisorId != widget.supervisorId;

    if (studentChanged || teacherChanged || supervisorChanged) {
      if (kDebugMode) {
        print(
            'ChatListPage context changed (student/teacher/supervisor). Reloading contacts and conversations.');
      }
      _loadData();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load contacts + conversations in parallel, then resolve family teachers
      final contactsFuture = _chatRepository.getContacts();
      final conversationsFuture = _chatRepository.getConversations();
      final familyMembers = await _authRepository.getFamilyMembers();
      final resolvedFamilyMembers =
          await _resolveFamilyMembersWithTeacherData(familyMembers);
      final results = await Future.wait([
        contactsFuture,
        conversationsFuture,
      ]);

      if (mounted) {
        final teacherSubjectsById =
            _buildTeacherSubjectsMap(resolvedFamilyMembers);
        final normalizedContacts = _normalizeContactsForSelectedStudent(
          results[0] as List<Contact>,
          resolvedFamilyMembers,
        );
        setState(() {
          _contacts = normalizedContacts;
          _teacherSubjectsById = teacherSubjectsById;

          // Sort contacts: Supervisor (Customer Service) first, then Teacher, then others
          _contacts.sort((a, b) {
            final aIsSupervisor = _isSupervisorContact(a);
            final bIsSupervisor = _isSupervisorContact(b);

            if (aIsSupervisor && !bIsSupervisor) return -1;
            if (!aIsSupervisor && bIsSupervisor) return 1;

            final aIsTeacher = _isTeacherContact(a);
            final bIsTeacher = _isTeacherContact(b);

            if (aIsTeacher && !bIsTeacher) return -1;
            if (!aIsTeacher && bIsTeacher) return 1;

            return 0;
          });

          _conversations = results[1] as List<Conversation>;
          _isLoading = false;
        });

        // Check for tutorial after data load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowTutorial();
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

    if (role.toLowerCase() == 'supervisor' ||
        role.toLowerCase() == 'mini-visor') {
      return Transform.scale(
        scale: 1.5,
        child: Lottie.asset(
          'assets/images/customer.json',
          fit: BoxFit.contain,
          animate: true,
          repeat: true,
        ),
      );
    }

    // For other roles, use icons
    IconData icon;
    switch (role.toLowerCase()) {
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
      case 'mini-visor':
        return 'المشرف';
      case 'student':
        return 'الطالب';
    }

    // Fallback to role
    switch (role.toLowerCase()) {
      case 'teacher':
        return (gender == 'أنثى') ? 'المعلمة' : 'المعلم';
      case 'supervisor':
      case 'mini-visor':
        return 'المشرف';
      case 'student':
        return 'الطالب';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Qatar'),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF8b0628),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryColor,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_contacts.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          16.0, MediaQuery.of(context).padding.top + 20.0, 16.0, 16.0),
      child: ResponsiveContentWrapper(
        child: Column(
          children: [
            ..._contacts.map((contact) {
              // Reset flags if it's the start of the list?
              // Actually map is called on every build, but keys must not be duplicated.
              // We will handle key assignment in _buildContactTile with logic to only assign once per build cycle if needed,
              // but stateless widgets/keys in map require care.
              // Simpler: Determine which contact gets the key BEFORE mapping or inside map securely.
              // Since keys are final, we just attach them to the specific contact.
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildContactTile(contact),
              );
            }),
          ],
        ),
      ),
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
        if (_isTeacherContact(contact)) {
          gender = authState.student!.teacherGender ?? 'ذكر';
        }
      }
    } catch (_) {}

    final roleName =
        _getRoleName(contact.role, contact.relation, gender: gender);
    final teacherSubject = _isTeacherContact(contact)
        ? _teacherSubjectsById[contact.id]
        : null;
    final roleNameWithSubject = (teacherSubject != null &&
            teacherSubject.trim().isNotEmpty)
        ? '$roleName | $teacherSubject'
        : roleName;

    // Override display name for supervisor
    String displayName = contact.name;
    bool isSupervisor = false;
    if (_isSupervisorContact(contact)) {
      displayName = 'خدمة العملاء';
      isSupervisor = true;
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
        key: _getContactKey(contact), // Assign Key logic here
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
                  clipBehavior:
                      Clip.none, // Allow badge to overflow without clipping
                  children: [
                    Container(
                      width: isSupervisor ? 70 : 56,
                      height: isSupervisor ? 70 : 56,
                      decoration: BoxDecoration(
                        // Remove background color for supervisor to show lottie clearly if needed
                        color: isSupervisor
                            ? Colors.transparent
                            : AppTheme.primaryColor
                                .withAlpha(25), // ~0.1 opacity
                        shape:
                            isSupervisor ? BoxShape.rectangle : BoxShape.circle,
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
                    // Unread badge - positioned at top-left outside avatar
                    if (unreadCount > 0)
                      Positioned(
                        right: isSupervisor ? 45 : 35,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 12, 207, 35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
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
                              roleNameWithSubject,
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

  // Helper to safely assign keys
  GlobalKey? _getContactKey(Contact contact) {
    // We need to ensure we only assign the key to ONE item to avoid GlobalKey duplications
    // Current simple logic: existing variables _hasTeacher/Supervisor are difficult to reset inside build loop cleanly without side effects.
    // Better approach: Find the index of the first teacher/supervisor in the list once, inside build or checking here.

    // Check if this contact is the FIRST teacher
    if (_isTeacherContact(contact)) {
      final firstTeacherIndex = _contacts.indexWhere((c) =>
          _isTeacherContact(c));
      if (firstTeacherIndex != -1 &&
          _contacts[firstTeacherIndex].id == contact.id) {
        return _teacherKey;
      }
    }

    // Check if this contact is the FIRST supervisor
    if (_isSupervisorContact(contact)) {
      final firstSupervisorIndex = _contacts.indexWhere((c) =>
          _isSupervisorContact(c));
      if (firstSupervisorIndex != -1 &&
          _contacts[firstSupervisorIndex].id == contact.id) {
        return _supervisorKey;
      }
    }

    return null;
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('chat_tutorial_seen_v2') ?? false;

    // Only show if we have targets
    if (!seen && !kDebugMode) {
      // Remove !kDebugMode in production if needed, ensuring debug behavior matches user request
      // Wait a bit for UI to settle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _contacts.isNotEmpty) {
          _showTutorial();
        }
      });
    } else if (kDebugMode && !seen) {
      // Force show in debug if not seen, for testing
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _contacts.isNotEmpty) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    List<TargetFocus> targets = _createTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black, // Consistent transparent black
      textSkip: "تخطي",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _markTutorialSeen();
      },
      onClickTarget: (target) {
        // Optional: Perform action
      },
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
    ).show(context: context);
  }

  void _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_tutorial_seen_v2', true);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 1. Supervisor Target (Customer Service) - REORDERED to be first
    bool hasSupervisor = _contacts.any((c) => _isSupervisorContact(c));

    if (hasSupervisor) {
      targets.add(
        TargetFocus(
          identify: "supervisor_chat",
          keyTarget: _supervisorKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "خدمة العملاء",
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
                        "لأي استفسار أو مشكلة، يمكنك التواصل مع خدمة العملاء هنا.",
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
        ),
      );
    }

    // 2. Teacher Target - REORDERED to be second
    bool hasTeacher = _contacts.any((c) => _isTeacherContact(c));

    if (hasTeacher) {
      targets.add(
        TargetFocus(
          identify: "teacher_chat",
          keyTarget: _teacherKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "المعلم",
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
                        "اضغط هنا للتواصل مع المعلم الخاص بك.",
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
                        if (hasSupervisor) ...[
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
                          const SizedBox(width: 10),
                        ],
                        // Finish Button (Done) - Flex 2
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
        ),
      );
    }

    return targets;
  }

  void _openChat(Contact contact, {String? displayNameOverride}) {
    // Determine gender to pass - reuse logic from build method or recalculate
    String gender = 'ذكر';
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        if (_isTeacherContact(contact)) {
          gender = authState.student!.teacherGender ?? 'ذكر';
        }
      }
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          recipientId: contact.id.toString(),
          recipientName: displayNameOverride ?? contact.name,
          studentId: widget.studentId,
          studentName: widget.studentName,
          recipientRole: contact.role,
          recipientGender: gender,
          recipientImage: contact.profileImage,
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

