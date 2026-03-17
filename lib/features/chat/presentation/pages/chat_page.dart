import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;

import 'package:flutter_chat_core/flutter_chat_core.dart' show ChatTheme;
import 'package:uuid/uuid.dart';

import 'package:lottie/lottie.dart';
import '../../../../core/utils/gender_helper.dart'; // Ensure this import exists
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/chat_event_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/models/chat_message.dart' as models;

/// Chat page for messaging between users.
///
/// Follows API v2 best practices:
/// - Use after_id for polling new messages
/// - Mark as read only when opening conversation or receiving new incoming messages
/// - Poll for read status updates separately
class ChatPage extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String studentId;
  final String studentName;

  /// Optional: if provided, use this conversation ID directly
  final String? conversationId;
  final String? recipientRole;
  final String? recipientGender;
  final String? recipientImage;

  const ChatPage({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.studentId,
    required this.studentName,
    this.conversationId,
    this.recipientRole,
    this.recipientGender,
    this.recipientImage,
    this.initialMessage,
  });

  final String? initialMessage;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _chatRepository;
  late final core.InMemoryChatController _chatController;
  final TextEditingController _textController =
      TextEditingController(); // Controller for input
  final ChatEventService _chatEventService = ChatEventService();
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isDisposed = false;
  int _currentPage = 1;
  Timer? _pollTimer;

  // Track all server message IDs we've seen (cleanup: keep last 500 to avoid memory bloat)
  final Set<String> _knownServerIds = {};
  static const int _maxKnownIds = 500;

  String? _serverConversationId; // Server-assigned conversation ID
  int _lastMessageId = 0; // For polling new messages
  String? _detectedRecipientRole; // Role detected from API response

  /// Check if the recipient is a supervisor (from widget or detected from API)
  bool get _isSupervisor {
    final role =
        (_detectedRecipientRole ?? widget.recipientRole)?.toLowerCase();
    return role == 'supervisor' || role == 'mini-visor';
  }

  void _cleanupKnownServerIds() {
    while (_knownServerIds.length > _maxKnownIds) {
      _knownServerIds.remove(_knownServerIds.first);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatEventService.clearActiveChat();
    _pollTimer?.cancel();
    _chatController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();
    _chatController = core.InMemoryChatController();
    _serverConversationId = widget.conversationId;

    // Set this chat as active for notification filtering
    _chatEventService.setActiveChat(
      conversationId: widget.conversationId,
      recipientId: widget.recipientId,
    );

    // Initialize controller with initial message if provided
    if (widget.initialMessage != null) {
      _textController.text = widget.initialMessage!;
    }

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
    });
  }

  /// Initialize the conversation - create/get it, then load messages
  Future<void> _initializeConversation() async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      // If we don't have a conversation ID, create/get one
      if (_serverConversationId == null) {
        final recipientIdInt = int.tryParse(widget.recipientId);
        if (recipientIdInt != null) {
          final conversationData =
              await _chatRepository.createOrGetConversation(
            recipientId: recipientIdInt,
          );

          if (conversationData != null) {
            _serverConversationId = conversationData['id']?.toString();
            // Extract role from other_user data
            final otherUser = conversationData['other_user'];
            if (otherUser != null && otherUser['role'] != null) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _detectedRecipientRole = otherUser['role']?.toString();
                });
              }
              if (kDebugMode) {
                print('Detected recipient role: $_detectedRecipientRole');
              }
            }
            if (kDebugMode) {
              print('Got conversation ID from server: $_serverConversationId');
            }
          }
        }
      }

      // Load messages
      await _loadMessages();

      // Mark as read when opening conversation (per API best practices)
      if (_serverConversationId != null && !_isDisposed) {
        await _chatRepository.markAsRead(
            conversationId: _serverConversationId!);
        // Notify that messages were read so unread count updates
        _chatEventService.notifyMessagesRead(recipientId: widget.recipientId);
      }

      // Set up polling for NEW messages (every 2 seconds, uses after_id)
      if (!_isDisposed) {
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (mounted && !_isDisposed) {
            _pollNewMessages();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing conversation: $e');
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Poll for NEW messages only using after_id (as per API best practices)
  Future<void> _pollNewMessages() async {
    if (_serverConversationId == null || _lastMessageId == 0 || _isDisposed) {
      return;
    }

    try {
      if (kDebugMode) {
        print('Polling new messages after_id: $_lastMessageId');
      }

      final messages = await _chatRepository.getMessagesByConversationId(
        _serverConversationId!,
        afterId: _lastMessageId,
      );

      if (kDebugMode) {
        print('Received ${messages.length} new messages from poll');
      }

      if (mounted && !_isDisposed && messages.isNotEmpty) {
        // Get existing messages
        final existingMessages =
            List<core.Message>.from(_chatController.messages);
        final existingIds = existingMessages.map((m) => m.id).toSet();

        bool hasNewIncoming = false;
        final newMessages = <core.TextMessage>[];

        for (var msg in messages) {
          // Update last message ID
          final msgId = int.tryParse(msg.id) ?? 0;
          if (msgId > _lastMessageId) {
            _lastMessageId = msgId;
          }

          // Skip if we already have this message or it was sent by us
          if (existingIds.contains(msg.id) ||
              _knownServerIds.contains(msg.id)) {
            continue;
          }

          _knownServerIds.add(msg.id);
          _cleanupKnownServerIds();

          // Check if this is an incoming message (not from us)
          final isIncoming = !msg.isMine && msg.senderId != widget.studentId;
          if (isIncoming && !msg.isRead) {
            hasNewIncoming = true;
          }

          newMessages.add(core.TextMessage(
            id: msg.id,
            authorId: msg.isMine ? widget.studentId : msg.senderId,
            createdAt: msg.timestamp,
            text: msg.content,
            status: _getMessageStatus(msg),
          ));
        }

        if (newMessages.isNotEmpty) {
          if (kDebugMode) {
            print('Adding ${newMessages.length} new messages to UI');
          }

          setState(() {
            final allMessages = [...existingMessages, ...newMessages];
            // Sort by message ID first (for server messages - they're sequential)
            // Only use timestamp for temp messages (like 'temp_xxx')
            allMessages.sort((a, b) {
              final aId = int.tryParse(a.id) ?? 0;
              final bId = int.tryParse(b.id) ?? 0;
              // Both have numeric IDs (server messages) - sort by ID
              if (aId > 0 && bId > 0) {
                return aId.compareTo(bId);
              }
              // At least one is a temp message - use timestamp
              return (a.createdAt ?? DateTime(0))
                  .compareTo(b.createdAt ?? DateTime(0));
            });
            _chatController.setMessages(allMessages);
          });

          // Only mark as read if there are new INCOMING unread messages
          if (hasNewIncoming) {
            await _chatRepository.markAsRead(
                conversationId: _serverConversationId!);
            // Notify that messages were read so unread count updates
            _chatEventService.notifyMessagesRead(
                recipientId: widget.recipientId);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error polling messages: $e');
      }
    }
  }

  core.MessageStatus _getMessageStatus(models.ChatMessage msg) {
    // Only show sending indicator while message is pending
    if (msg.isPending) {
      return core.MessageStatus.sending;
    }
    // No status icons for any messages (removed read/sent indicators)
    return core.MessageStatus.delivered;
  }

  Future<void> _loadMessages() async {
    if (_isLoading || _serverConversationId == null || _isDisposed) return;

    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (kDebugMode) {
        print('Loading messages for conversation $_serverConversationId');
      }

      final responseMap = await _chatRepository.getMessagesWithMetadata(
        _serverConversationId!,
        page: _currentPage,
      );

      // Extract role info if available
      if (responseMap['other_user'] != null) {
        final role = responseMap['other_user']['role']?.toString();
        if (role != null && _detectedRecipientRole != role) {
          if (kDebugMode) {
            print('Detected recipient role from messages: $role');
          }
          setState(() {
            _detectedRecipientRole = role;
          });
        }
      }

      final messagesList = responseMap['messages'] as List<dynamic>? ?? [];
      final serverMessages = messagesList
          .map((json) =>
              models.ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        print('Received ${serverMessages.length} server messages');
      }

      // Track message IDs
      for (var msg in serverMessages) {
        _knownServerIds.add(msg.id);
        final msgId = int.tryParse(msg.id) ?? 0;
        if (msgId > _lastMessageId) {
          _lastMessageId = msgId;
        }
      }

      if (serverMessages.isNotEmpty) {
        if (mounted && !_isDisposed) {
          setState(() {
            final coreMessages = serverMessages
                .map((msg) => core.TextMessage(
                      id: msg.id,
                      authorId: msg.isMine ? widget.studentId : msg.senderId,
                      createdAt: msg.timestamp,
                      text: msg.content,
                      status: _getMessageStatus(msg),
                    ))
                .toList();

            // Sort by message ID first (sequential from server), then timestamp for temp messages
            coreMessages.sort((a, b) {
              final aId = int.tryParse(a.id) ?? 0;
              final bId = int.tryParse(b.id) ?? 0;
              // Both have numeric IDs (server messages) - sort by ID
              if (aId > 0 && bId > 0) {
                return aId.compareTo(bId);
              }
              // At least one is a temp message - use timestamp
              return a.createdAt!.compareTo(b.createdAt!);
            });
            _chatController.setMessages(coreMessages);
            _currentPage++;
            _isLoading = false;
          });
        }
      } else {
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading messages: $e');
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }

      if (_chatController.messages.isEmpty && mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الرسائل: $e')),
        );
      }
    }
  }

  void _handleSendPressed(types.PartialText message) {
    if (!mounted || _isDisposed) return;
    final tempId = 'temp_${const Uuid().v4()}';

    // Optimistic update: append temp message to end (no sort needed)
    setState(() {
      final currentMessages = List<core.Message>.from(_chatController.messages);
      currentMessages.add(core.TextMessage(
        id: tempId,
        authorId: widget.studentId,
        createdAt: DateTime.now(),
        text: message.text,
        status: core.MessageStatus.sending,
      ));
      _chatController.setMessages(currentMessages);
    });

    _sendMessageToServer(tempId, message.text);
  }

  Future<void> _sendMessageToServer(String tempId, String messageText) async {
    try {
      final recipientIdInt = int.tryParse(widget.recipientId);
      if (recipientIdInt == null) {
        throw Exception('Invalid recipient ID');
      }

      // Use direct message
      final sentMessage = await _chatRepository.sendDirectMessage(
        recipientId: recipientIdInt,
        senderId: widget.studentId,
        message: messageText,
      );

      if (mounted && !_isDisposed) {
        // Register server ID BEFORE touching UI so the poll can't sneak in a duplicate
        _knownServerIds.add(sentMessage.id);
        _cleanupKnownServerIds();

        // Advance the poll cursor
        final sentMsgId = int.tryParse(sentMessage.id) ?? 0;
        if (sentMsgId > _lastMessageId) {
          _lastMessageId = sentMsgId;
        }

        setState(() {
          final current = List<core.Message>.from(_chatController.messages);

          // If the 2-second poll already added the server message, just drop the temp.
          // Otherwise update the temp message's status in-place (keep same ID → no animation glitch).
          if (current.any((m) => m.id == sentMessage.id)) {
            _chatController.setMessages(
              current.where((m) => m.id != tempId).toList(),
            );
          } else {
            _chatController.setMessages(current.map((msg) {
              if (msg.id == tempId && msg is core.TextMessage) {
                return core.TextMessage(
                  id: msg.id, // keep temp ID — avoids replacement animation
                  authorId: msg.authorId,
                  createdAt: msg.createdAt,
                  text: msg.text,
                  status: core.MessageStatus.sent,
                );
              }
              return msg;
            }).toList());
          }
        });

        if (kDebugMode) {
          print('Message sent successfully: ${sentMessage.id}');
        }

        _chatEventService.notifyMessageSent(
          recipientId: widget.recipientId,
          message: messageText,
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        // Update message status to error
        setState(() {
          final currentMessages =
              List<core.Message>.from(_chatController.messages);
          final updatedMessages = currentMessages.map((msg) {
            if (msg.id == tempId && msg is core.TextMessage) {
              return core.TextMessage(
                id: msg.id,
                authorId: msg.authorId,
                createdAt: msg.createdAt,
                text: msg.text,
                status: core.MessageStatus.error,
              );
            }
            return msg;
          }).toList();
          _chatController.setMessages(updatedMessages);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سيتم إرسال الرسالة عندما تعود للاتصال بالإنترنت'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        if (kDebugMode) {
          print('Failed to send message: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
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
                    color: Color.fromARGB(40, 0, 0, 0),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                              child: _buildAppBarAvatar(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    // Show خدمة العملاء for supervisor
                                    _isSupervisor
                                        ? 'خدمة العملاء'
                                        : widget.recipientName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontFamily: 'Qatar',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_isLoading || _isInitializing)
                                    const Text(
                                      'جاري التحميل...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontFamily: 'Qatar',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppTheme.primaryColor),
                        onPressed: () {
                          setState(() {
                            _currentPage = 1;
                            _lastMessageId = 0;
                            _knownServerIds.clear();
                          });
                          _chatController.setMessages([]);
                          _loadMessages();
                        },
                        tooltip: 'تحديث المحادثة',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _isInitializing
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/chat_bg.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Color(0x0D8B0628),
                        BlendMode.dstATop,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Chat(
                                currentUserId: widget.studentId,
                                resolveUser: (String userId) async {
                                  if (userId == widget.studentId) {
                                    return core.User(
                                      id: widget.studentId,
                                      name: widget.studentName,
                                    );
                                  } else {
                                    return core.User(
                                      id: widget.recipientId,
                                      name: widget.recipientName,
                                    );
                                  }
                                },
                                chatController: _chatController,
                                onMessageSend: (String text) {
                                  _handleSendPressed(
                                      types.PartialText(text: text));
                                },
                                theme: ChatTheme.light().copyWith(
                                  colors: ChatTheme.light().colors.copyWith(
                                        primary: AppTheme.primaryColor,
                                        onPrimary: Colors.white,
                                      ),
                                ),
                                // inputOptions: InputOptions... removed as it's not defined
                                // customBottomWidget: ... removed as it's not defined
                              ),
                            ),
                            // Overlay custom input to hide default one and allow pre-filling
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildMessageInput(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ));
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(
                  fontFamily: 'Qatar',
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  hintStyle: TextStyle(
                    fontFamily: 'Qatar',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    _handleSendPressed(types.PartialText(text: text));
                    _textController.clear();
                  }
                },
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarAvatar() {
    final role =
        (_detectedRecipientRole ?? widget.recipientRole)?.toLowerCase() ?? '';

    if (_isSupervisor) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        child: Transform.scale(
          scale: 1.5,
          child: Lottie.asset(
            'assets/images/customer.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
          ),
        ),
      );
    }

    if (widget.recipientImage != null && widget.recipientImage!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(widget.recipientImage!),
      );
    }

    if (role == 'teacher') {
      return CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(
          GenderHelper.getTeacherImage(widget.recipientGender ?? 'male'),
        ),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primaryColor,
      child: Text(
        widget.recipientName.isNotEmpty
            ? widget.recipientName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: 'Qatar',
        ),
      ),
    );
  }
}
