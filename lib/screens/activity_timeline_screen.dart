import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';

class ActivityTimelineScreen extends StatefulWidget {
  final String entityType; // 'lead' or 'customer'
  final String entityId;
  final String entityName;

  const ActivityTimelineScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
  });

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<CRMProvider>();
      List<Map<String, dynamic>> result;

      if (widget.entityType == 'lead') {
        result = await provider.fetchLeadActivities(widget.entityId);
      } else {
        result = await provider.fetchCustomerActivities(widget.entityId);
      }

      if (mounted) {
        setState(() {
          _activities = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showLogActivitySheet() {
    final formKey = GlobalKey<FormState>();
    String activityType = 'call';
    final subjectController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Log Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For ${widget.entityName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Activity type dropdown
                DropdownButtonFormField<String>(
                  initialValue: activityType,
                  items: const [
                    DropdownMenuItem(value: 'call', child: Text('Phone Call')),
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                    DropdownMenuItem(value: 'note', child: Text('Note')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => activityType = val);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Activity Type',
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                // Subject
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    prefixIcon: Icon(Icons.subject_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Subject is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Notes
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final data = {
                        'type': activityType,
                        'subject': subjectController.text.trim(),
                        'description': notesController.text.trim(),
                      };

                      try {
                        await context
                            .read<CRMProvider>()
                            .logActivity(widget.entityId, data);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchActivities();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Activity logged successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Failed to log activity: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Log Activity',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.entityName} Activities'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _fetchActivities,
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogActivitySheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Log Activity',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (_error != null && _activities.isEmpty) {
      return CrmErrorWidget(
        message: _error!,
        onRetry: _fetchActivities,
      );
    }

    if (_activities.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.timeline_rounded,
        title: 'No activities yet',
        subtitle: 'Tap the button below to log the first activity',
      );
    }

    return ActivityTimeline(activities: _activities);
  }
}
