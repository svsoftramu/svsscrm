import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CRMProvider>();
      provider.fetchNotifications();
      provider.fetchUnreadCount();
    });
  }

  /// Group notifications by date label: Today, Yesterday, Earlier
  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final n in notifications) {
      final raw = n['date'] ?? n['created_at'] ?? n['timestamp'] ?? '';
      DateTime? dt;
      if (raw is String && raw.isNotEmpty) {
        dt = DateTime.tryParse(raw);
      }

      String label;
      if (dt != null) {
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        if (dateOnly == today) {
          label = 'Today';
        } else if (dateOnly == yesterday) {
          label = 'Yesterday';
        } else {
          label = 'Earlier';
        }
      } else {
        label = 'Earlier';
      }

      groups.putIfAbsent(label, () => []);
      groups[label]!.add(n);
    }

    return groups;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task':
        return Icons.task_alt_rounded;
      case 'lead':
        return Icons.person_search_rounded;
      case 'leave':
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _iconColorForType(String type) {
    switch (type) {
      case 'task':
        return AppColors.primary;
      case 'lead':
        return AppColors.success;
      case 'leave':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  Color _iconBgForType(String type) {
    switch (type) {
      case 'task':
        return AppColors.cardBlue;
      case 'lead':
        return AppColors.cardGreen;
      case 'leave':
        return AppColors.cardOrange;
      default:
        return AppColors.surfaceVariant;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<CRMProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        '${provider.unreadCount} unread',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      tooltip: 'Mark all as read',
                      onPressed: () => provider.markAllNotificationsRead(),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.notifications_none_rounded,
                        size: 40, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const Text('No notifications',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text("You're all caught up!",
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          final grouped = _groupByDate(provider.notifications);
          // Ordered keys: Today first, then Yesterday, then Earlier
          final orderedKeys = <String>[];
          for (final k in ['Today', 'Yesterday', 'Earlier']) {
            if (grouped.containsKey(k)) orderedKeys.add(k);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchNotifications();
              await provider.fetchUnreadCount();
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: orderedKeys.fold<int>(
                  0, (sum, k) => sum + 1 + grouped[k]!.length),
              itemBuilder: (context, index) {
                // Walk through groups to determine what to render
                int cursor = 0;
                for (final key in orderedKeys) {
                  final items = grouped[key]!;
                  if (index == cursor) {
                    // Section header
                    return Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }
                  cursor++; // skip header
                  if (index < cursor + items.length) {
                    final n = items[index - cursor];
                    return _buildNotificationCard(n, provider);
                  }
                  cursor += items.length;
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> n, CRMProvider provider) {
    final title = n['title'] ?? n['subject'] ?? 'Notification';
    final body = n['description'] ?? n['message'] ?? n['body'] ?? '';
    final dateStr = n['date'] ?? n['created_at'] ?? n['timestamp'] ?? '';
    final isRead =
        n['is_read'] == true || n['is_read'] == 1 || n['read'] == true;
    final type = (n['type'] ?? n['notification_type'] ?? 'general').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? null : AppColors.cardBlue,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isRead && n['id'] != null) {
            provider.markNotificationRead(n['id'].toString());
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.surfaceVariant
                      : _iconBgForType(type),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForType(type),
                  color: isRead ? AppColors.textMuted : _iconColorForType(type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.w500 : FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (body.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    if (dateStr.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(dateStr.toString()),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
