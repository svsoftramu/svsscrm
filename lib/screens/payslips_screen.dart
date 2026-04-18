import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';

class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await Provider.of<CRMProvider>(context, listen: false).fetchPayslips();
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _getMonthName(dynamic month) {
    if (month == null) return '';
    final monthNum = int.tryParse(month.toString());
    if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
      return DateFormat.MMMM().format(DateTime(2024, monthNum));
    }
    return month.toString();
  }

  void _showPayslipDetail(Map<String, dynamic> payslip) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Payslip Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (payslip['month'] != null || payslip['year'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_getMonthName(payslip['month'])} ${payslip['year'] ?? ''}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const Divider(height: 24),
              ...payslip.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            _formatKey(entry.key),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${entry.value ?? 'N/A'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: _isAmountField(entry.key)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAmountField(String key) {
    final lower = key.toLowerCase();
    return lower.contains('salary') ||
        lower.contains('amount') ||
        lower.contains('pay') ||
        lower.contains('total') ||
        lower.contains('net') ||
        lower.contains('gross') ||
        lower.contains('deduction') ||
        lower.contains('allowance');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final payslips = provider.payslips;

          if (payslips.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (payslips.isEmpty && provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.error!.replaceFirst('Exception: ', ''),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (payslips.isEmpty) {
            return const Center(
              child: Text('No payslips found.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payslips.length,
              itemBuilder: (context, index) {
                final payslip = payslips[index];
                final month = _getMonthName(payslip['month']);
                final year = payslip['year']?.toString() ?? '';
                final netSalary = payslip['net_salary'] ??
                    payslip['net_pay'] ??
                    payslip['amount'] ??
                    payslip['total'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _showPayslipDetail(payslip),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.receipt,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$month $year',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to view details',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (netSalary != null)
                            Text(
                              '\$$netSalary',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
