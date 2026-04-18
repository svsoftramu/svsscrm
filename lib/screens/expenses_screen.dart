import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _travelRequests = [];
  List<Map<String, dynamic>> _expenseClaims = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.get('travel/requests'),
        ApiService.instance.get('travel/claims'),
        ApiService.instance.get('travel/expense-categories'),
      ]);
      setState(() {
        _travelRequests = _extractList(results[0]);
        _expenseClaims = _extractList(results[1]);
        _expenseCategories = _extractList(results[2]);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    return [];
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved': case 'reimbursed': return AppColors.success;
      case 'submitted': case 'pending': return AppColors.warning;
      case 'rejected': return AppColors.error;
      case 'draft': return AppColors.textMuted;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }

  // ─── New Travel Request ───
  Future<void> _showNewTravelDialog() async {
    final formKey = GlobalKey<FormState>();
    String purpose = '', destination = '', mode = 'car';
    DateTime? departure;
    String estimatedCost = '';

    final depC = TextEditingController();
    final retC = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('New Travel Request'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Purpose *', border: OutlineInputBorder()),
                    onChanged: (v) => purpose = v,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Destination *', border: OutlineInputBorder()),
                    onChanged: (v) => destination = v,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: 'Travel Mode', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'car', child: Text('Car')),
                      DropdownMenuItem(value: 'bus', child: Text('Bus')),
                      DropdownMenuItem(value: 'train', child: Text('Train')),
                      DropdownMenuItem(value: 'flight', child: Text('Flight')),
                      DropdownMenuItem(value: 'bike', child: Text('Bike')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => mode = v ?? 'car',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: depC, readOnly: true,
                    decoration: const InputDecoration(labelText: 'Departure Date *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      final p = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (p != null) ss(() { departure = p; depC.text = DateFormat('yyyy-MM-dd').format(p); });
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: retC, readOnly: true,
                    decoration: const InputDecoration(labelText: 'Return Date *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      final p = await showDatePicker(context: ctx, initialDate: departure ?? DateTime.now(), firstDate: departure ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (p != null) ss(() { retC.text = DateFormat('yyyy-MM-dd').format(p); });
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Estimated Cost (₹)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => estimatedCost = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await ApiService.instance.post('travel/submit', {
                    'purpose': purpose, 'destination': destination, 'travel_mode': mode,
                    'departure_date': depC.text, 'return_date': retC.text,
                    'estimated_cost': estimatedCost,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    depC.dispose(); retC.dispose();
  }

  // ─── New Expense Claim ───
  Future<void> _showNewClaimDialog() async {
    final formKey = GlobalKey<FormState>();
    String title = '', notes = '';
    String? travelId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Expense Claim'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder(), hintText: 'e.g., Client Visit - Hyderabad'),
                  onChanged: (v) => title = v,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                if (_travelRequests.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Link to Travel Request (Optional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._travelRequests.map((t) => DropdownMenuItem(value: t['id']?.toString(), child: Text('${t['destination']} - ${t['purpose']}'))),
                    ],
                    onChanged: (v) => travelId = v,
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                  onChanged: (v) => notes = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await ApiService.instance.post('travel/claims/new', {
                  'title': title, 'notes': notes,
                  'travel_request_id': ?travelId,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ─── Add Item to Claim ───
  Future<void> _showAddItemDialog(String claimId) async {
    final formKey = GlobalKey<FormState>();
    String description = '', amount = '', notes = '';
    String? categoryId;
    DateTime expenseDate = DateTime.now();
    final dateC = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Expense Item'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                    items: _expenseCategories.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text(c['name']?.toString() ?? ''))).toList(),
                    onChanged: (v) => categoryId = v,
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                    onChanged: (v) => description = v,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => amount = v,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: dateC, readOnly: true,
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      final p = await showDatePicker(context: ctx, initialDate: expenseDate, firstDate: DateTime.now().subtract(const Duration(days: 90)), lastDate: DateTime.now());
                      if (p != null) ss(() { expenseDate = p; dateC.text = DateFormat('yyyy-MM-dd').format(p); });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                    onChanged: (v) => notes = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await ApiService.instance.post('travel/claims/$claimId/add-item', {
                    'category_id': categoryId, 'description': description,
                    'amount': amount, 'expense_date': dateC.text, 'notes': notes,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    dateC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel & Expenses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.flight_takeoff_rounded, size: 18), text: 'Travel'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Claims'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showNewTravelDialog();
          } else {
            _showNewClaimDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'New Travel' : 'New Claim'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTravelTab(),
                _buildClaimsTab(),
              ],
            ),
    );
  }

  Widget _buildTravelTab() {
    if (_travelRequests.isEmpty) {
      return const EmptyStateWidget(icon: Icons.flight_takeoff_rounded, title: 'No travel requests', subtitle: 'Submit a travel request to get started');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _travelRequests.length,
        itemBuilder: (ctx, i) {
          final t = _travelRequests[i];
          final status = t['status']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['destination']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(t['purpose']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${t['departure_date'] ?? ''} → ${t['return_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      if (t['estimated_cost'] != null && t['estimated_cost'].toString() != '0')
                        Text('₹${t['estimated_cost']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClaimsTab() {
    if (_expenseClaims.isEmpty) {
      return const EmptyStateWidget(icon: Icons.receipt_long_rounded, title: 'No expense claims', subtitle: 'Create an expense claim to track TA/DA');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _expenseClaims.length,
        itemBuilder: (ctx, i) {
          final c = _expenseClaims[i];
          final status = c['status']?.toString() ?? '';
          final items = c['items'] is List ? (c['items'] as List) : [];
          final total = double.tryParse(c['total_amount']?.toString() ?? '0') ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['title']?.toString() ?? c['claim_number']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(c['claim_number']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final m = item is Map<String, dynamic> ? item : <String, dynamic>{};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${m['category_name'] ?? m['description'] ?? ''}', style: const TextStyle(fontSize: 13))),
                            Text('₹${m['amount'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (status == 'draft') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddItemDialog(c['id'].toString()),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await ApiService.instance.post('travel/claims/${c['id']}/submit', {});
                              _loadData();
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Submit', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
