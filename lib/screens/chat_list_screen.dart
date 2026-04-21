import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchChannels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterChannels(List<Map<String, dynamic>> channels, String type) {
    var filtered = channels.where((ch) {
      if (type == 'direct') return (ch['type'] ?? 'direct') == 'direct';
      if (type == 'group') return (ch['type'] ?? '') == 'group';
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((ch) {
        final name = (ch['name'] ?? ch['participant_name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                style: const TextStyle(fontSize: 15),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Team Chat'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 20),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => context.read<ChatProvider>().fetchChannels(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Direct'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showNewChatSheet(context),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.channels.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildChannelList(provider, 'all'),
              _buildChannelList(provider, 'direct'),
              _buildChannelList(provider, 'group'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChannelList(ChatProvider provider, String type) {
    final channels = _filterChannels(provider.channels, type);

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
              child: Icon(
                type == 'group' ? Icons.group_rounded : Icons.chat_bubble_outline_rounded,
                size: 40, color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results found' : 'No ${type == 'all' ? '' : type} conversations yet',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('Start a new chat with your team', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchChannels(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: channels.length,
        itemBuilder: (context, index) => _buildChannelTile(channels[index]),
      ),
    );
  }

  Widget _buildChannelTile(Map<String, dynamic> channel) {
    final name = (channel['name'] ?? channel['participant_name'] ?? 'Chat').toString();
    final lastMsg = (channel['last_message'] ?? channel['last_message_text'] ?? '').toString();
    final time = (channel['updated_at'] ?? channel['last_message_time'] ?? '').toString();
    final unread = (channel['unread_count'] as int?) ?? 0;
    final isGroup = (channel['type'] ?? '') == 'group';
    final memberCount = channel['member_count'] ?? 0;
    final isOnline = channel['is_online'] == true || channel['is_online'] == 1;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          channelId: channel['id'].toString(),
          channelName: name,
          isGroup: isGroup,
        ),
      )),
      onLongPress: () => _showChannelOptions(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGroup
                          ? [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]
                          : [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: isGroup
                        ? const Icon(Icons.group_rounded, color: Colors.white, size: 24)
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
                if (!isGroup && isOnline)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          _formatTime(time),
                          style: TextStyle(fontSize: 11, color: unread > 0 ? AppColors.primary : AppColors.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isGroup) ...[
                        Icon(Icons.group_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('$memberCount ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                      Expanded(
                        child: Text(
                          lastMsg.isNotEmpty ? lastMsg : 'No messages yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0 ? AppColors.textPrimary : AppColors.textMuted,
                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelOptions(Map<String, dynamic> channel) {
    final isGroup = (channel['type'] ?? '') == 'group';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.push_pin_rounded, color: AppColors.primary),
              title: const Text('Pin Conversation'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_rounded, color: AppColors.textSecondary),
              title: const Text('Mute Notifications'),
              onTap: () => Navigator.pop(ctx),
            ),
            if (isGroup)
              ListTile(
                leading: const Icon(Icons.group_add_rounded, color: AppColors.success),
                title: const Text('Add Members'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddMembersSheet(channel);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(isGroup ? 'Leave Group' : 'Delete Conversation', style: const TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.9,
        builder: (_, controller) => _NewChatSheet(
          scrollController: controller,
          onChatCreated: (channelId, name, isGroup) {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatConversationScreen(channelId: channelId, channelName: name, isGroup: isGroup),
            ));
          },
        ),
      ),
    );
  }

  void _showAddMembersSheet(Map<String, dynamic> channel) {
    // TODO: Implement add members to group
  }

  String _formatTime(String time) {
    try {
      final dt = DateTime.tryParse(time);
      if (dt == null) return time;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return DateFormat('EEE').format(dt);
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return time;
    }
  }
}

// ═══════════════════════════════════════════════
// NEW CHAT SHEET — Direct + Group Creation
// ═══════════════════════════════════════════════

class _NewChatSheet extends StatefulWidget {
  final ScrollController scrollController;
  final Function(String channelId, String name, bool isGroup) onChatCreated;

  const _NewChatSheet({required this.scrollController, required this.onChatCreated});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  bool _isGroupMode = false;
  final _groupNameC = TextEditingController();
  final _searchC = TextEditingController();
  String _search = '';
  final Set<String> _selectedIds = {};
  final Map<String, String> _selectedNames = {};
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchDirectory();
    });
  }

  @override
  void dispose() {
    _groupNameC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isGroupMode ? 'New Group' : 'New Chat',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _isGroupMode = !_isGroupMode;
                      if (!_isGroupMode) {
                        _selectedIds.clear();
                        _selectedNames.clear();
                      }
                    }),
                    icon: Icon(_isGroupMode ? Icons.person_rounded : Icons.group_rounded, size: 18),
                    label: Text(_isGroupMode ? 'Direct Chat' : 'Create Group'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Group name input
              if (_isGroupMode) ...[
                TextField(
                  controller: _groupNameC,
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    prefixIcon: const Icon(Icons.group_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Selected members chips
              if (_isGroupMode && _selectedIds.isNotEmpty) ...[
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _selectedNames.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(e.value, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(() {
                          _selectedIds.remove(e.key);
                          _selectedNames.remove(e.key);
                        }),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Search
              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  hintText: 'Search team members...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: Consumer<CRMProvider>(
            builder: (context, provider, _) {
              // Exclude current user from the list — can't chat with yourself
              final currentUserId = (ApiService.instance.userData?['staffid'] ?? ApiService.instance.userData?['id'] ?? '').toString();
              var members = provider.directory.where((m) {
                final id = (m['staffid'] ?? m['id'] ?? '').toString();
                return id != currentUserId;
              }).toList();

              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                members = members.where((m) {
                  final name = '${m['firstname'] ?? ''} ${m['lastname'] ?? ''}'.toLowerCase();
                  return name.contains(q);
                }).toList();
              }

              if (provider.directory.isEmpty) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              if (members.isEmpty) {
                return Center(
                  child: Text(
                    _search.isNotEmpty ? 'No results found' : 'No other team members found',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index];
                  final id = (m['staffid'] ?? m['id'] ?? '').toString();
                  final name = '${m['firstname'] ?? ''} ${m['lastname'] ?? ''}'.trim();
                  final role = (m['role_name'] ?? m['designation'] ?? '').toString();
                  final isSelected = _selectedIds.contains(id);

                  return ListTile(
                    leading: Stack(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          )),
                        ),
                        if (_isGroupMode && isSelected)
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.check, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: role.isNotEmpty ? Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)) : null,
                    trailing: _isGroupMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleMember(id, name),
                            activeColor: AppColors.primary,
                          )
                        : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                    onTap: () {
                      if (_isGroupMode) {
                        _toggleMember(id, name);
                      } else {
                        _createDirectChat(id, name);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),

        // Create group button
        if (_isGroupMode && _selectedIds.isNotEmpty)
          Container(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createGroup,
                icon: _creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.group_add_rounded, size: 20),
                label: Text('Create Group (${_selectedIds.length} members)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _toggleMember(String id, String name) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedNames.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedNames[id] = name;
      }
    });
  }

  Future<void> _createDirectChat(String staffId, String name) async {
    setState(() => _creating = true);
    try {
      final channel = await context.read<ChatProvider>().createChannel([staffId]);
      widget.onChatCreated(channel['id']?.toString() ?? '', name, false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final channel = await context.read<ChatProvider>().createGroupChannel(
        _selectedIds.toList(),
        _groupNameC.text.trim(),
      );
      widget.onChatCreated(channel['id']?.toString() ?? '', _groupNameC.text.trim(), true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
