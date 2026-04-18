import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService.instance;

  List<Map<String, dynamic>> _channels = [];
  final Map<String, List<Map<String, dynamic>>> _messages = {};
  int _totalUnread = 0;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get channels => _channels;
  int get totalUnread => _totalUnread;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> getMessages(String channelId) => _messages[channelId] ?? [];

  Future<void> fetchChannels() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _channels = await _chatService.fetchChannels();
      _totalUnread = 0;
      for (final ch in _channels) {
        _totalUnread += (ch['unread_count'] as int?) ?? int.tryParse(ch['unread_count']?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMessages(String channelId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _messages[channelId] = await _chatService.fetchMessages(channelId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String channelId, String text) async {
    final msg = <String, dynamic>{
      'text': text,
      'message': text,
      'sender_id': 'me',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'sending',
      'message_type': 'text',
    };
    _messages.putIfAbsent(channelId, () => []);
    _messages[channelId]!.add(msg);
    notifyListeners();

    try {
      await _chatService.sendMessage(channelId, text);
      msg['status'] = 'sent';
    } catch (e) {
      msg['status'] = 'failed';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> createChannel(List<String> participantIds) async {
    final channel = await _chatService.createChannel(participantIds, type: 'direct');
    await fetchChannels();
    return channel;
  }

  Future<Map<String, dynamic>> createGroupChannel(List<String> participantIds, String name) async {
    final channel = await _chatService.createChannel(participantIds, type: 'group', name: name);
    await fetchChannels();
    return channel;
  }

  Future<void> markAsRead(String channelId) async {
    try {
      await _chatService.markAsRead(channelId);
      // Update local unread count
      for (final ch in _channels) {
        if (ch['id']?.toString() == channelId) {
          ch['unread_count'] = 0;
          break;
        }
      }
      _totalUnread = 0;
      for (final ch in _channels) {
        _totalUnread += (ch['unread_count'] as int?) ?? int.tryParse(ch['unread_count']?.toString() ?? '0') ?? 0;
      }
      notifyListeners();
    } catch (_) {}
  }

  void addNewMessages(String channelId, List<Map<String, dynamic>> newMessages) {
    _messages.putIfAbsent(channelId, () => []);
    final existingIds = _messages[channelId]!.map((m) => m['id']?.toString()).toSet();
    for (final msg in newMessages) {
      if (msg['id'] != null && !existingIds.contains(msg['id']?.toString())) {
        _messages[channelId]!.add(msg);
      }
    }
    notifyListeners();
  }
}
