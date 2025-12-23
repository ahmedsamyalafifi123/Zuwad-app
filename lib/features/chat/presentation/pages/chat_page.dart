import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_chat_core/flutter_chat_core.dart' show ChatTheme;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/chat_repository.dart';

class ChatPage extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String studentId;
  final String studentName;

  const ChatPage({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _chatRepository;
  late final core.InMemoryChatController _chatController;
  bool _isLoading = false;
  int _currentPage = 1;
  Timer? _refreshTimer;
  final Set<String> _sentMessageIds = {}; // Track successfully sent messages

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _refreshMessages() async {
    try {
      if (kDebugMode) {
        print('Refreshing messages...');
      }
      final messages = await _chatRepository.getMessages(
        studentId: widget.studentId,
        recipientId: widget.recipientId,
        page: 1, // Always get latest messages
      );

      if (kDebugMode) {
        print('Received ${messages.length} messages during refresh');
      }

      if (mounted && messages.isNotEmpty) {
        // Get existing messages from controller
        final existingMessages =
            List<core.Message>.from(_chatController.messages);
        final existingMessageIds =
            existingMessages.map((msg) => msg.id).toSet();

        // Convert server messages to flutter_chat_core messages
        final serverCoreMessages = messages
            .map((msg) => core.TextMessage(
                  id: msg.id,
                  authorId: msg.senderId,
                  createdAt: msg
                      .timestamp, // Already converted to local time in ChatMessage.fromJson
                  text: msg.content,
                ))
            .toList();

        // Only add new messages that don't exist locally
        final newMessages = serverCoreMessages
            .where((msg) => !existingMessageIds.contains(msg.id))
            .toList();

        if (newMessages.isNotEmpty) {
          if (kDebugMode) {
            print('Adding ${newMessages.length} new messages');
          }
          setState(() {
            // Create a set of server message IDs for tracking sent messages
            final serverMessageIds =
                serverCoreMessages.map((msg) => msg.id).toSet();

            // Update sent message status for local messages that now exist on server
            final updatedMessages = existingMessages.map((msg) {
              if (msg.authorId == widget.studentId &&
                  serverMessageIds.contains(msg.id)) {
                _sentMessageIds.add(msg.id);
                // Update message status to sent
                if (msg is core.TextMessage) {
                  return core.TextMessage(
                    id: msg.id,
                    authorId: msg.authorId,
                    createdAt: msg.createdAt,
                    text: msg.text,
                    status: core.MessageStatus.sent,
                  );
                }
              }
              return msg;
            }).toList();

            // Add new messages
            final allMessages = [...updatedMessages, ...newMessages];

            // Sort by creation time in ascending order (oldest first)
            allMessages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

            // Update controller with messages
            _chatController.setMessages(allMessages);
            if (kDebugMode) {
              print('Updated UI with ${newMessages.length} new messages');
            }
          });
        } else {
          // No new messages, just update status of existing sent messages
          final serverMessageIds =
              serverCoreMessages.map((msg) => msg.id).toSet();
          final existingMessages =
              List<core.Message>.from(_chatController.messages);
          bool hasStatusUpdate = false;

          final updatedMessages = existingMessages.map((msg) {
            if (msg.authorId == widget.studentId &&
                serverMessageIds.contains(msg.id) &&
                !_sentMessageIds.contains(msg.id)) {
              _sentMessageIds.add(msg.id);
              hasStatusUpdate = true;
              if (msg is core.TextMessage) {
                return core.TextMessage(
                  id: msg.id,
                  authorId: msg.authorId,
                  createdAt: msg.createdAt,
                  text: msg.text,
                  status: core.MessageStatus.sent,
                );
              }
            }
            return msg;
          }).toList();

          if (hasStatusUpdate) {
            setState(() {
              _chatController.setMessages(updatedMessages);
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing messages: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository();

    // Initialize InMemoryChatController
    _chatController = core.InMemoryChatController();

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });

    // Set up periodic refresh every 5 seconds (less frequent to reduce flickering)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _refreshMessages();
      }
    });
  }

  Future<void> _loadMessages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print(
          'Loading messages for conversation between ${widget.studentId} and ${widget.recipientId}');

      // Only fetch from server - no local messages
      final serverMessages = await _chatRepository.getMessages(
        studentId: widget.studentId,
        recipientId: widget.recipientId,
        page: _currentPage,
      );

      if (kDebugMode) {
        print('Received ${serverMessages.length} server messages');
        for (var msg in serverMessages) {
          print(
              'Server message: ${msg.id} from ${msg.senderId} content: ${msg.content}');
        }
      }

      // Update UI with server messages
      if (serverMessages.isNotEmpty) {
        if (kDebugMode) {
          print('Setting messages in controller');
        }

        // Update UI with server messages
        setState(() {
          // Convert server messages to flutter_chat_core types
          final coreMessages = serverMessages
              .map((msg) => core.TextMessage(
                    id: msg.id,
                    authorId: msg.senderId,
                    createdAt: msg
                        .timestamp, // Already converted to local time in ChatMessage.fromJson
                    text: msg.content,
                  ))
              .toList();

          // Sort messages in ascending order (oldest first) so flutter_chat_ui displays newest at bottom
          coreMessages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
          _chatController.setMessages(coreMessages);
          _currentPage++;
          _isLoading = false;

          // Messages will automatically show newest at bottom due to chronological order
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading messages: $e');
      }
      setState(() {
        _isLoading = false;
      });

      // Only show error if we have no messages to display
      if (_chatController.messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    // Generate a unique ID for the message
    final messageId = const Uuid().v4();

    // Create message with sending status using flutter_chat_core types
    final textMessage = core.TextMessage(
      id: messageId,
      authorId: widget.studentId,
      createdAt: DateTime.now(), // Use local time for consistency
      text: message.text,
      status: core.MessageStatus.sending, // Show sending status
    );

    // Add the message to the UI immediately (optimistic update)
    final currentMessages = List<core.Message>.from(_chatController.messages);
    currentMessages.add(textMessage);

    // Sort by creation time in ascending order (oldest first)
    currentMessages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    // Update controller with properly sorted messages
    _chatController.setMessages(currentMessages);

    // Send to server in background without blocking UI
    _sendMessageToServer(messageId, message.text);
  }

  Future<void> _sendMessageToServer(
      String messageId, String messageText) async {
    try {
      // Try to send the message
      final sentMessage = await _chatRepository.sendMessage(
        studentId: widget.studentId,
        recipientId: widget.recipientId,
        message: messageText,
      );

      // Message sent successfully - update status to sent with checkmark
      if (mounted) {
        _sentMessageIds.add(sentMessage.id);

        // Update the message status to sent
        final currentMessages =
            List<core.Message>.from(_chatController.messages);
        final updatedMessages = currentMessages.map((msg) {
          if (msg.id == messageId && msg is core.TextMessage) {
            return core.TextMessage(
              id: sentMessage.id, // Use server ID
              authorId: msg.authorId,
              createdAt: msg.createdAt,
              text: msg.text,
              status:
                  core.MessageStatus.sent, // Show sent status with checkmark
            );
          }
          return msg;
        }).toList();

        setState(() {
          _chatController.setMessages(updatedMessages);
        });

        if (kDebugMode) {
          print('Message sent successfully: ${sentMessage.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        // Update message status to error
        final currentMessages =
            List<core.Message>.from(_chatController.messages);
        final updatedMessages = currentMessages.map((msg) {
          if (msg.id == messageId && msg is core.TextMessage) {
            return core.TextMessage(
              id: msg.id,
              authorId: msg.authorId,
              createdAt: msg.createdAt,
              text: msg.text,
              status: core.MessageStatus.error, // Show error status
            );
          }
          return msg;
        }).toList();

        setState(() {
          _chatController.setMessages(updatedMessages);
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('سيتم إرسال الرسالة عندما تعود للاتصال بالإنترنت'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
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
        appBar: AppBar(
          elevation: 1,
          backgroundColor: AppTheme.primaryColor,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFf6c302),
                child: Text(
                  widget.recipientName.isNotEmpty
                      ? widget.recipientName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_isLoading)
                      const Text(
                        'جاري التحميل...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _currentPage = 1;
                });
                _loadMessages();
              },
              tooltip: 'تحديث المحادثة',
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            // WhatsApp-like background pattern
            image: DecorationImage(
              image: const AssetImage('assets/images/chat_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                AppTheme.primaryColor.withOpacity(0.05),
                BlendMode.dstATop,
              ),
            ),
          ),
          child: Column(
            children: [
              Expanded(
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
                    _handleSendPressed(types.PartialText(text: text));
                  },
                  // Removed custom builders to use default flutter_chat_ui behavior
                  // This ensures messages are displayed with newest at bottom
                  theme: ChatTheme.light().copyWith(
                    colors: ChatTheme.light().colors.copyWith(
                          primary: AppTheme.primaryColor,
                          onPrimary: Colors.white,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
