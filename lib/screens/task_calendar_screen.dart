import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../utils/status_helpers.dart';
import '../widgets/empty_state_widget.dart';

class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key});

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CRMProvider>();
      if (provider.tasks.isEmpty) {
        provider.fetchTasks();
      }
    });
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseDateFromTask(Map<String, dynamic> task) {
    final dateStr =
        (task['duedate'] ?? task['due_date'] ?? '').toString();
    if (dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupTasksByDate(
      List<Map<String, dynamic>> tasks) {
    final Map<DateTime, List<Map<String, dynamic>>> map = {};
    for (final task in tasks) {
      final dt = _parseDateFromTask(task);
      if (dt == null) continue;
      final normalized = _normalizeDate(dt);
      map.putIfAbsent(normalized, () => []);
      map[normalized]!.add(task);
    }
    return map;
  }

  List<Map<String, dynamic>> _getTasksForDay(
      DateTime day, Map<DateTime, List<Map<String, dynamic>>> taskMap) {
    return taskMap[_normalizeDate(day)] ?? [];
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final dt = _parseDateFromTask(task);
    if (dt == null) return false;
    final status = (task['status'] ?? '').toString();
    final isComplete =
        status == '5' || status.toLowerCase() == 'completed';
    return !isComplete && dt.isBefore(DateTime.now());
  }

  bool _isCompleted(Map<String, dynamic> task) {
    final status = (task['status'] ?? '').toString();
    return status == '5' || status.toLowerCase() == 'completed';
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return AppColors.error;
      case 'medium':
        return AppColors.accent;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case '1':
        return 'Not Started';
      case '2':
        return 'In Progress';
      case '3':
        return 'Testing';
      case '4':
        return 'Awaiting';
      case '5':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) => taskStatusColor(status);

  void _showTaskDetailSheet(BuildContext context, Map<String, dynamic> task) {
    final title = task['name'] ?? task['title'] ?? 'Untitled';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
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
              Text(
                title.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              ...task.entries
                  .where((e) =>
                      e.value != null &&
                      e.value.toString().isNotEmpty &&
                      e.key != 'id')
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatKey(e.key),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
            ],
          ),
        );
      },
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Calendar'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => context.read<CRMProvider>().fetchTasks(),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            );
          }

          final taskMap = _groupTasksByDate(provider.tasks);
          final selectedDayTasks = _selectedDay != null
              ? _getTasksForDay(_selectedDay!, taskMap)
              : <Map<String, dynamic>>[];

          return Column(
            children: [
              // Calendar
              Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TableCalendar(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2030),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null &&
                        isSameDay(_selectedDay!, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: (day) =>
                        _getTasksForDay(day, taskMap),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      outsideDaysVisible: false,
                      markersMaxCount: 3,
                      markerDecoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;
                        final tasks =
                            events.cast<Map<String, dynamic>>();
                        return Positioned(
                          bottom: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _buildMarkerDots(tasks),
                          ),
                        );
                      },
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      formatButtonTextStyle: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      titleTextStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      leftChevronIcon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textSecondary,
                      ),
                      rightChevronIcon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    _legendDot(AppColors.error, 'Overdue'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.primary, 'Pending'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.success, 'Completed'),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Selected day header
              if (_selectedDay != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM')
                            .format(_selectedDay!),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (selectedDayTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${selectedDayTasks.length} task${selectedDayTasks.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Task list for selected day
              Expanded(
                child: selectedDayTasks.isEmpty
                    ? const Center(
                        child: EmptyStateWidget(
                          icon: Icons.event_available_rounded,
                          title: 'No tasks for this day',
                          subtitle:
                              'Select a day with colored dots to see tasks',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: selectedDayTasks.length,
                        itemBuilder: (context, index) {
                          final task = selectedDayTasks[index];
                          return _buildTaskTile(task);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMarkerDots(List<Map<String, dynamic>> tasks) {
    final hasOverdue = tasks.any(_isOverdue);
    final hasCompleted = tasks.any(_isCompleted);
    final hasNormal =
        tasks.any((t) => !_isOverdue(t) && !_isCompleted(t));

    final dots = <Widget>[];
    if (hasOverdue) dots.add(_markerDot(AppColors.error));
    if (hasNormal) dots.add(_markerDot(AppColors.primary));
    if (hasCompleted) dots.add(_markerDot(AppColors.success));

    // If no categorization matched, show a default dot
    if (dots.isEmpty) dots.add(_markerDot(AppColors.primary));

    return dots;
  }

  Widget _markerDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final title = (task['name'] ?? task['title'] ?? 'Untitled').toString();
    final priority = (task['priority'] ?? '').toString();
    final status = (task['status'] ?? '').toString();
    final isComplete = _isCompleted(task);
    final overdue = _isOverdue(task);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showTaskDetailSheet(context, task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Priority color dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _priorityColor(priority),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Task info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isComplete
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration:
                            isComplete ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (priority.isNotEmpty)
                          Text(
                            priority,
                            style: TextStyle(
                              fontSize: 12,
                              color: _priorityColor(priority),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (overdue) ...[
                          if (priority.isNotEmpty)
                            const Text(' · ',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12)),
                          const Text(
                            'Overdue',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
