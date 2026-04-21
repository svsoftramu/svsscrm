import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  String _period = 'month';
  DateTimeRange? _customRange;

  final _periodOptions = const {
    'today': 'Today',
    'week': 'This Week',
    'month': 'This Month',
    'year': 'This Year',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String endpoint = 'admin/dashboard?period=$_period';
      if (_period == 'custom' && _customRange != null) {
        final fmt = DateFormat('yyyy-MM-dd');
        endpoint += '&date_from=${fmt.format(_customRange!.start)}'
            '&date_to=${fmt.format(_customRange!.end)}';
      }
      final response = await ApiService.instance.get(endpoint);
      setState(() {
        _data = response is Map<String, dynamic>
            ? (response['data'] is Map<String, dynamic>
                ? response['data']
                : response)
            : {};
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _loading = false);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = 'custom';
      });
      _loadData();
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _formatCurrency(dynamic v) {
    final amount = _toDouble(v);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.adaptive(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(colors)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _buildPeriodFilter(colors),
                      const SizedBox(height: 16),
                      _buildKPICards(colors),
                      const SizedBox(height: 24),
                      _buildRevenueVsExpensesChart(colors),
                      const SizedBox(height: 24),
                      _buildExpenseCategoryPieChart(colors),
                      const SizedBox(height: 24),
                      _buildStaffActivitySection(colors),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(AdaptiveColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(AdaptiveColors colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: colors.textSecondary),
            const SizedBox(width: 10),
            Text('Period:', style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _period,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  items: _periodOptions.entries.map((e) {
                    String label = e.value;
                    if (e.key == 'custom' && _customRange != null) {
                      final fmt = DateFormat('dd MMM');
                      label = '${fmt.format(_customRange!.start)} - ${fmt.format(_customRange!.end)}';
                    }
                    return DropdownMenuItem(value: e.key, child: Text(label, style: const TextStyle(fontSize: 14)));
                  }).toList(),
                  onChanged: (value) {
                    if (value == 'custom') {
                      _pickCustomRange();
                    } else if (value != null) {
                      setState(() => _period = value);
                      _loadData();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards(AdaptiveColors colors) {
    final kpis = [
      _KPI('Total Sales', _formatCurrency(_data['total_sales']), Icons.trending_up_rounded, colors.cardBlue, AppColors.primary),
      _KPI('Payments Received', _formatCurrency(_data['payments_received']), Icons.account_balance_wallet_rounded, colors.cardGreen, AppColors.success),
      _KPI('Payments Pending', _formatCurrency(_data['payments_pending']), Icons.schedule_rounded, colors.cardOrange, AppColors.warning),
      _KPI('Total Expenses', _formatCurrency(_data['total_expenses']), Icons.receipt_long_rounded, colors.cardRed, AppColors.error),
      _KPI('Gross Profit', _formatCurrency(_data['gross_profit']), Icons.bar_chart_rounded, colors.cardPurple, const Color(0xFF8B5CF6)),
      _KPI('Net Profit', _formatCurrency(_data['net_profit']), Icons.emoji_events_rounded, colors.cardTeal, _toDouble(_data['net_profit']) >= 0 ? const Color(0xFF06B6D4) : AppColors.error),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Card(
          color: kpi.bgColor,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kpi.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(kpi.icon, color: kpi.iconColor, size: 18),
                    ),
                    const Spacer(),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.value,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kpi.label,
                      style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevenueVsExpensesChart(AdaptiveColors colors) {
    final revenue = _toDouble(_data['total_sales']);
    final expenses = _toDouble(_data['total_expenses']); // includes salaries
    final profit = _toDouble(_data['net_profit']);
    final maxY = [revenue, expenses, profit.abs()].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue vs Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('Expenses include salaries, employee claims & company expenses', style: TextStyle(fontSize: 11, color: colors.textMuted)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: (revenue == 0 && expenses == 0)
                  ? Center(child: Text('No data for this period', style: TextStyle(color: colors.textMuted)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final labels = ['Revenue', 'Expenses', 'Net Profit'];
                              return BarTooltipItem(
                                '${labels[groupIndex]}\n${_formatCurrency(rod.toY)}',
                                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = ['Revenue', 'Expenses', 'Net Profit'];
                                final idx = value.toInt();
                                if (idx >= 0 && idx < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(labels[idx], style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _makeBarGroup(0, revenue, AppColors.primary),
                          _makeBarGroup(1, expenses, AppColors.error),
                          _makeBarGroup(2, profit >= 0 ? profit : 0, AppColors.success),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppColors.primary, 'Revenue'),
                const SizedBox(width: 16),
                _legendDot(AppColors.error, 'Expenses'),
                const SizedBox(width: 16),
                _legendDot(AppColors.success, 'Net Profit'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.adaptive(context).textSecondary)),
      ],
    );
  }

  Widget _buildExpenseCategoryPieChart(AdaptiveColors colors) {
    final raw = _data['expense_categories'];
    final List<Map<String, dynamic>> categories = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) categories.add(item);
      }
    }

    final pieColors = [
      AppColors.primary,
      AppColors.error,
      AppColors.success,
      AppColors.warning,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF78716C),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('By category', style: TextStyle(fontSize: 12, color: colors.textMuted)),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              SizedBox(
                height: 160,
                child: Center(child: Text('No expense data', style: TextStyle(color: colors.textMuted))),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: List.generate(categories.length, (i) {
                      final cat = categories[i];
                      final amount = _toDouble(cat['amount'] ?? cat['total']);
                      return PieChartSectionData(
                        value: amount,
                        color: pieColors[i % pieColors.length],
                        radius: 50,
                        title: '',
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(categories.length, (i) {
                final cat = categories[i];
                final name = cat['name'] ?? cat['category'] ?? 'Category ${i + 1}';
                final amount = _toDouble(cat['amount'] ?? cat['total']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: pieColors[i % pieColors.length], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name.toString(), style: TextStyle(fontSize: 13, color: colors.textPrimary))),
                      Text(_formatCurrency(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffActivitySection(AdaptiveColors colors) {
    final staff = _data['staff'] ?? _data['staff_stats'] ?? {};
    final leads = _data['leads'] ?? _data['lead_stats'] ?? {};
    final tasks = _data['tasks'] ?? _data['task_stats'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Staff & Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('Team performance overview', style: TextStyle(fontSize: 12, color: colors.textMuted)),
            const SizedBox(height: 16),

            // Staff
            _statRow(Icons.people_rounded, AppColors.primary, 'Total Staff', _toInt(staff is Map ? (staff['active_count'] ?? staff['total'] ?? staff['count']) : staff).toString(), colors),
            const Divider(height: 24),

            // Leads
            _statRow(Icons.leaderboard_rounded, const Color(0xFF8B5CF6), 'Total Leads', _toInt(leads is Map ? (leads['total'] ?? leads['count']) : leads).toString(), colors),
            if (leads is Map) ...[
              if (leads['new'] != null)
                _statRow(Icons.fiber_new_rounded, AppColors.success, 'New Leads', _toInt(leads['new']).toString(), colors),
              if (leads['converted'] != null)
                _statRow(Icons.check_circle_rounded, AppColors.primary, 'Converted', _toInt(leads['converted']).toString(), colors),
              if (leads['lost'] != null)
                _statRow(Icons.cancel_rounded, AppColors.error, 'Lost', _toInt(leads['lost']).toString(), colors),
            ],
            const Divider(height: 24),

            // Tasks
            _statRow(Icons.task_alt_rounded, AppColors.accent, 'Total Tasks', _toInt(tasks is Map ? (tasks['total'] ?? tasks['count']) : tasks).toString(), colors),
            if (tasks is Map) ...[
              if (tasks['completed'] != null)
                _statRow(Icons.done_all_rounded, AppColors.success, 'Completed', _toInt(tasks['completed']).toString(), colors),
              if (tasks['in_progress'] != null)
                _statRow(Icons.autorenew_rounded, AppColors.warning, 'In Progress', _toInt(tasks['in_progress']).toString(), colors),
              if (tasks['overdue'] != null)
                _statRow(Icons.warning_amber_rounded, AppColors.error, 'Overdue', _toInt(tasks['overdue']).toString(), colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, Color color, String label, String value, AdaptiveColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
          ),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _KPI {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _KPI(this.label, this.value, this.icon, this.bgColor, this.iconColor);
}
