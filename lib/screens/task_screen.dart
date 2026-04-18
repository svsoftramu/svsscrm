import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/status_helpers.dart';
import '../widgets/error_widget.dart';
import '../widgets/empty_state_widget.dart';

void showAddTaskSheet(BuildContext context) {
  _showAddTaskForm(context);
}

void _showAddTaskForm(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _AddTaskPage()),
  );
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  String? _filterStatus;
  String? _filterPriority;
  DateTimeRange? _filterDueRange;
  String _sortField = 'duedate';
  bool _sortAscending = true;

  int get _activeFilterCount => [
    if (_filterStatus != null) 1,
    if (_filterPriority != null) 1,
    if (_filterDueRange != null) 1,
  ].length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchTasks();
    });
  }

  List<Map<String, dynamic>> _filterTasks(List<Map<String, dynamic>> tasks) {
    var filtered = tasks.toList();

    if (_filterStatus != null) {
      filtered = filtered.where((t) => (t['status'] ?? '').toString() == _filterStatus).toList();
    }
    if (_filterPriority != null) {
      filtered = filtered.where((t) => (t['priority'] ?? '').toString().toLowerCase() == _filterPriority!.toLowerCase()).toList();
    }
    if (_filterDueRange != null) {
      filtered = filtered.where((t) {
        final dateStr = (t['duedate'] ?? t['due_date'] ?? '').toString();
        final dt = DateTime.tryParse(dateStr);
        if (dt == null) return false;
        return !dt.isBefore(_filterDueRange!.start) && !dt.isAfter(_filterDueRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    filtered.sort((a, b) {
      dynamic va, vb;
      switch (_sortField) {
        case 'name':
          va = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
          vb = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();
          break;
        case 'priority':
          va = _priorityOrder((a['priority'] ?? '').toString());
          vb = _priorityOrder((b['priority'] ?? '').toString());
          break;
        default:
          va = (a['duedate'] ?? a['due_date'] ?? '').toString();
          vb = (b['duedate'] ?? b['due_date'] ?? '').toString();
      }
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  int _priorityOrder(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent': return 0;
      case 'high': return 1;
      case 'medium': return 2;
      case 'low': return 3;
      default: return 4;
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.6, maxChildSize: 0.85,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter & Sort', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      setState(() { _filterStatus = null; _filterPriority = null; _filterDueRange = null; _sortField = 'duedate'; _sortAscending = true; });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _fChip('All', _filterStatus == null, () { setSheetState(() {}); setState(() => _filterStatus = null); }),
                  _fChip('Not Started', _filterStatus == '1', () { setSheetState(() {}); setState(() => _filterStatus = '1'); }),
                  _fChip('In Progress', _filterStatus == '2', () { setSheetState(() {}); setState(() => _filterStatus = '2'); }),
                  _fChip('Testing', _filterStatus == '3', () { setSheetState(() {}); setState(() => _filterStatus = '3'); }),
                  _fChip('Awaiting', _filterStatus == '4', () { setSheetState(() {}); setState(() => _filterStatus = '4'); }),
                  _fChip('Completed', _filterStatus == '5', () { setSheetState(() {}); setState(() => _filterStatus = '5'); }),
                ],
              ),
              const SizedBox(height: 20),

              // Priority
              const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _fChip('All', _filterPriority == null, () { setSheetState(() {}); setState(() => _filterPriority = null); }),
                  _fChip('Urgent', _filterPriority == 'urgent', () { setSheetState(() {}); setState(() => _filterPriority = 'urgent'); }),
                  _fChip('High', _filterPriority == 'high', () { setSheetState(() {}); setState(() => _filterPriority = 'high'); }),
                  _fChip('Medium', _filterPriority == 'medium', () { setSheetState(() {}); setState(() => _filterPriority = 'medium'); }),
                  _fChip('Low', _filterPriority == 'low', () { setSheetState(() {}); setState(() => _filterPriority = 'low'); }),
                ],
              ),
              const SizedBox(height: 20),

              // Due date range
              const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _filterDueRange,
                  );
                  if (range != null) {
                    setSheetState(() {});
                    setState(() => _filterDueRange = range);
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_filterDueRange != null
                    ? '${DateFormat('dd MMM').format(_filterDueRange!.start)} - ${DateFormat('dd MMM').format(_filterDueRange!.end)}'
                    : 'Select date range'),
              ),
              const SizedBox(height: 20),

              // Sort
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _fChip('Due Date', _sortField == 'duedate', () { setSheetState(() {}); setState(() => _sortField = 'duedate'); }),
                  _fChip('Name', _sortField == 'name', () { setSheetState(() {}); setState(() => _sortField = 'name'); }),
                  _fChip('Priority', _sortField == 'priority', () { setSheetState(() {}); setState(() => _sortField = 'priority'); }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_upward_rounded, size: 14), SizedBox(width: 4), Text('Ascending')]),
                    selected: _sortAscending,
                    onSelected: (_) { setSheetState(() {}); setState(() => _sortAscending = true); },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_downward_rounded, size: 14), SizedBox(width: 4), Text('Descending')]),
                    selected: !_sortAscending,
                    onSelected: (_) { setSheetState(() {}); setState(() => _sortAscending = false); },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        automaticallyImplyLeading: false,
        actions: [
          _ActionButton(icon: Icons.refresh_rounded, onTap: () => context.read<CRMProvider>().fetchTasks()),
          Stack(
            children: [
              _ActionButton(icon: Icons.filter_list_rounded, onTap: _showFilterSheet),
              if (_activeFilterCount > 0)
                Positioned(right: 4, top: 4, child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Center(child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                )),
            ],
          ),
          _ActionButton(icon: Icons.add_rounded, onTap: () => _showAddDialog(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.error != null && provider.tasks.isEmpty) {
            return CrmErrorWidget(message: provider.error!, onRetry: () => provider.fetchTasks());
          }
          if (provider.tasks.isEmpty) {
            return const EmptyStateWidget(icon: Icons.check_circle_outline_rounded, title: 'No tasks yet', subtitle: 'Tap + to create a task');
          }

          final filteredTasks = _filterTasks(provider.tasks);

          if (filteredTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_off_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('No tasks match filters', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => setState(() { _filterStatus = null; _filterPriority = null; _filterDueRange = null; }),
                      child: const Text('Clear Filters')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchTasks(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (_activeFilterCount == 0 && scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 && !provider.isLoading && provider.tasksHasMore) {
                  provider.fetchTasks(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filteredTasks.length + (_activeFilterCount == 0 && provider.tasksHasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= filteredTasks.length) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final task = filteredTasks[index];
                final title = task['name'] ?? task['title'] ?? 'Untitled';
                final status = task['status'] ?? '';
                final priority = task['priority'] ?? '';
                final dueDate = task['duedate'] ?? task['due_date'] ?? '';
                final isComplete = status.toString() == '5' || status.toString().toLowerCase() == 'completed';

                String formattedDate = dueDate.toString();
                try { if (dueDate.toString().isNotEmpty) formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dueDate.toString())); } catch (_) {}

                return Dismissible(
                  key: Key(task['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Task', style: TextStyle(fontWeight: FontWeight.w700)),
                        content: Text('Delete "$title"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => context.read<CRMProvider>().deleteTask(task['id'].toString()),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _showDetailSheet(context, task),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isComplete ? AppColors.cardGreen : _priorityColor(priority.toString()).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isComplete ? AppColors.success : _priorityColor(priority.toString()),
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
                                      fontWeight: FontWeight.w600, fontSize: 15,
                                      color: isComplete ? AppColors.textMuted : AppColors.textPrimary,
                                      decoration: isComplete ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [if (formattedDate.isNotEmpty) formattedDate, if (priority.toString().isNotEmpty) priority.toString()].join('  ·  '),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status.toString()).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_statusLabel(status.toString()),
                                  style: TextStyle(color: _statusColor(status.toString()), fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          );
        },
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': case 'urgent': return AppColors.error;
      case 'medium': return AppColors.accent;
      case 'low': return AppColors.success;
      default: return AppColors.textMuted;
    }
  }

  Color _statusColor(String status) => taskStatusColor(status);

  String _statusLabel(String status) => taskStatusLabel(status);

  void _showDetailSheet(BuildContext context, Map<String, dynamic> task) {
    final title = task['name'] ?? task['title'] ?? 'Untitled';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller, padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(title.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              ...task.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty && e.key != 'id')
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 120, child: Text(_formatKey(e.key), style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    _showAddTaskForm(context);
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, size: 20), onPressed: onTap, splashRadius: 20),
    );
  }
}

class _AddTaskPage extends StatefulWidget {
  const _AddTaskPage();

  @override
  State<_AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<_AddTaskPage> {
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _hourlyRateC = TextEditingController();
  String _priority = 'Medium';
  String _status = '1';
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _billable = false;
  bool _isPublic = false;
  String? _relType;
  String? _relId;
  List<Map<String, dynamic>> _staffList = [];
  final List<String> _assignedStaff = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final response = await ApiService.instance.get('staff');
      final data = response is Map ? response['data'] : response;
      if (data is List) {
        setState(() {
          _staffList = data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _hourlyRateC.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_dueDate ?? DateTime.now().add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _save() {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task name is required'), backgroundColor: AppColors.error),
      );
      return;
    }
    final data = <String, dynamic>{
      'name': _nameC.text.trim(),
      'priority': _priority,
      'status': _status,
      'startdate': (_startDate ?? DateTime.now()).toIso8601String().split('T')[0],
      'duedate': (_dueDate ?? DateTime.now().add(const Duration(days: 1))).toIso8601String().split('T')[0],
    };
    if (_descC.text.trim().isNotEmpty) data['description'] = _descC.text.trim();
    if (_billable) data['billable'] = 1;
    if (_isPublic) data['is_public'] = 1;
    if (_hourlyRateC.text.trim().isNotEmpty) data['hourly_rate'] = _hourlyRateC.text.trim();
    if (_relType != null && _relType!.isNotEmpty) data['rel_type'] = _relType;
    if (_relId != null && _relId!.isNotEmpty) data['rel_id'] = _relId;
    if (_assignedStaff.isNotEmpty) data['assignees'] = _assignedStaff;

    context.read<CRMProvider>().addTask(data);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info
            const Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Task Name *', prefixIcon: Icon(Icons.title_rounded, size: 20))),
            const SizedBox(height: 12),
            TextField(controller: _descC, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true), maxLines: 4),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'High', child: Text('High')),
                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
              ],
              onChanged: (val) => setState(() => _priority = val!),
              decoration: const InputDecoration(labelText: 'Priority', prefixIcon: Icon(Icons.flag_rounded, size: 20)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: '1', child: Text('Not Started')),
                DropdownMenuItem(value: '2', child: Text('In Progress')),
                DropdownMenuItem(value: '3', child: Text('Testing')),
                DropdownMenuItem(value: '4', child: Text('Awaiting Feedback')),
                DropdownMenuItem(value: '5', child: Text('Completed')),
              ],
              onChanged: (val) => setState(() => _status = val!),
              decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline_rounded, size: 20)),
            ),

            // Assign To
            const SizedBox(height: 24),
            const Text('Assign To', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            if (_staffList.isEmpty)
              const Text('Loading staff...', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _staffList.map((s) {
                  final sid = s['staffid']?.toString() ?? '';
                  final name = '${s['firstname'] ?? ''} ${s['lastname'] ?? ''}'.trim();
                  final selected = _assignedStaff.contains(sid);
                  return FilterChip(
                    label: Text(name, style: TextStyle(fontSize: 13, color: selected ? Colors.white : AppColors.textPrimary)),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    onSelected: (val) => setState(() {
                      if (val) { _assignedStaff.add(sid); } else { _assignedStaff.remove(sid); }
                    }),
                  );
                }).toList(),
              ),

            // Dates
            const SizedBox(height: 24),
            const Text('Dates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded, size: 20),
              title: Text(_startDate != null ? dateFormat.format(_startDate!) : 'Select Start Date'),
              subtitle: const Text('Start Date'),
              onTap: () => _pickDate(true),
              trailing: _startDate != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _startDate = null)) : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, size: 20),
              title: Text(_dueDate != null ? dateFormat.format(_dueDate!) : 'Select Due Date'),
              subtitle: const Text('Due Date'),
              onTap: () => _pickDate(false),
              trailing: _dueDate != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _dueDate = null)) : null,
            ),

            // Related To
            const SizedBox(height: 24),
            const Text('Related To', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _relType,
              items: const [
                DropdownMenuItem(value: null, child: Text('None')),
                DropdownMenuItem(value: 'project', child: Text('Project')),
                DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
                DropdownMenuItem(value: 'estimate', child: Text('Estimate')),
                DropdownMenuItem(value: 'contract', child: Text('Contract')),
                DropdownMenuItem(value: 'ticket', child: Text('Ticket')),
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'lead', child: Text('Lead')),
                DropdownMenuItem(value: 'proposal', child: Text('Proposal')),
              ],
              onChanged: (val) => setState(() => _relType = val),
              decoration: const InputDecoration(labelText: 'Related Type', prefixIcon: Icon(Icons.link_rounded, size: 20)),
            ),
            if (_relType != null) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Related ID', prefixIcon: Icon(Icons.tag_rounded, size: 20)),
                keyboardType: TextInputType.number,
                onChanged: (val) => _relId = val,
              ),
            ],

            // Billing
            const SizedBox(height: 24),
            const Text('Billing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Billable'),
              value: _billable,
              onChanged: (val) => setState(() => _billable = val),
            ),
            if (_billable)
              TextField(controller: _hourlyRateC, decoration: const InputDecoration(labelText: 'Hourly Rate', prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20)), keyboardType: TextInputType.number),

            // Visibility
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Public Task'),
              subtitle: const Text('Visible to all staff members'),
              value: _isPublic,
              onChanged: (val) => setState(() => _isPublic = val),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
