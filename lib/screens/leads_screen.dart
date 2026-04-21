import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/error_widget.dart';
import 'lead_notes_screen.dart';
import 'activity_timeline_screen.dart';

void showAddLeadSheet(BuildContext context) {
  // Ensure sources/statuses are loaded
  final p = context.read<CRMProvider>();
  p.fetchLeadSources();
  p.fetchLeadStatuses();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AddLeadForm(
      onSave: (data) {
        context.read<CRMProvider>().addLead(data);
        Navigator.pop(ctx);
      },
    ),
  );
}

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterStatus;
  String? _filterSource;
  DateTimeRange? _filterDateRange;
  String _sortField = 'dateadded';
  bool _sortAscending = false;

  int get _activeFilterCount => [
    if (_filterStatus != null) 1,
    if (_filterSource != null) 1,
    if (_filterDateRange != null) 1,
  ].length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<CRMProvider>();
      p.fetchLeads();
      p.fetchLeadSources();
      p.fetchLeadStatuses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterLeads(List<Map<String, dynamic>> leads) {
    var filtered = leads.toList();

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((lead) {
        final name = (lead['name'] ?? '${lead['first_name'] ?? lead['firstname'] ?? ''} ${lead['last_name'] ?? lead['lastname'] ?? ''}'.trim()).toString().toLowerCase();
        final phone = (lead['phonenumber'] ?? lead['phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    // Status filter
    if (_filterStatus != null) {
      filtered = filtered.where((l) => (l['status'] ?? l['lead_status'] ?? '').toString() == _filterStatus).toList();
    }

    // Source filter
    if (_filterSource != null) {
      filtered = filtered.where((l) => (l['source'] ?? '').toString() == _filterSource).toList();
    }

    // Date range filter
    if (_filterDateRange != null) {
      filtered = filtered.where((l) {
        final dateStr = (l['dateadded'] ?? l['created_at'] ?? '').toString();
        final dt = DateTime.tryParse(dateStr);
        if (dt == null) return false;
        return !dt.isBefore(_filterDateRange!.start) && !dt.isAfter(_filterDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      dynamic va, vb;
      switch (_sortField) {
        case 'name':
          va = (a['name'] ?? '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim()).toString().toLowerCase();
          vb = (b['name'] ?? '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.trim()).toString().toLowerCase();
          break;
        case 'lead_value':
          va = double.tryParse((a['lead_value'] ?? '0').toString()) ?? 0;
          vb = double.tryParse((b['lead_value'] ?? '0').toString()) ?? 0;
          break;
        default:
          va = (a['dateadded'] ?? a['created_at'] ?? '').toString();
          vb = (b['dateadded'] ?? b['created_at'] ?? '').toString();
      }
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  /// Compute stats from the full leads list (before search filter).
  Map<String, int> _computeStats(List<Map<String, dynamic>> leads, List<Map<String, dynamic>> statuses) {
    final stats = <String, int>{'total': leads.length};
    for (final s in statuses) {
      final id = s['id'].toString();
      final name = (s['name'] ?? '').toString().toLowerCase();
      final count = leads.where((l) => (l['status'] ?? l['lead_status'] ?? '').toString() == id).length;
      stats[name] = count;
    }
    return stats;
  }

  Color _statusColorByName(String name) {
    final n = name.toLowerCase();
    if (n.contains('new') || n.contains('open')) return AppColors.info;
    if (n.contains('contact') || n.contains('follow')) return const Color(0xFF8B5CF6);
    if (n.contains('convert') || n.contains('won') || n.contains('active')) return AppColors.success;
    if (n.contains('lost') || n.contains('dead') || n.contains('closed')) return AppColors.error;
    if (n.contains('pend') || n.contains('warm') || n.contains('proposal')) return AppColors.warning;
    return AppColors.textMuted;
  }

  void _showFilterSheet() {
    final provider = context.read<CRMProvider>();
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
                      setState(() {
                        _filterStatus = null;
                        _filterSource = null;
                        _filterDateRange = null;
                        _sortField = 'dateadded';
                        _sortAscending = false;
                      });
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
                  _filterChip('All', _filterStatus == null, () { setSheetState(() {}); setState(() => _filterStatus = null); }),
                  ...provider.leadStatuses.map((s) => _filterChip(
                    s['name']?.toString() ?? '',
                    _filterStatus == s['id'].toString(),
                    () { setSheetState(() {}); setState(() => _filterStatus = s['id'].toString()); },
                  )),
                ],
              ),
              const SizedBox(height: 20),

              // Source
              const Text('Source', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _filterChip('All', _filterSource == null, () { setSheetState(() {}); setState(() => _filterSource = null); }),
                  ...provider.leadSources.map((s) => _filterChip(
                    s['name']?.toString() ?? '',
                    _filterSource == s['id'].toString(),
                    () { setSheetState(() {}); setState(() => _filterSource = s['id'].toString()); },
                  )),
                ],
              ),
              const SizedBox(height: 20),

              // Date range
              const Text('Date Added', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _filterDateRange,
                  );
                  if (range != null) {
                    setSheetState(() {});
                    setState(() => _filterDateRange = range);
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_filterDateRange != null
                    ? '${DateFormat('dd MMM').format(_filterDateRange!.start)} - ${DateFormat('dd MMM').format(_filterDateRange!.end)}'
                    : 'Select date range'),
              ),
              const SizedBox(height: 20),

              // Sort
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _filterChip('Date Added', _sortField == 'dateadded', () { setSheetState(() {}); setState(() => _sortField = 'dateadded'); }),
                  _filterChip('Name', _sortField == 'name', () { setSheetState(() {}); setState(() => _sortField = 'name'); }),
                  _filterChip('Value', _sortField == 'lead_value', () { setSheetState(() {}); setState(() => _sortField = 'lead_value'); }),
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

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
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
    final adaptive = AppColors.adaptive(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads'),
        automaticallyImplyLeading: false,
        actions: [
          _ActionButton(icon: Icons.refresh_rounded, onTap: () => context.read<CRMProvider>().fetchLeads()),
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
          _ActionButton(icon: Icons.add_rounded, onTap: () => _showAddLeadDialog(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.leads.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.error != null && provider.leads.isEmpty) {
            return CrmErrorWidget(message: provider.error!, onRetry: () => provider.fetchLeads());
          }
          if (provider.leads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('No leads yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      'Start building your pipeline by adding\nyour first lead.',
                      style: TextStyle(color: adaptive.textSecondary, fontSize: 14, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddLeadDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add First Lead', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredLeads = _filterLeads(provider.leads);
          final stats = _computeStats(provider.leads, provider.leadStatuses);

          return RefreshIndicator(
            onRefresh: () => provider.fetchLeads(),
            child: Column(
              children: [
                // Stats summary row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _StatBadge(label: 'Total', count: stats['total'] ?? 0, color: colorScheme.onSurface),
                        ...provider.leadStatuses.map((s) {
                          final name = (s['name'] ?? '').toString();
                          final count = stats[name.toLowerCase()] ?? 0;
                          Color c = _statusColorByName(name);
                          final hexColor = s['color']?.toString() ?? '';
                          if (hexColor.startsWith('#') && hexColor.length >= 7) {
                            c = Color(int.parse('FF${hexColor.substring(1)}', radix: 16));
                          }
                          return _StatBadge(label: name, count: count, color: c);
                        }),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or mobile...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredLeads.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: adaptive.textMuted),
                              const SizedBox(height: 12),
                              Text('No leads match "$_searchQuery"', style: TextStyle(color: adaptive.textSecondary)),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scroll) {
                            if (_searchQuery.isEmpty && scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 && !provider.isLoading && provider.leadsHasMore) {
                              provider.fetchLeads(loadMore: true);
                            }
                            return false;
                          },
                          child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filteredLeads.length + (_searchQuery.isEmpty && provider.leadsHasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filteredLeads.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      return _LeadCard(
                        lead: filteredLeads[index],
                        statuses: provider.leadStatuses,
                        onTap: () => _showDetailSheet(context, filteredLeads[index]),
                      );
                    },
                  ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context, Map<String, dynamic> lead) {
    final name = lead['name'] ?? '${lead['first_name'] ?? lead['firstname'] ?? ''} ${lead['last_name'] ?? lead['lastname'] ?? ''}'.trim();
    final adaptive = AppColors.adaptive(context);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller, padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: adaptive.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Center(child: Container(width: 72, height: 72,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary))))),
              const SizedBox(height: 12),
              Center(child: Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface))),
              const SizedBox(height: 24),
              ...lead.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty && !['id', 'hash', 'addedfrom', 'leadorder'].contains(e.key))
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 130, child: Text(_formatKey(e.key), style: TextStyle(color: adaptive.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(e.value.toString(), style: TextStyle(fontSize: 14, color: colorScheme.onSurface))),
                    ]),
                  )),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(height: 48, child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LeadNotesScreen(leadId: lead['id'].toString(), leadName: name),
                        ));
                      },
                      icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      label: const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(height: 48, child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ActivityTimelineScreen(entityType: 'lead', entityId: lead['id'].toString(), entityName: name),
                        ));
                      },
                      icon: const Icon(Icons.timeline_rounded, size: 18),
                      label: const Text('Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(height: 48, child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Convert to Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: Text('Convert "$name" to a customer?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Convert'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    Navigator.pop(ctx);
                    try {
                      await context.read<CRMProvider>().convertLeadToCustomer(lead['id'].toString());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lead converted to customer!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Conversion failed: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Convert to Customer'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(height: 8),
              SizedBox(height: 48, child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); context.read<CRMProvider>().deleteLead(lead['id'].toString()); },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                label: const Text('Delete Lead', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
              )),
            ],
          ),
        );
      },
    );
  }

  void _showAddLeadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddLeadForm(
        onSave: (data) {
          context.read<CRMProvider>().addLead(data);
          Navigator.pop(ctx);
        },
      ),
    );
  }


  String _formatKey(String key) {
    return key.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}

// ---------------------------------------------------------------------------
// Lead Card Widget
// ---------------------------------------------------------------------------
class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final List<Map<String, dynamic>> statuses;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.statuses, required this.onTap});

  Color _statusColorByName(String name) {
    final n = name.toLowerCase();
    if (n.contains('new') || n.contains('open')) return AppColors.info;
    if (n.contains('contact') || n.contains('follow')) return const Color(0xFF8B5CF6);
    if (n.contains('convert') || n.contains('won') || n.contains('active')) return AppColors.success;
    if (n.contains('lost') || n.contains('dead') || n.contains('closed')) return AppColors.error;
    if (n.contains('pend') || n.contains('warm') || n.contains('proposal')) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final adaptive = AppColors.adaptive(context);

    final name = lead['name'] ?? '${lead['first_name'] ?? lead['firstname'] ?? ''} ${lead['last_name'] ?? lead['lastname'] ?? ''}'.trim();
    final email = lead['email'] ?? '';
    final phone = lead['phonenumber'] ?? lead['phone'] ?? '';
    final status = lead['status'] ?? lead['lead_status'] ?? '';
    final company = lead['company'] ?? '';
    final leadValue = lead['lead_value']?.toString() ?? '';

    // Resolve status
    String statusName = status.toString();
    Color statusColor = AppColors.textMuted;
    for (final s in statuses) {
      if (s['id'].toString() == status.toString()) {
        statusName = s['name'] ?? status.toString();
        final hexColor = s['color']?.toString() ?? '';
        if (hexColor.startsWith('#') && hexColor.length >= 7) {
          statusColor = Color(int.parse('FF${hexColor.substring(1)}', radix: 16));
        } else {
          statusColor = _statusColorByName(statusName);
        }
        break;
      }
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: adaptive.border),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Colored left border accent
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Row(
                        children: [
                          // Avatar circle with initials
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(
                              initial,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: statusColor),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Company name large if exists, else lead name
                                if (company.toString().isNotEmpty) ...[
                                  Text(company.toString(),
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colorScheme.onSurface),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 1),
                                  Text(name.isNotEmpty ? name : 'Unknown',
                                      style: TextStyle(fontSize: 12.5, color: adaptive.textSecondary, fontWeight: FontWeight.w500),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ] else ...[
                                  Text(name.isNotEmpty ? name : 'Unknown',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colorScheme.onSurface),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Status pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(statusName,
                                        style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (leadValue.isNotEmpty && leadValue != '0' && leadValue != '0.00') ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.currency_rupee_rounded, size: 11, color: adaptive.textMuted),
                                      Text(leadValue,
                                        style: TextStyle(fontSize: 11, color: adaptive.textMuted, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    if (email.toString().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          email.toString(),
                                          style: TextStyle(fontSize: 11, color: adaptive.textMuted),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Action buttons
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (phone.toString().isNotEmpty) ...[
                                _CardIconButton(
                                  icon: Icons.call_rounded,
                                  color: AppColors.success,
                                  onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.toString())),
                                  tooltip: 'Call',
                                ),
                                const SizedBox(height: 4),
                                _CardIconButton(
                                  icon: Icons.chat_rounded,
                                  color: const Color(0xFF25D366),
                                  onTap: () {
                                    final cleaned = phone.toString().replaceAll(RegExp(r'[^\d+]'), '');
                                    launchUrl(Uri.parse('https://wa.me/$cleaned'));
                                  },
                                  tooltip: 'WhatsApp',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Badge
// ---------------------------------------------------------------------------
class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final adaptive = AppColors.adaptive(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: adaptive.textSecondary)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small icon button for card actions
// ---------------------------------------------------------------------------
class _CardIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _CardIconButton({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36, height: 36,
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Lead Form (unchanged)
// ---------------------------------------------------------------------------
class _AddLeadForm extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSave;
  const _AddLeadForm({required this.onSave});

  @override
  State<_AddLeadForm> createState() => _AddLeadFormState();
}

class _AddLeadFormState extends State<_AddLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _companyC = TextEditingController();
  final _titleC = TextEditingController();
  final _websiteC = TextEditingController();
  final _addressC = TextEditingController();
  final _cityC = TextEditingController();
  final _stateC = TextEditingController();
  final _countryC = TextEditingController();
  final _zipC = TextEditingController();
  final _descC = TextEditingController();
  final _leadValueC = TextEditingController();
  String? _source;
  String? _status;

  @override
  void dispose() {
    for (final c in [_nameC, _emailC, _phoneC, _companyC, _titleC, _websiteC, _addressC, _cityC, _stateC, _countryC, _zipC, _descC, _leadValueC]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) {
        final provider = context.watch<CRMProvider>();
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Add New Lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                const SizedBox(height: 20),

                // Name *
                _field(_nameC, 'Name *', Icons.person_outline_rounded, validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                const SizedBox(height: 14),

                // Email
                _field(_emailC, 'Email', Icons.mail_outline_rounded, type: TextInputType.emailAddress),
                const SizedBox(height: 14),

                // Phone
                _field(_phoneC, 'Phone Number', Icons.phone_rounded, type: TextInputType.phone),
                const SizedBox(height: 14),

                // Company
                _field(_companyC, 'Company', Icons.business_rounded),
                const SizedBox(height: 14),

                // Title / Position
                _field(_titleC, 'Title / Position', Icons.badge_rounded),
                const SizedBox(height: 14),

                // Source dropdown
                if (provider.leadSources.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source_rounded, size: 20)),
                    initialValue: _source,
                    items: provider.leadSources.map((s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(s['name']?.toString() ?? ''),
                    )).toList(),
                    onChanged: (v) => setState(() => _source = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // Status dropdown
                if (provider.leadStatuses.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag_rounded, size: 20)),
                    initialValue: _status,
                    items: provider.leadStatuses.map((s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(s['name']?.toString() ?? ''),
                    )).toList(),
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // Lead Value
                _field(_leadValueC, 'Lead Value', Icons.currency_rupee_rounded, type: TextInputType.number),
                const SizedBox(height: 14),

                // Website
                _field(_websiteC, 'Website', Icons.language_rounded, type: TextInputType.url),
                const SizedBox(height: 14),

                // Address
                _field(_addressC, 'Address', Icons.location_on_outlined),
                const SizedBox(height: 14),

                // City, State row
                Row(
                  children: [
                    Expanded(child: _field(_cityC, 'City', null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_stateC, 'State', null)),
                  ],
                ),
                const SizedBox(height: 14),

                // Country, ZIP row
                Row(
                  children: [
                    Expanded(child: _field(_countryC, 'Country', null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_zipC, 'ZIP Code', null)),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descC,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded, size: 20)),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final data = <String, dynamic>{
                          'name': _nameC.text,
                        };
                        if (_emailC.text.isNotEmpty) data['email'] = _emailC.text;
                        if (_phoneC.text.isNotEmpty) data['phonenumber'] = _phoneC.text;
                        if (_companyC.text.isNotEmpty) data['company'] = _companyC.text;
                        if (_titleC.text.isNotEmpty) data['title'] = _titleC.text;
                        if (_source != null) data['source'] = _source;
                        if (_status != null) data['status'] = _status;
                        if (_leadValueC.text.isNotEmpty) data['lead_value'] = _leadValueC.text;
                        if (_websiteC.text.isNotEmpty) data['website'] = _websiteC.text;
                        if (_addressC.text.isNotEmpty) data['address'] = _addressC.text;
                        if (_cityC.text.isNotEmpty) data['city'] = _cityC.text;
                        if (_stateC.text.isNotEmpty) data['state'] = _stateC.text;
                        if (_countryC.text.isNotEmpty) data['country'] = _countryC.text;
                        if (_zipC.text.isNotEmpty) data['zip'] = _zipC.text;
                        if (_descC.text.isNotEmpty) data['description'] = _descC.text;
                        widget.onSave(data);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Save Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _field(TextEditingController c, String label, IconData? icon, {TextInputType? type, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
      keyboardType: type,
      validator: validator,
    );
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
      decoration: BoxDecoration(color: AppColors.adaptive(context).surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, size: 20), onPressed: onTap, splashRadius: 20),
    );
  }
}
