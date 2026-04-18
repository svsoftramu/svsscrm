import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class ActivityTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> activities;

  const ActivityTimeline({super.key, required this.activities});

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  String _selectedFilter = 'All';

  static const List<String> _filterLabels = [
    'All',
    'Calls',
    'Meetings',
    'Notes',
    'Emails',
    'Invoices',
    'Estimates',
    'Projects',
    'Proposals',
  ];

  static const Map<String, String> _filterToType = {
    'Calls': 'call',
    'Meetings': 'meeting',
    'Notes': 'note',
    'Emails': 'email',
    'Invoices': 'invoice',
    'Estimates': 'estimate',
    'Projects': 'project',
    'Proposals': 'proposal',
  };

  List<Map<String, dynamic>> get _filteredActivities {
    if (_selectedFilter == 'All') return widget.activities;
    final type = _filterToType[_selectedFilter] ?? '';
    return widget.activities
        .where((a) =>
            (a['type'] ?? a['activity_type'] ?? '').toString().toLowerCase() ==
            type)
        .toList();
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return AppColors.success;
      case 'meeting':
        return const Color(0xFF8B5CF6);
      case 'note':
        return AppColors.primary;
      case 'email':
        return AppColors.accent;
      case 'invoice':
        return const Color(0xFFEF4444);
      case 'estimate':
        return const Color(0xFFF59E0B);
      case 'project':
        return const Color(0xFF3B82F6);
      case 'proposal':
        return const Color(0xFF6366F1);
      default:
        return AppColors.textMuted;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return Icons.phone_rounded;
      case 'meeting':
        return Icons.people_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'invoice':
        return Icons.receipt_long_rounded;
      case 'estimate':
        return Icons.request_quote_rounded;
      case 'project':
        return Icons.folder_rounded;
      case 'proposal':
        return Icons.description_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  String _formatTimestamp(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filterLabels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _filterLabels[index];
              final isSelected = _selectedFilter == label;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = label),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Timeline
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.timeline_rounded,
                        size: 40, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No activities found',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedFilter == 'All'
                        ? 'Activities will appear here'
                        : 'No ${_selectedFilter.toLowerCase()} recorded yet',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final activity = filtered[index];
                final type = (activity['type'] ??
                        activity['activity_type'] ??
                        'note')
                    .toString()
                    .toLowerCase();
                final title = (activity['subject'] ??
                        activity['title'] ??
                        activity['name'] ??
                        'Activity')
                    .toString();
                final description = (activity['description'] ??
                        activity['notes'] ??
                        activity['body'] ??
                        '')
                    .toString();
                final timestamp = (activity['created_at'] ??
                        activity['date'] ??
                        activity['timestamp'] ??
                        '')
                    .toString();
                final color = _colorForType(type);
                final icon = _iconForType(type);
                final isLast = index == filtered.length - 1;

                return _TimelineEntry(
                  color: color,
                  icon: icon,
                  title: title,
                  description: description,
                  timestamp: _formatTimestamp(timestamp),
                  typeName: type[0].toUpperCase() + type.substring(1),
                  isLast: isLast,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String description;
  final String timestamp;
  final String typeName;
  final bool isLast;

  const _TimelineEntry({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.typeName,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeName,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
