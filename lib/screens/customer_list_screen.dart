import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/error_widget.dart';
import 'activity_timeline_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortField = 'datecreated';
  bool _sortAscending = false;
  String? _filterCity;
  Timer? _debounce;

  int get _activeFilterCount => [if (_filterCity != null) 1].length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchCustomers();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  List<Map<String, dynamic>> _filterCustomers(List<Map<String, dynamic>> customers) {
    var filtered = customers.toList();

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final company = (c['company'] ?? '').toString().toLowerCase();
        final contactName = (c['contact_name'] ?? c['contact_person'] ?? '').toString().toLowerCase();
        final phone = (c['phonenumber'] ?? c['contact_phone'] ?? c['phone'] ?? '').toString().toLowerCase();
        return company.contains(q) || contactName.contains(q) || phone.contains(q);
      }).toList();
    }

    // City filter
    if (_filterCity != null) {
      filtered = filtered.where((c) => (c['city'] ?? '').toString().toLowerCase() == _filterCity!.toLowerCase()).toList();
    }

    // Sort
    filtered.sort((a, b) {
      dynamic va, vb;
      switch (_sortField) {
        case 'company':
          va = (a['company'] ?? '').toString().toLowerCase();
          vb = (b['company'] ?? '').toString().toLowerCase();
          break;
        case 'contact_name':
          va = (a['contact_name'] ?? a['contact_person'] ?? '').toString().toLowerCase();
          vb = (b['contact_name'] ?? b['contact_person'] ?? '').toString().toLowerCase();
          break;
        default:
          va = (a['datecreated'] ?? a['created_at'] ?? '').toString();
          vb = (b['datecreated'] ?? b['created_at'] ?? '').toString();
      }
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  /// Compute stats from the full customer list.
  Map<String, int> _computeStats(List<Map<String, dynamic>> customers) {
    final now = DateTime.now();
    int thisMonth = 0;
    int active = 0;

    for (final c in customers) {
      final isActive = (c['active'] ?? c['status'] ?? '1').toString();
      if (isActive == '1' || isActive.toLowerCase() == 'active') active++;

      final dateStr = (c['datecreated'] ?? c['created_at'] ?? '').toString();
      final dt = DateTime.tryParse(dateStr);
      if (dt != null && dt.year == now.year && dt.month == now.month) {
        thisMonth++;
      }
    }

    return {
      'total': customers.length,
      'active': active,
      'this_month': thisMonth,
    };
  }

  void _showFilterSheet() {
    final provider = context.read<CRMProvider>();
    // Extract unique cities
    final cities = provider.customers
        .map((c) => (c['city'] ?? '').toString().trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.5, maxChildSize: 0.75,
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
                      setState(() { _filterCity = null; _sortField = 'datecreated'; _sortAscending = false; });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // City filter
              if (cities.isNotEmpty) ...[
                const Text('City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _filterChip('All', _filterCity == null, () { setSheetState(() {}); setState(() => _filterCity = null); }),
                    ...cities.map((c) => _filterChip(c, _filterCity == c, () { setSheetState(() {}); setState(() => _filterCity = c); })),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Sort
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _filterChip('Date Added', _sortField == 'datecreated', () { setSheetState(() {}); setState(() => _sortField = 'datecreated'); }),
                  _filterChip('Company', _sortField == 'company', () { setSheetState(() {}); setState(() => _sortField = 'company'); }),
                  _filterChip('Contact', _sortField == 'contact_name', () { setSheetState(() {}); setState(() => _sortField = 'contact_name'); }),
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
        title: const Text('Customers'),
        automaticallyImplyLeading: false,
        actions: [
          _ActionButton(icon: Icons.refresh_rounded, onTap: () => context.read<CRMProvider>().fetchCustomers()),
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
          _ActionButton(icon: Icons.add_rounded, onTap: () => _showAddDialog(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.customers.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (provider.error != null && provider.customers.isEmpty) {
            return CrmErrorWidget(message: provider.error!, onRetry: () => provider.fetchCustomers());
          }
          if (provider.customers.isEmpty) {
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
                        color: AppColors.success.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_rounded, size: 40, color: AppColors.success),
                    ),
                    const SizedBox(height: 20),
                    Text('No customers yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      'Add your first customer or convert\na lead to get started.',
                      style: TextStyle(color: adaptive.textSecondary, fontSize: 14, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add First Customer', style: TextStyle(fontWeight: FontWeight.w600)),
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

          final filteredCustomers = _filterCustomers(provider.customers);
          final stats = _computeStats(provider.customers);

          return RefreshIndicator(
            onRefresh: () => provider.fetchCustomers(),
            child: Column(
              children: [
                // Stats summary row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _StatBadge(label: 'Total', count: stats['total'] ?? 0, color: colorScheme.onSurface),
                      const SizedBox(width: 8),
                      _StatBadge(label: 'Active', count: stats['active'] ?? 0, color: AppColors.success),
                      const SizedBox(width: 8),
                      _StatBadge(label: 'This Month', count: stats['this_month'] ?? 0, color: AppColors.info),
                    ],
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
                    onChanged: _onSearchChanged,
                  ),
                ),
                Expanded(
                  child: filteredCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: adaptive.textMuted),
                              const SizedBox(height: 12),
                              Text('No customers match "$_searchQuery"', style: TextStyle(color: adaptive.textSecondary)),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scroll) {
                            if (_searchQuery.isEmpty && scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 && !provider.isLoading && provider.customersHasMore) {
                              provider.fetchCustomers(loadMore: true);
                            }
                            return false;
                          },
                          child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filteredCustomers.length + (_searchQuery.isEmpty && provider.customersHasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= filteredCustomers.length) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                return _CustomerCard(
                  customer: filteredCustomers[index],
                  onTap: () => _showDetailSheet(context, filteredCustomers[index]),
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

  void _showDetailSheet(BuildContext context, Map<String, dynamic> customer) {
    final company = (customer['company'] ?? '').toString().trim();
    final contactName = (customer['contact_name'] ?? '').toString().trim();
    final name = company.isNotEmpty ? company : (contactName.isNotEmpty ? contactName : 'Unknown');
    final adaptive = AppColors.adaptive(context);
    final colorScheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

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
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(initial,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.success))))),
              const SizedBox(height: 12),
              Center(child: Text(name.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface))),
              const SizedBox(height: 24),
              ...customer.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty && e.key != 'id' && e.key != 'userid')
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 120, child: Text(_formatKey(e.key), style: TextStyle(color: adaptive.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(e.value.toString(), style: TextStyle(fontSize: 14, color: colorScheme.onSurface))),
                    ]),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ActivityTimelineScreen(entityType: 'customer', entityId: customer['id']?.toString() ?? customer['userid']?.toString() ?? '', entityName: name.toString()),
                    ));
                  },
                  icon: const Icon(Icons.timeline_rounded, size: 18),
                  label: const Text('Activity Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); context.read<CRMProvider>().deleteCustomer(customer['id']?.toString() ?? customer['userid']?.toString() ?? ''); },
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final companyC = TextEditingController();
    final vatC = TextEditingController();
    final gstC = TextEditingController();
    final cinC = TextEditingController();
    final phoneC = TextEditingController();
    final websiteC = TextEditingController();
    final addressC = TextEditingController();
    final cityC = TextEditingController();
    final stateC = TextEditingController();
    final zipC = TextEditingController();
    final billingStreetC = TextEditingController();
    final billingCityC = TextEditingController();
    final billingStateC = TextEditingController();
    final billingZipC = TextEditingController();
    final shippingStreetC = TextEditingController();
    final shippingCityC = TextEditingController();
    final shippingStateC = TextEditingController();
    final shippingZipC = TextEditingController();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Add Customer'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (companyC.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Company name is required'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    final data = <String, dynamic>{
                      'company': companyC.text.trim(),
                    };
                    if (vatC.text.trim().isNotEmpty) data['vat'] = vatC.text.trim();
                    if (gstC.text.trim().isNotEmpty) data['gst_number'] = gstC.text.trim();
                    if (cinC.text.trim().isNotEmpty) data['cin_number'] = cinC.text.trim();
                    if (phoneC.text.trim().isNotEmpty) data['phonenumber'] = phoneC.text.trim();
                    if (websiteC.text.trim().isNotEmpty) data['website'] = websiteC.text.trim();
                    if (addressC.text.trim().isNotEmpty) data['address'] = addressC.text.trim();
                    if (cityC.text.trim().isNotEmpty) data['city'] = cityC.text.trim();
                    if (stateC.text.trim().isNotEmpty) data['state'] = stateC.text.trim();
                    if (zipC.text.trim().isNotEmpty) data['zip'] = zipC.text.trim();
                    if (billingStreetC.text.trim().isNotEmpty) data['billing_street'] = billingStreetC.text.trim();
                    if (billingCityC.text.trim().isNotEmpty) data['billing_city'] = billingCityC.text.trim();
                    if (billingStateC.text.trim().isNotEmpty) data['billing_state'] = billingStateC.text.trim();
                    if (billingZipC.text.trim().isNotEmpty) data['billing_zip'] = billingZipC.text.trim();
                    if (shippingStreetC.text.trim().isNotEmpty) data['shipping_street'] = shippingStreetC.text.trim();
                    if (shippingCityC.text.trim().isNotEmpty) data['shipping_city'] = shippingCityC.text.trim();
                    if (shippingStateC.text.trim().isNotEmpty) data['shipping_state'] = shippingStateC.text.trim();
                    if (shippingZipC.text.trim().isNotEmpty) data['shipping_zip'] = shippingZipC.text.trim();
                    context.read<CRMProvider>().addCustomer(data);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                const _SectionHeader(title: 'Basic Information'),
                const SizedBox(height: 8),
                TextField(controller: companyC, decoration: const InputDecoration(labelText: 'Company Name *', prefixIcon: Icon(Icons.business_rounded, size: 20))),
                const SizedBox(height: 12),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_rounded, size: 20)), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: websiteC, decoration: const InputDecoration(labelText: 'Website', prefixIcon: Icon(Icons.language_rounded, size: 20)), keyboardType: TextInputType.url),

                // Tax Info
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Tax Information'),
                const SizedBox(height: 8),
                TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT Number', prefixIcon: Icon(Icons.receipt_long_rounded, size: 20))),
                const SizedBox(height: 12),
                TextField(controller: gstC, decoration: const InputDecoration(labelText: 'GST Number', prefixIcon: Icon(Icons.numbers_rounded, size: 20))),
                const SizedBox(height: 12),
                TextField(controller: cinC, decoration: const InputDecoration(labelText: 'CIN Number', prefixIcon: Icon(Icons.badge_rounded, size: 20))),

                // Address
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Address'),
                const SizedBox(height: 8),
                TextField(controller: addressC, decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.location_on_rounded, size: 20)), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: cityC, decoration: const InputDecoration(labelText: 'City'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: stateC, decoration: const InputDecoration(labelText: 'State'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: zipC, decoration: const InputDecoration(labelText: 'ZIP / Postal Code'), keyboardType: TextInputType.number),

                // Billing Address
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Billing Address'),
                const SizedBox(height: 8),
                TextField(controller: billingStreetC, decoration: const InputDecoration(labelText: 'Billing Street'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: billingCityC, decoration: const InputDecoration(labelText: 'Billing City'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: billingStateC, decoration: const InputDecoration(labelText: 'Billing State'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: billingZipC, decoration: const InputDecoration(labelText: 'Billing ZIP'), keyboardType: TextInputType.number),

                // Shipping Address
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Shipping Address'),
                const SizedBox(height: 8),
                TextField(controller: shippingStreetC, decoration: const InputDecoration(labelText: 'Shipping Street'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: shippingCityC, decoration: const InputDecoration(labelText: 'Shipping City'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: shippingStateC, decoration: const InputDecoration(labelText: 'Shipping State'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: shippingZipC, decoration: const InputDecoration(labelText: 'Shipping ZIP'), keyboardType: TextInputType.number),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}

// ---------------------------------------------------------------------------
// Customer Card Widget
// ---------------------------------------------------------------------------
class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;

  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final adaptive = AppColors.adaptive(context);

    final company = (customer['company'] ?? '').toString().trim();
    final contactName = (customer['contact_name'] ?? customer['contact_person'] ?? '').toString().trim();
    final name = company.isNotEmpty ? company : (contactName.isNotEmpty ? contactName : 'Unknown');
    final contact = company.isNotEmpty ? contactName : '';
    final phone = customer['phonenumber'] ?? customer['contact_phone'] ?? customer['phone'] ?? '';
    final email = customer['contact_email'] ?? customer['email'] ?? '';
    final city = (customer['city'] ?? '').toString().trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Determine if active
    final isActive = (customer['active'] ?? customer['status'] ?? '1').toString();
    final active = isActive == '1' || isActive.toLowerCase() == 'active';
    final accentColor = active ? AppColors.success : AppColors.textMuted;

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
                color: accentColor.withValues(alpha: 0.08),
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
                      color: accentColor,
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
                              color: accentColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(
                              initial,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accentColor),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Company name big
                                Text(name,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colorScheme.onSurface),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (contact.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(contact,
                                      style: TextStyle(fontSize: 12.5, color: adaptive.textSecondary, fontWeight: FontWeight.w500),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Active/Inactive badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        active ? 'Active' : 'Inactive',
                                        style: TextStyle(color: accentColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (city.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.location_on_outlined, size: 12, color: adaptive.textMuted),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(city,
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
                              ],
                              if (email.toString().isNotEmpty)
                                _CardIconButton(
                                  icon: Icons.mail_outline_rounded,
                                  color: AppColors.info,
                                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: email.toString())),
                                  tooltip: 'Email',
                                ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: adaptive.textSecondary)),
          ],
        ),
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
// Section Header (for add form)
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary));
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
