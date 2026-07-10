import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/translations.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

// Chat message model
class ChatMessageModel {
  final String id;
  final String orderId;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'CLIENT',
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// Chat state management
class ChatState {
  final List<ChatMessageModel> messages;
  final bool isLoading;

  ChatState({required this.messages, this.isLoading = true});

  ChatState copyWith({List<ChatMessageModel>? messages, bool? isLoading}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;
  final SocketService _socket;
  final String orderId;

  ChatNotifier(this._api, this._socket, this.orderId)
      : super(ChatState(messages: [])) {
    _loadMessages();
    _setupSocketListeners();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _api.client.get('/api/order/$orderId/messages');
      if (res.data['success'] == true) {
        final list = res.data['messages'] as List;
        final msgs = list.map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>)).toList();
        state = state.copyWith(messages: msgs, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _setupSocketListeners() {
    _socket.socket.on('new_message', (data) {
      final msg = ChatMessageModel.fromJson(Map<String, dynamic>.from(data as Map));
      if (msg.orderId == orderId) {
        // Prevent duplicate local messages
        if (!state.messages.any((m) => m.id == msg.id)) {
          state = state.copyWith(messages: [...state.messages, msg]);
        }
      }
    });
  }

  void sendMessage(String text, String senderId, String senderRole) {
    _socket.socket.emit('send_message', {
      'orderId': orderId,
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
    });
  }

  @override
  void dispose() {
    _socket.socket.off('new_message');
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, orderId) {
  final api = ref.read(apiServiceProvider);
  final socket = ref.read(socketServiceProvider);
  return ChatNotifier(api, socket, orderId);
});

// CHAT SCREEN UI
class ChatScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ChatScreen({super.key, required this.orderId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _sendCustomMessage(text);
    _messageController.clear();
  }

  void _sendCustomMessage(String text) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final isDriver = ref.read(driverModeProvider);
    final role = isDriver ? 'DRIVER' : 'CLIENT';

    ref.read(chatProvider(widget.orderId).notifier).sendMessage(text, user.id, role);
    
    // Smooth scroll to bottom
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildTemplateChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1C1C2E),
        side: const BorderSide(color: Color(0xFF2A2A3E)),
        label: Text(text, style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 12)),
        onPressed: () => _sendCustomMessage(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.orderId));
    final currentUser = ref.watch(authProvider).user;

    // Smooth scroll to bottom when new messages arrive
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13131F),
        elevation: 0,
        title: Text(context.tr('chat'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator(color: OrbitaColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, idx) {
                      final msg = chatState.messages[idx];
                      final isMe = msg.senderId == currentUser?.id;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
          ),
          
          // Templates chips
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTemplateChip("5 daqiqada boraman"),
                _buildTemplateChip("Men yetib keldim!"),
                _buildTemplateChip("Svetoforda turibman"),
                _buildTemplateChip("Yo'ldaman"),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF13131F),
              border: Border(top: BorderSide(color: Color(0xFF2A2A3E))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulyatsiya: Ovoz yozib olinyapti...'),
                          duration: Duration(milliseconds: 700),
                        ),
                      );
                      Timer(const Duration(milliseconds: 800), () {
                        _sendCustomMessage("[Ovozli xabar: 0:08]");
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1C2E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: OrbitaColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: context.tr('write_message'),
                        hintStyle: const TextStyle(color: OrbitaColors.textHint),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFF1C1C2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: OrbitaColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isVoice = message.text.startsWith('[Ovozli xabar:');
    final duration = isVoice ? message.text.replaceAll('[Ovozli xabar: ', '').replaceAll(']', '') : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? OrbitaColors.primary.withOpacity(0.9)
              : const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: Border.all(
            color: isMe ? Colors.transparent : const Color(0xFF2A2A3E),
          ),
        ),
        child: isVoice
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Icon(Icons.waves, color: Colors.white70, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    duration,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            : Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
      ),
    );
  }
}
