import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nguyenanh/features/chatbot/data/models/chat_models.dart';
import 'package:nguyenanh/features/chatbot/data/services/chat_service.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:intl/intl.dart';

class UIMessage {
  final String id;
  final String role;
  String text;
  final String time;
  bool loading;
  String? status;
  List<String> toolSteps;

  UIMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.loading = false,
    this.status,
    List<String>? toolSteps,
  }) : toolSteps = toolSteps ?? [];
}

class ChatbotProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService(ApiClient.dio);

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  bool _isBubbleVisible = true; // Show immediately after login
  bool get isBubbleVisible => _isBubbleVisible;

  List<UIMessage> _messages = [];
  List<UIMessage> get messages => _messages;

  bool _loading = false;
  bool get loading => _loading;

  CancelToken? _cancelToken;
  String _sessionId = 'chatbot-flutter-${DateTime.now().millisecondsSinceEpoch}';

  ChatbotProvider() {
    _messages.add(
      UIMessage(
        id: '0',
        role: 'bot',
        text: 'Xin chào! Tôi là trợ lý AI của hệ thống.\nTôi có thể giúp bạn tra cứu sản lượng, bảo trì, và trạng thái vận hành.',
        time: DateFormat('HH:mm').format(DateTime.now()),
      ),
    );
  }

  void togglePanel() {
    _isOpen = !_isOpen;
    notifyListeners();
  }
  
  void openPanel() {
    _isOpen = true;
    notifyListeners();
  }

  void closePanel() {
    _isOpen = false;
    notifyListeners();
  }

  void toggleBubbleVisibility() {
    _isBubbleVisible = !_isBubbleVisible;
    if (!_isBubbleVisible) {
      _isOpen = false;
    }
    notifyListeners();
  }

  void reset() {
    _cancelToken?.cancel();
    _loading = false;
    final oldSessionId = _sessionId;
    _sessionId = 'chatbot-flutter-${DateTime.now().millisecondsSinceEpoch}';
    _chatService.clearMemory(oldSessionId);
    
    _messages = [
      UIMessage(
        id: '0',
        role: 'bot',
        text: 'Xin chào! Tôi là trợ lý AI của hệ thống.\nTôi có thể giúp bạn tra cứu sản lượng, bảo trì, và trạng thái vận hành.',
        time: DateFormat('HH:mm').format(DateTime.now()),
      )
    ];
    notifyListeners();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    final userMsg = UIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: trimmed,
      time: DateFormat('HH:mm').format(DateTime.now()),
    );
    
    final botId = 'b-${DateTime.now().millisecondsSinceEpoch}';
    final botMsg = UIMessage(
      id: botId,
      role: 'bot',
      text: '',
      time: '',
      loading: true,
    );

    _messages.add(userMsg);
    _messages.add(botMsg);
    _loading = true;
    notifyListeners();

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final apiMessages = _messages
        .where((m) => !m.loading && m.text.trim().isNotEmpty)
        .map((m) => ChatMessage(
              role: m.role == 'bot' ? 'assistant' : 'user',
              content: m.text,
            ))
        .toList();
    
    // Add the user's current message
    apiMessages.add(ChatMessage(role: 'user', content: trimmed));

    String accumulated = '';

    void appendStep(String status) {
      final idx = _messages.indexWhere((m) => m.id == botId);
      if (idx >= 0) {
        final msg = _messages[idx];
        final lastStep = msg.toolSteps.isNotEmpty ? msg.toolSteps.last : null;
        if (lastStep != status) {
          msg.toolSteps.add(status);
        }
        msg.status = status;
        msg.loading = accumulated.isEmpty;
        notifyListeners();
      }
    }

    await _chatService.runWithTools(
      messages: apiMessages,
      sessionId: _sessionId,
      cancelToken: _cancelToken,
      onStatus: (status) => appendStep(status),
      onToolStart: (name, args) => appendStep('Đang gọi $name'),
      onIteration: (n) => appendStep('Vòng xử lý $n'),
      onContent: (chunk) {
        accumulated += chunk;
        final idx = _messages.indexWhere((m) => m.id == botId);
        if (idx >= 0) {
          _messages[idx].text = accumulated;
          _messages[idx].status = null;
          _messages[idx].loading = false;
          notifyListeners();
        }
      },
      onDone: () {
        final idx = _messages.indexWhere((m) => m.id == botId);
        if (idx >= 0) {
          _messages[idx].text = accumulated.isEmpty ? '(Không có phản hồi)' : accumulated;
          _messages[idx].loading = false;
          _messages[idx].status = null;
          // Set real time
          final realTime = DateFormat('HH:mm').format(DateTime.now());
          _messages[idx] = UIMessage(
            id: _messages[idx].id,
            role: _messages[idx].role,
            text: _messages[idx].text,
            time: realTime,
            toolSteps: _messages[idx].toolSteps,
            loading: false,
            status: null,
          );
        }
        _loading = false;
        notifyListeners();
      },
      onError: (err) {
        final idx = _messages.indexWhere((m) => m.id == botId);
        if (idx >= 0) {
          _messages[idx].text = '⚠️ Đã xảy ra lỗi: ${err.toString()}';
          _messages[idx].loading = false;
          _messages[idx].status = null;
          final realTime = DateFormat('HH:mm').format(DateTime.now());
          _messages[idx] = UIMessage(
            id: _messages[idx].id,
            role: _messages[idx].role,
            text: _messages[idx].text,
            time: realTime,
            toolSteps: _messages[idx].toolSteps,
            loading: false,
            status: null,
          );
        }
        _loading = false;
        notifyListeners();
      },
    );
  }
}
