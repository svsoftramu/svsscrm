import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/status_helpers.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<Map<String, dynamic>> _leaveTypes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadLeaveTypes();
    });
  }

  Future<void> _refresh() async {
    final provider = Provider.of<CRMProvider>(context, listen: false);
    await provider.fetchLeaveBalances();
    await provider.fetchLeaveRequests();
  }

  Future<void> _loadLeaveTypes() async {
    try {
      final response = await ApiService.instance.get('leaves/types');
      final data = response is Map ? response['data'] : response;
      if (data is List) {
        setState(() {
          _leaveTypes = data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
        });
      }
    } catch (_) {}
  }

  double _getBalance(String? typeId) {
    if (typeId == null) return 0;
    final provider = Provider.of<CRMProvider>(context, listen: false);
    final match = provider.leaveBalances.where((b) => b['leave_type_id']?.toString() == typeId);
    if (match.isEmpty) return 0;
    return double.tryParse(match.first['remaining']?.toString() ?? '0') ?? 0;
  }

  int _calcDays(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 0;
    return end.difference(start).inDays + 1;
  }

  Future<void> _showApplyLeaveDialog() async {
    final provider = Provider.of<CRMProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String? selectedLeaveTypeId;
    DateTime? startDate;
    DateTime? endDate;
    String reason = '';

    final startDateController = TextEditingController();
    final endDateController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final balance = _getBalance(selectedLeaveTypeId);
          final daysRequested = _calcDays(startDate, endDate);
          final hasEnoughBalance = selectedLeaveTypeId == null || daysRequested <= balance;

          return AlertDialog(
            title: const Text('Apply Leave'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_rounded, size: 20),
                      ),
                      items: _leaveTypes.map((lt) {
                        final id = lt['id']?.toString() ?? '';
                        final name = lt['name'] ?? lt['short_code'] ?? 'Type $id';
                        final bal = _getBalance(id);
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text(name.toString(), overflow: TextOverflow.ellipsis)),
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bal > 0 ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${bal.toStringAsFixed(0)} left', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bal > 0 ? AppColors.success : AppColors.error)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedLeaveTypeId = v),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    // Show balance info
                    if (selectedLeaveTypeId != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: balance > 0 ? AppColors.success.withValues(alpha: 0.06) : AppColors.error.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(balance > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 16, color: balance > 0 ? AppColors.success : AppColors.error),
                            const SizedBox(width: 8),
                            Text('Available: ${balance.toStringAsFixed(0)} days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: balance > 0 ? AppColors.success : AppColors.error)),
                            if (daysRequested > 0) ...[
                              const Spacer(),
                              Text('Requesting: $daysRequested days', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: startDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                            startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: endDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDate = picked;
                            endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    // Warn if exceeding balance
                    if (daysRequested > 0 && !hasEnoughBalance) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Insufficient balance! You have ${balance.toStringAsFixed(0)} days but requesting $daysRequested days.', style: const TextStyle(fontSize: 12, color: AppColors.error))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (v) => reason = v,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: hasEnoughBalance
                    ? () async {
                        if (formKey.currentState!.validate()) {
                          if (balance <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('No leave balance available for this type'), backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          try {
                            await provider.applyLeave({
                              'leave_type_id': selectedLeaveTypeId,
                              'from_date': DateFormat('yyyy-MM-dd').format(startDate!),
                              'to_date': DateFormat('yyyy-MM-dd').format(endDate!),
                              'reason': reason,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _refresh();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        }
                      }
                    : null,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    startDateController.dispose();
    endDateController.dispose();
  }

  String _getLeaveTypeName(dynamic typeId) {
    final id = typeId?.toString();
    if (id == null) return 'Leave';
    final match = _leaveTypes.where((lt) => lt['id']?.toString() == id);
    if (match.isNotEmpty) return match.first['name']?.toString() ?? 'Leave';
    return 'Leave Type #$id';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyLeaveDialog,
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final balances = provider.leaveBalances;
          final requests = provider.leaveRequests;

          if (balances.isEmpty && requests.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (balances.isEmpty && requests.isEmpty && provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!.replaceFirst('Exception: ', ''), style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (balances.isNotEmpty) ...[
                  Text('Leave Balances', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: balances.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final bal = balances[index];
                        final typeName = bal['leave_type_name'] ?? bal['short_code'] ?? _getLeaveTypeName(bal['leave_type_id']);
                        final shortCode = bal['short_code'] ?? '';
                        final colorHex = bal['color']?.toString();
                        final cardColor = colorHex != null && colorHex.startsWith('#')
                            ? Color(int.parse('FF${colorHex.substring(1)}', radix: 16))
                            : AppColors.primary;

                        return SizedBox(
                          width: 170,
                          child: Card(
                            elevation: 0,
                            color: cardColor.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cardColor.withValues(alpha: 0.3))),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(6)),
                                        child: Text(shortCode.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(typeName.toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cardColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _balanceCol('Total', '${bal['opening_balance'] ?? 0}'),
                                      _balanceCol('Taken', '${bal['taken'] ?? 0}'),
                                      _balanceCol('Left', '${bal['remaining'] ?? 0}', bold: true),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text('Leave Requests', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No leave requests found.')),
                  )
                else
                  ...requests.map((req) {
                    final typeName = req['leave_type_name'] ?? req['leave_type'] ?? _getLeaveTypeName(req['leave_type_id']);
                    final status = req['status']?.toString() ?? '';
                    final fromDate = req['from_date'] ?? req['start_date'] ?? '';
                    final toDate = req['to_date'] ?? req['end_date'] ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(typeName.toString(), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: leaveStatusColor(status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(leaveStatusLabel(status), style: TextStyle(color: leaveStatusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('$fromDate  →  $toDate', style: theme.textTheme.bodyMedium),
                            if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Reason: ${req['reason']}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            ],
                            if (status.toLowerCase() == 'pending') ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await provider.cancelLeave(req['id'].toString());
                                    _refresh();
                                  },
                                  icon: const Icon(Icons.cancel_outlined, size: 18),
                                  label: const Text('Cancel'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceCol(String label, String value, {bool bold = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
