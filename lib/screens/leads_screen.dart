import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/error_widget.dart';
import '../widgets/empty_state_widget.dart';
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
            return const EmptyStateWidget(icon: Icons.person_add_alt_1_rounded, title: 'No leads yet', subtitle: 'Tap + to add your first lead');
          }

          final filteredLeads = _filterLeads(provider.leads);

          return RefreshIndicator(
            onRefresh: () => provider.fetchLeads(),
            child: Column(
              children: [
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
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text('No leads match "$_searchQuery"', style: const TextStyle(color: AppColors.textSecondary)),
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
                      final lead = filteredLeads[index];
                final name = lead['name'] ?? '${lead['first_name'] ?? lead['firstname'] ?? ''} ${lead['last_name'] ?? lead['lastname'] ?? ''}'.trim();
                final email = lead['email'] ?? '';
                final phone = lead['phonenumber'] ?? lead['phone'] ?? '';
                final status = lead['status'] ?? lead['lead_status'] ?? '';
                final company = lead['company'] ?? '';

                // Find status name from statuses list
                String statusName = status.toString();
                Color statusColor = AppColors.textMuted;
                for (final s in provider.leadStatuses) {
                  if (s['id'].toString() == status.toString()) {
                    statusName = s['name'] ?? status.toString();
                    final hexColor = s['color']?.toString() ?? '';
                    if (hexColor.startsWith('#') && hexColor.length >= 7) {
                      statusColor = Color(int.parse('FF${hexColor.substring(1)}', radix: 16));
                    }
                    break;
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _showDetailSheet(context, lead),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isNotEmpty ? name : 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  company.isNotEmpty ? '$company  ·  $email' : email,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (phone.toString().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.call_rounded, color: AppColors.success, size: 20),
                                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone.toString())),
                                splashRadius: 20,
                                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusName, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary))))),
              const SizedBox(height: 12),
              Center(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              const SizedBox(height: 24),
              ...lead.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty && !['id', 'hash', 'addedfrom', 'leadorder'].contains(e.key))
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 130, child: Text(_formatKey(e.key), style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
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
                const Text('Add New Lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, size: 20), onPressed: onTap, splashRadius: 20),
    );
  }
}

