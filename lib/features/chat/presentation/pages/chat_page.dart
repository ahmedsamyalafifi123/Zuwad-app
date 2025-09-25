import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_chat_core/flutter_chat_core.dart' show ChatTheme;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

// For input handling
import 'package:flutter/services.dart';

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
  final List<types.Message> _messages = [];
  late final ChatRepository _chatRepository;
  late final core.InMemoryChatController _chatController;
  bool _isLoading = false;
  int _currentPage = 1;
  Timer? _refreshTimer;
  String? _lastMessageId;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _refreshMessages() async {
    try {
      print('Refreshing messages...');
      final messages = await _chatRepository.getMessages(
        studentId: widget.studentId,
        recipientId: widget.recipientId,
        page: 1, // Always get latest messages
      );

      print('Received ${messages.length} messages during refresh');
      for (var msg in messages) {
        print(
            'Refresh message: ${msg.id} from ${msg.senderId} content: ${msg.content}');
      }

      if (mounted && messages.isNotEmpty) {
        // Merge server messages with existing local messages
        setState(() {
          // Get existing messages from controller
          final existingMessages =
              List<core.Message>.from(_chatController.messages);

          // Convert server messages to flutter_chat_core messages
          final serverCoreMessages = messages
              .map((msg) => core.TextMessage(
                    id: msg.id,
                    authorId: msg.senderId,
                    createdAt: msg.timestamp.toUtc(),
                    text: msg.content,
                  ))
              .toList();

          // Create a set of server message IDs for quick lookup
          final serverMessageIds =
              serverCoreMessages.map((msg) => msg.id).toSet();

          // Keep local messages that are not in server response (recently sent)
          final localOnlyMessages = existingMessages
              .where((msg) => !serverMessageIds.contains(msg.id))
              .toList();

          // Combine server messages with local-only messages
          final allMessages = [...serverCoreMessages, ...localOnlyMessages];

          // Sort by creation time in descending order (newest first) for flutter_chat_ui
          allMessages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

          // Update the last message ID
          _lastMessageId = messages.first.id;
          print('Setting last message ID to: $_lastMessageId');

          // Update controller with merged messages
          // flutter_chat_ui expects messages in reverse chronological order (newest first)
          _chatController.setMessages(allMessages);
          print(
              'Updated UI with ${allMessages.length} messages (${serverCoreMessages.length} from server, ${localOnlyMessages.length} local)');

          // Messages will automatically show newest first due to reverse order
        });
      }
    } catch (e) {
      print('Error refreshing messages: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository(
      baseUrl: 'https://system.zuwad-academy.com',
    );

    // Initialize InMemoryChatController
    _chatController = core.InMemoryChatController();

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });

    // Set up periodic refresh every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

      print('Received ${serverMessages.length} server messages');
      for (var msg in serverMessages) {
        print(
            'Server message: ${msg.id} from ${msg.senderId} content: ${msg.content}');
      }

      // Store the last message ID to avoid duplicates during refresh
      if (serverMessages.isNotEmpty) {
        _lastMessageId = serverMessages.first.id;
        print('Setting last message ID to: $_lastMessageId');

        // Update UI with server messages
        setState(() {
          // Convert server messages to flutter_chat_core types
          final coreMessages = serverMessages
              .map((msg) => core.TextMessage(
                    id: msg.id,
                    authorId: msg.senderId,
                    createdAt: msg.timestamp.toUtc(),
                    text: msg.content,
                  ))
              .toList();

          // Server messages are already in DESC order (newest first), which is what flutter_chat_ui expects
          _chatController.setMessages(coreMessages);
          _currentPage++;
          _isLoading = false;

          // Messages will automatically show newest first due to reverse order
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
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
      createdAt: DateTime.now().toUtc(),
      text: message.text,
    );

    // Add the message to the UI immediately (optimistic update)
    // Get current messages, add new message, and sort properly
    final currentMessages = List<core.Message>.from(_chatController.messages);
    currentMessages.add(textMessage);

    // Sort by creation time in descending order (newest first) for flutter_chat_ui
    currentMessages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

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

      // Message sent successfully - no need to update UI as the message is already there
      // The server will return the message in future refreshes with the correct server ID
      print('Message sent successfully: ${sentMessage.id}');
    } catch (e) {
      if (mounted) {
        // Show error message but keep the message in UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('سيتم إرسال الرسالة عندما تعود للاتصال بالإنترنت'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // The message stays in the UI with its original ID
        // It will be handled when connection is restored
        print('Failed to send message: $e');
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
                  widget.recipientName[0].toUpperCase(),
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
                  _messages.clear();
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
                  builders: core.Builders(
                    chatAnimatedListBuilder: (context, itemBuilder) {
                      return ChatAnimatedListReversed(
                        itemBuilder: itemBuilder,
                      );
                    },
                  ),
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
