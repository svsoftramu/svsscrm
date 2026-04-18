import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../utils/status_helpers.dart';
import '../widgets/error_widget.dart';
import '../widgets/empty_state_widget.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => context.read<CRMProvider>().fetchInvoices(),
              splashRadius: 20,
            ),
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.invoices.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.error != null && provider.invoices.isEmpty) {
            return CrmErrorWidget(message: provider.error!, onRetry: () => provider.fetchInvoices());
          }
          if (provider.invoices.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long_rounded,
              title: 'No invoices yet',
              subtitle: 'Your invoices will appear here',
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchInvoices(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 && !provider.isLoading && provider.invoicesHasMore) {
                  provider.fetchInvoices(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: provider.invoices.length + (provider.invoicesHasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.invoices.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final invoice = provider.invoices[index];
                  return _InvoiceCard(invoice: invoice);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final number = invoice['number'] ?? invoice['invoice_number'] ?? invoice['prefix']?.toString() ?? '#${invoice['id'] ?? ''}';
    final clientName = invoice['client_name'] ?? invoice['company'] ?? invoice['customer_name'] ?? '';
    final total = invoice['total'] ?? invoice['amount'] ?? invoice['subtotal'] ?? '';
    final status = (invoice['status'] ?? '').toString();
    final date = invoice['date'] ?? invoice['datecreated'] ?? invoice['created_at'] ?? '';
    final dueDate = invoice['duedate'] ?? invoice['due_date'] ?? '';

    final statusLabel = invoiceStatusLabel(status);
    final statusColor = invoiceStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF14B8A6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(number.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      [if (clientName.toString().isNotEmpty) clientName, if (date.toString().isNotEmpty) _formatDate(date.toString())].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (dueDate.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Due: ${_formatDate(dueDate.toString())}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (total.toString().isNotEmpty)
                    Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
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
              Center(child: Container(width: 72, height: 72,
                  decoration: BoxDecoration(color: const Color(0xFF14B8A6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF14B8A6)))),
              const SizedBox(height: 12),
              Center(child: Text(
                invoice['number']?.toString() ?? invoice['invoice_number']?.toString() ?? '#${invoice['id'] ?? ''}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              )),
              const SizedBox(height: 24),
              ...invoice.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty && !['id', 'hash', 'addedfrom'].contains(e.key))
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 130, child: Text(_formatKey(e.key), style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.tryParse(date);
      if (dt != null) return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {}
    return date;
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}
