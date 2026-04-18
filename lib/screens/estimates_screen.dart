import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../utils/status_helpers.dart';
import '../widgets/error_widget.dart';
import '../widgets/empty_state_widget.dart';

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchEstimates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimates'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => context.read<CRMProvider>().fetchEstimates(),
              splashRadius: 20,
            ),
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.estimates.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.error != null && provider.estimates.isEmpty) {
            return CrmErrorWidget(message: provider.error!, onRetry: () => provider.fetchEstimates());
          }
          if (provider.estimates.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.description_rounded,
              title: 'No estimates yet',
              subtitle: 'Your estimates will appear here',
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchEstimates(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 && !provider.isLoading && provider.estimatesHasMore) {
                  provider.fetchEstimates(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: provider.estimates.length + (provider.estimatesHasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.estimates.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final estimate = provider.estimates[index];
                  return _EstimateCard(estimate: estimate);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  const _EstimateCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final number = estimate['number'] ?? estimate['estimate_number'] ?? estimate['prefix']?.toString() ?? '#${estimate['id'] ?? ''}';
    final clientName = estimate['client_name'] ?? estimate['company'] ?? estimate['customer_name'] ?? '';
    final total = estimate['total'] ?? estimate['amount'] ?? estimate['subtotal'] ?? '';
    final status = (estimate['status'] ?? '').toString();
    final date = estimate['date'] ?? estimate['datecreated'] ?? estimate['created_at'] ?? '';
    final statusLabel = estimateStatusLabel(status);
    final statusColor = estimateStatusColor(status);

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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFF8B5CF6), size: 22),
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
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.description_rounded, size: 32, color: Color(0xFF8B5CF6)))),
              const SizedBox(height: 12),
              Center(child: Text(
                estimate['number']?.toString() ?? estimate['estimate_number']?.toString() ?? '#${estimate['id'] ?? ''}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              )),
              const SizedBox(height: 24),
              ...estimate.entries
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
