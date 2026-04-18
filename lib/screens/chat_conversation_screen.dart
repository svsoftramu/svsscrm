import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/chat_provider.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatConversationScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final bool isGroup;

  const ChatConversationScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    this.isGroup = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _myUserId;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _myUserId = ApiService.instance.userData?['staffid']?.toString() ??
        ApiService.instance.userData?['id']?.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      provider.fetchMessages(widget.channelId);
      provider.markAsRead(widget.channelId);
    });

    ChatService.instance.startPolling(widget.channelId, (newMessages) {
      if (mounted) {
        context.read<ChatProvider>().addNewMessages(widget.channelId, newMessages);
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ChatService.instance.stopPolling();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _replyingTo = null);
    context.read<ChatProvider>().sendMessage(widget.channelId, text);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 70);
    if (img == null) return;

    // Send image via API
    try {
      await ApiService.instance.uploadFile(
        'crm/chat/channels/${widget.channelId}/messages',
        img.path,
        fields: {'message_type': 'image'},
      );
      if (mounted) {
        context.read<ChatProvider>().fetchMessages(widget.channelId);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: widget.isGroup ? () => _showGroupInfo() : null,
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isGroup
                        ? [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]
                        : [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: widget.isGroup
                      ? const Icon(Icons.group_rounded, color: Colors.white, size: 18)
                      : Text(
                          widget.channelName.isNotEmpty ? widget.channelName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.channelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    if (widget.isGroup)
                      const Text('tap for group info', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.group_rounded, size: 20),
              onPressed: _showGroupInfo,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                final messages = provider.getMessages(widget.channelId);

                if (provider.isLoading && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(24)),
                          child: const Icon(Icons.chat_outlined, size: 48, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text('No messages yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Say hello! 👋', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessage(msg, messages, index);
                  },
                );
              },
            ),
          ),

          // Reply preview
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo!['sender_name']?.toString() ?? 'You',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                        Text(
                          (_replyingTo!['text'] ?? _replyingTo!['message'] ?? '').toString(),
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 24),
                  onPressed: _sendImage,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send button
                Container(
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, List<Map<String, dynamic>> messages, int index) {
    final isMe = msg['sender_id']?.toString() == _myUserId || msg['sender_id'] == 'me';
    final text = (msg['text'] ?? msg['message'] ?? msg['content'] ?? '').toString();
    final time = (msg['created_at'] ?? msg['timestamp'] ?? '').toString();
    final senderName = (msg['sender_name'] ?? '').toString();
    final status = msg['status'];
    final msgType = (msg['message_type'] ?? 'text').toString();
    final fileUrl = msg['file_url']?.toString();

    // Date separator
    Widget? dateSeparator;
    if (index == 0 || _shouldShowDate(messages, index)) {
      final dt = DateTime.tryParse(time);
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final msgDay = DateTime(dt.year, dt.month, dt.day);
        String label;
        if (msgDay == today) {
          label = 'Today';
        } else if (msgDay == today.subtract(const Duration(days: 1))) {
          label = 'Yesterday';
        } else {
          label = DateFormat('dd MMM yyyy').format(dt);
        }

        dateSeparator = Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
            ),
          ),
        );
      }
    }

    // Show sender name for group chats on first message or sender change
    bool showSenderName = widget.isGroup && !isMe;
    if (showSenderName && index > 0) {
      final prevMsg = messages[index - 1];
      if (prevMsg['sender_id']?.toString() == msg['sender_id']?.toString() && !_shouldShowDate(messages, index)) {
        showSenderName = false;
      }
    }

    return Column(
      children: [
        ?dateSeparator,
        GestureDetector(
          onLongPress: () => _showMessageOptions(msg),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              margin: EdgeInsets.only(bottom: 3, top: showSenderName ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name for group
                  if (showSenderName && senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(senderName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _senderColor(senderName))),
                    ),

                  // Image message
                  if (msgType == 'image' && fileUrl != null && fileUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(fileUrl, width: 200, height: 200, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 200, height: 100, color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      ),
                    ),

                  // Text
                  if (text.isNotEmpty)
                    Text(text, style: TextStyle(fontSize: 14.5, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.35)),

                  // Time + status
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(time),
                        style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withValues(alpha: 0.55) : AppColors.textMuted),
                      ),
                      if (isMe && status != null) ...[
                        const SizedBox(width: 3),
                        Icon(
                          status == 'sent' ? Icons.done_rounded
                              : status == 'read' ? Icons.done_all_rounded
                              : status == 'sending' ? Icons.access_time_rounded
                              : Icons.error_outline_rounded,
                          size: 13,
                          color: status == 'read'
                              ? (isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.primary)
                              : (isMe ? Colors.white.withValues(alpha: 0.55) : AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _senderColor(String name) {
    final colors = [
      AppColors.primary, AppColors.success, AppColors.accent,
      const Color(0xFF8B5CF6), const Color(0xFF14B8A6), const Color(0xFFEF4444),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final text = (msg['text'] ?? msg['message'] ?? msg['content'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 8),
            if (text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo() {
    // TODO: Show group members, admin options
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.5, maxChildSize: 0.8,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.group_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(widget.channelName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            const Center(child: Text('Group Chat', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            const SizedBox(height: 24),
            const Text('Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Center(child: Text('Member list will load from server', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDate(List<Map<String, dynamic>> messages, int index) {
    if (index == 0) return true;
    final curr = DateTime.tryParse((messages[index]['created_at'] ?? messages[index]['timestamp'] ?? '').toString());
    final prev = DateTime.tryParse((messages[index - 1]['created_at'] ?? messages[index - 1]['timestamp'] ?? '').toString());
    if (curr == null || prev == null) return false;
    return curr.day != prev.day || curr.month != prev.month || curr.year != prev.year;
  }

  String _formatTime(String time) {
    try {
      final dt = DateTime.tryParse(time);
      if (dt != null) return DateFormat('hh:mm a').format(dt);
    } catch (_) {}
    return time;
  }
}
