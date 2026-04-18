import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late int _month;
  late int _year;
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService.instance;
      final monthlyRes = await api.get('attendance/monthly?month=$_month&year=$_year');
      final summaryRes = await api.get('attendance/summary?month=$_month&year=$_year');

      final monthlyData = monthlyRes['data'];
      final summaryData = summaryRes['data'];

      if (mounted) {
        setState(() {
          _records = monthlyData is List
              ? monthlyData.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          _summary = summaryData is Map ? Map<String, dynamic>.from(summaryData) : {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _records = [];
          _summary = {};
          _isLoading = false;
        });
      }
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
    _fetchData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
    _fetchData();
  }

  String _formatTime(dynamic value) {
    if (value == null) return '--:--';
    final str = value.toString();
    try {
      if (str.contains(' ') && str.length > 10) {
        return DateFormat('hh:mm a').format(DateTime.parse(str));
      }
      if (str.contains(':')) {
        final parts = str.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$h12:$minute $period';
      }
    } catch (_) {}
    return str;
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEE, dd MMM').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String get _monthLabel => DateFormat('MMMM yyyy').format(DateTime(_year, _month));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report')),
      body: Column(
        children: [
          // Month navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surfaceVariant),
                ),
                Text(_monthLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                IconButton(
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: _isCurrentMonth ? Colors.grey.shade100 : AppColors.surfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        // Summary cards
                        _buildSummaryCards(),
                        const SizedBox(height: 20),

                        // Daily records header
                        Row(
                          children: [
                            const Text('Daily Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            Text('${_records.length} days', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Records
                        if (_records.isEmpty)
                          _buildEmptyState()
                        else
                          ..._records.map(_buildDayCard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final present = _summary['present'] ?? 0;
    final absent = _summary['absent'] ?? 0;
    final late = _summary['late'] ?? 0;
    final total = _summary['total'] ?? 0;

    // Calculate total hours from records
    double totalHours = 0;
    for (final r in _records) {
      final h = r['hours_worked'] ?? r['total_hours'];
      if (h != null) {
        totalHours += double.tryParse(h.toString()) ?? 0;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Present', value: '$present', icon: Icons.check_circle_rounded, color: AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(label: 'Absent', value: '$absent', icon: Icons.cancel_rounded, color: AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(label: 'Late', value: '$late', icon: Icons.schedule_rounded, color: AppColors.warning)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Total Days', value: '$total', icon: Icons.calendar_month_rounded, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(label: 'Hours', value: totalHours > 0 ? totalHours.toStringAsFixed(1) : '--', icon: Icons.timer_rounded, color: const Color(0xFF6366F1))),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Attendance',
                value: total > 0 ? '${((present / total) * 100).round()}%' : '--',
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFF0EA5E9),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> record) {
    final date = record['attendance_date'] ?? record['date'] ?? '';
    final checkIn = _formatTime(record['check_in'] ?? record['checkin_time']);
    final checkOut = _formatTime(record['check_out'] ?? record['checkout_time']);
    final status = (record['status'] ?? '').toString();
    final hours = record['hours_worked'] ?? record['total_hours'];
    final isPresent = status.toLowerCase() == 'present';
    final isLate = status.toLowerCase() == 'late';
    final statusColor = isPresent ? AppColors.success : isLate ? AppColors.warning : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPresent ? Icons.check_circle_rounded : isLate ? Icons.schedule_rounded : Icons.cancel_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(date.toString()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (hours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${hours}h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.login_rounded, size: 15, color: AppColors.success.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text('In: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        Text(checkIn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 15, color: AppColors.error.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text('Out: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        Text(checkOut, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.event_busy_rounded, size: 40, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text('No attendance records', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('No data found for $_monthLabel', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
