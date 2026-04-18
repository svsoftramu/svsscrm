import 'dart:async';
import 'api_service.dart';

class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  Timer? _pollTimer;

  Future<List<Map<String, dynamic>>> fetchChannels() async {
    final response = await ApiService.instance.get('crm/chat/channels');
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    if (response is List) return response.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String channelId, {String? sinceTimestamp}) async {
    final query = sinceTimestamp != null ? '?since=$sinceTimestamp' : '';
    final response = await ApiService.instance.get('crm/chat/channels/$channelId/messages$query');
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    if (response is List) return response.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    return [];
  }

  Future<void> sendMessage(String channelId, String text) async {
    await ApiService.instance.post('crm/chat/channels/$channelId/messages', {'text': text});
  }

  Future<Map<String, dynamic>> createChannel(List<String> participantIds, {String type = 'direct', String? name}) async {
    final body = <String, dynamic>{
      'participants': participantIds,
      'type': type,
    };
    if (name != null) body['name'] = name;
    final response = await ApiService.instance.post('crm/chat/channels', body);
    if (response is Map<String, dynamic>) {
      return response['data'] is Map<String, dynamic> ? response['data'] : response;
    }
    return {};
  }

  Future<void> markAsRead(String channelId) async {
    try {
      await ApiService.instance.post('crm/chat/channels/$channelId/read', {});
    } catch (_) {}
  }

  void startPolling(String channelId, Function(List<Map<String, dynamic>>) onNewMessages) {
    stopPolling();
    String? lastTimestamp;

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final messages = await fetchMessages(channelId, sinceTimestamp: lastTimestamp);
        if (messages.isNotEmpty) {
          lastTimestamp = messages.last['created_at']?.toString() ?? messages.last['timestamp']?.toString();
          onNewMessages(messages);
        }
      } catch (_) {}
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stopPolling();
  }
}
