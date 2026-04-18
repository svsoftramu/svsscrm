import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/error_widget.dart';
import '../widgets/empty_state_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showExportSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onSelected: (_) => _showExportSnackbar(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Export PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_rounded,
                          size: 18, color: AppColors.success),
                      SizedBox(width: 10),
                      Text('Export CSV'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Lead Sources'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SalesTab(),
          _LeadSourcesTab(),
          _TeamTab(),
        ],
      ),
    );
  }
}

// ============================================================
// SALES TAB
// ============================================================
class _SalesTab extends StatefulWidget {
  const _SalesTab();

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await context.read<CRMProvider>().fetchSalesReport(
            month: _selectedMonth.toString(),
            year: _selectedYear.toString(),
          );
      if (mounted) {
        setState(() {
          _reportData = data;
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

  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              const Text(
                'Select Period',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              // Year row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () =>
                        setSheetState(() => _selectedYear--),
                  ),
                  Text(
                    '$_selectedYear',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () =>
                        setSheetState(() => _selectedYear++),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Month grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final isSelected = month == _selectedMonth;
                  return GestureDetector(
                    onTap: () {
                      setSheetState(() => _selectedMonth = month);
                    },
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM')
                              .format(DateTime(2024, month)),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {});
                    _fetchReport();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null && _reportData == null) {
      return CrmErrorWidget(
          message: _error!, onRetry: _fetchReport);
    }

    final data = _reportData ?? {};
    final totalRevenue =
        _parseDouble(data['total_revenue'] ?? data['revenue'] ?? 0);
    final paidAmount =
        _parseDouble(data['paid'] ?? data['paid_amount'] ?? 0);
    final unpaidAmount =
        _parseDouble(data['unpaid'] ?? data['unpaid_amount'] ?? 0);
    final currencyFormat = NumberFormat.currency(
        symbol: '\u20B9', decimalDigits: 0, locale: 'en_IN');

    // Monthly revenue data for bar chart
    final monthlyData = data['monthly'] ?? data['monthly_revenue'];
    final List<Map<String, dynamic>> monthlyList =
        monthlyData is List
            ? monthlyData
                .map((e) =>
                    e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList()
            : [];

    return RefreshIndicator(
      onRefresh: _fetchReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month/Year picker
            GestureDetector(
              onTap: _showMonthYearPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth))} $_selectedYear',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Revenue summary cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Revenue',
                    value: currencyFormat.format(totalRevenue),
                    color: AppColors.primary,
                    bgColor: AppColors.cardBlue,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Paid',
                    value: currencyFormat.format(paidAmount),
                    color: AppColors.success,
                    bgColor: AppColors.cardGreen,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    label: 'Unpaid',
                    value: currencyFormat.format(unpaidAmount),
                    color: AppColors.error,
                    bgColor: AppColors.cardRed,
                    icon: Icons.pending_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bar chart (if monthly data available)
            if (monthlyList.isNotEmpty) ...[
              const Text(
                'Monthly Revenue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _getMaxRevenue(monthlyList) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem:
                                (group, gIndex, rod, rIndex) {
                              return BarTooltipItem(
                                currencyFormat.format(rod.toY),
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
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
                                final idx = value.toInt();
                                if (idx >= 0 &&
                                    idx < monthlyList.length) {
                                  final label =
                                      (monthlyList[idx]['month'] ??
                                              monthlyList[idx]
                                                  ['label'] ??
                                              '')
                                          .toString();
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8),
                                    child: Text(
                                      label.length > 3
                                          ? label.substring(0, 3)
                                          : label,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color:
                                            AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(
                          monthlyList.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: _parseDouble(
                                    monthlyList[i]['amount'] ??
                                        monthlyList[i]['revenue'] ??
                                        0),
                                color: AppColors.primary,
                                width: 16,
                                borderRadius:
                                    const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Key metrics
            const Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricRow('Total Invoices',
                '${data['total_invoices'] ?? data['invoices_count'] ?? '-'}'),
            _buildMetricRow('Total Estimates',
                '${data['total_estimates'] ?? data['estimates_count'] ?? '-'}'),
            _buildMetricRow('New Customers',
                '${data['new_customers'] ?? data['customers_count'] ?? '-'}'),
            _buildMetricRow('Converted Leads',
                '${data['converted_leads'] ?? data['conversions'] ?? '-'}'),
            _buildMetricRow('Average Deal Size',
                data['avg_deal_size'] != null
                    ? currencyFormat
                        .format(_parseDouble(data['avg_deal_size']))
                    : '-'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getMaxRevenue(List<Map<String, dynamic>> list) {
    double max = 0;
    for (final item in list) {
      final val =
          _parseDouble(item['amount'] ?? item['revenue'] ?? 0);
      if (val > max) max = val;
    }
    return max == 0 ? 100 : max;
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LEAD SOURCES TAB
// ============================================================
class _LeadSourcesTab extends StatefulWidget {
  const _LeadSourcesTab();

  @override
  State<_LeadSourcesTab> createState() => _LeadSourcesTabState();
}

class _LeadSourcesTabState extends State<_LeadSourcesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String? _error;
  int? _touchedIndex;

  static const List<Color> _pieColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.accent,
    Color(0xFF8B5CF6),
    AppColors.error,
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
  ];

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await context.read<CRMProvider>().fetchLeadSourceReport();
      if (mounted) {
        setState(() {
          _reportData = data;
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

  List<Map<String, dynamic>> _extractSources() {
    if (_reportData == null) return [];
    final sources = _reportData!['sources'] ??
        _reportData!['lead_sources'] ??
        _reportData!['data'];
    if (sources is List) {
      return sources
          .map((e) =>
              e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null && _reportData == null) {
      return CrmErrorWidget(
          message: _error!, onRetry: _fetchReport);
    }

    final sources = _extractSources();

    if (sources.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No lead source data',
        subtitle: 'Lead source analytics will appear here',
      );
    }

    final total = sources.fold<double>(
        0,
        (sum, s) =>
            sum +
            _parseDouble(s['count'] ?? s['total'] ?? s['leads'] ?? 0));

    return RefreshIndicator(
      onRefresh: _fetchReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pie chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 240,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = response
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: List.generate(sources.length, (i) {
                        final source = sources[i];
                        final count = _parseDouble(source['count'] ??
                            source['total'] ??
                            source['leads'] ??
                            0);
                        final isTouched = i == _touchedIndex;
                        final color =
                            _pieColors[i % _pieColors.length];

                        return PieChartSectionData(
                          color: color,
                          value: count,
                          title: isTouched
                              ? '${count.toInt()}'
                              : '${(count / total * 100).toStringAsFixed(0)}%',
                          radius: isTouched ? 60 : 50,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 14 : 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(sources.length, (i) {
                final source = sources[i];
                final name =
                    (source['name'] ?? source['source'] ?? 'Unknown')
                        .toString();
                final color = _pieColors[i % _pieColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 24),

            // Table
            const Text(
              'Source Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Source',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Count',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Conversion',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rows
                  ...List.generate(sources.length, (i) {
                    final source = sources[i];
                    final name = (source['name'] ??
                            source['source'] ??
                            'Unknown')
                        .toString();
                    final count = _parseDouble(source['count'] ??
                        source['total'] ??
                        source['leads'] ??
                        0);
                    final conversionRate = _parseDouble(
                        source['conversion_rate'] ??
                            source['conversion'] ??
                            0);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i < sources.length - 1
                            ? const Border(
                                bottom: BorderSide(
                                    color: Color(0xFFE2E8F0)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color:
                                  _pieColors[i % _pieColors.length],
                              borderRadius:
                                  BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${count.toInt()}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3),
                                  decoration: BoxDecoration(
                                    color: conversionRate > 50
                                        ? AppColors.success
                                            .withValues(alpha: 0.1)
                                        : conversionRate > 25
                                            ? AppColors.accent
                                                .withValues(
                                                    alpha: 0.1)
                                            : AppColors.error
                                                .withValues(
                                                    alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${conversionRate.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: conversionRate > 50
                                          ? AppColors.success
                                          : conversionRate > 25
                                              ? AppColors.accent
                                              : AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

// ============================================================
// TEAM TAB
// ============================================================
class _TeamTab extends StatefulWidget {
  const _TeamTab();

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await context
          .read<CRMProvider>()
          .fetchTeamPerformanceReport();
      if (mounted) {
        setState(() {
          _reportData = data;
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

  List<Map<String, dynamic>> _extractMembers() {
    if (_reportData == null) return [];
    final members = _reportData!['members'] ??
        _reportData!['team'] ??
        _reportData!['data'];
    if (members is List) {
      return members
          .map((e) =>
              e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null && _reportData == null) {
      return CrmErrorWidget(
          message: _error!, onRetry: _fetchReport);
    }

    final members = _extractMembers();

    if (members.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_rounded,
        title: 'No team data',
        subtitle: 'Team performance analytics will appear here',
      );
    }

    final currencyFormat = NumberFormat.currency(
        symbol: '\u20B9', decimalDigits: 0, locale: 'en_IN');

    return RefreshIndicator(
      onRefresh: _fetchReport,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final name = (member['name'] ??
                  member['staff_name'] ??
                  'Unknown')
              .toString();
          final initials = name
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join();
          final leadsAssigned = (member['leads_assigned'] ??
                  member['leads'] ??
                  member['total_leads'] ??
                  0)
              .toString();
          final tasksCompleted = (member['tasks_completed'] ??
                  member['completed_tasks'] ??
                  0)
              .toString();
          final revenue = _parseDouble(member['revenue'] ??
              member['revenue_generated'] ??
              member['total_revenue'] ??
              0);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with avatar and name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (member['role'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member['role'].toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.people_outline_rounded,
                        label: 'Leads',
                        value: leadsAssigned,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Tasks Done',
                        value: tasksCompleted,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Revenue',
                        value: currencyFormat.format(revenue),
                        color: AppColors.accent,
                      ),
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

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
