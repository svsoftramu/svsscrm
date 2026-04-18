import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ClientVisitsScreen extends StatefulWidget {
  const ClientVisitsScreen({super.key});

  @override
  State<ClientVisitsScreen> createState() => _ClientVisitsScreenState();
}

class _ClientVisitsScreenState extends State<ClientVisitsScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiService.instance.get('client-visits');
      final data = res['data'];
      if (mounted) {
        setState(() {
          _visits = data is List ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
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

  void _showAddVisitSheet() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _AddVisitScreen(onSaved: _fetchVisits)));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
      case 'in progress':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _purposeIcon(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'meeting':
        return Icons.people_rounded;
      case 'demo':
        return Icons.laptop_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'follow_up':
      case 'follow-up':
        return Icons.follow_the_signs_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Visits'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _fetchVisits, splashRadius: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null && _visits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchVisits, child: const Text('Retry')),
                    ],
                  ),
                )
              : _visits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(24)),
                            child: const Icon(Icons.location_off_rounded, size: 48, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 16),
                          const Text('No visits logged yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('Tap + to log your first client visit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchVisits,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _visits.length,
                        itemBuilder: (context, index) {
                          final v = _visits[index];
                          final purpose = (v['purpose'] ?? 'visit').toString();
                          final status = (v['status'] ?? 'planned').toString();
                          final clientName = (v['client_name'] ?? v['company'] ?? 'Unknown Client').toString();
                          final notes = (v['notes'] ?? '').toString();
                          final address = (v['address'] ?? '').toString();
                          final visitDate = _formatDate((v['visit_date'] ?? v['created_at'] ?? '').toString());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: InkWell(
                              onTap: () => _showVisitDetail(v),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_purposeIcon(purpose), color: _statusColor(status), size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${purpose[0].toUpperCase()}${purpose.substring(1).replaceAll('_', ' ')} - $visitDate',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (address.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVisitSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('New Visit', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showVisitDetail(Map<String, dynamic> visit) {
    final purpose = (visit['purpose'] ?? 'visit').toString();
    final status = (visit['status'] ?? 'planned').toString();
    final clientName = (visit['client_name'] ?? visit['company'] ?? 'Unknown').toString();
    final notes = (visit['notes'] ?? '').toString();
    final address = (visit['address'] ?? '').toString();
    final lat = visit['latitude']?.toString() ?? '';
    final lng = visit['longitude']?.toString() ?? '';
    final checkInTime = visit['check_in_time']?.toString() ?? '';
    final checkOutTime = visit['check_out_time']?.toString() ?? '';
    final visitDate = (visit['visit_date'] ?? visit['created_at'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
                child: Icon(_purposeIcon(purpose), size: 30, color: _statusColor(status)),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(clientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor(status))),
              ),
            ),
            const SizedBox(height: 24),
            _DetailRow(icon: Icons.category_rounded, label: 'Purpose', value: purpose[0].toUpperCase() + purpose.substring(1).replaceAll('_', ' ')),
            _DetailRow(icon: Icons.calendar_today_rounded, label: 'Visit Date', value: _formatDate(visitDate)),
            if (checkInTime.isNotEmpty) _DetailRow(icon: Icons.login_rounded, label: 'Check-in', value: _formatDate(checkInTime)),
            if (checkOutTime.isNotEmpty) _DetailRow(icon: Icons.logout_rounded, label: 'Check-out', value: _formatDate(checkOutTime)),
            if (address.isNotEmpty) _DetailRow(icon: Icons.location_on_rounded, label: 'Address', value: address),
            if (lat.isNotEmpty && lng.isNotEmpty) _DetailRow(icon: Icons.gps_fixed_rounded, label: 'Coordinates', value: '$lat, $lng'),
            if (notes.isNotEmpty) _DetailRow(icon: Icons.note_rounded, label: 'Notes', value: notes),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ADD VISIT SCREEN
// ═══════════════════════════════════════════════

class _AddVisitScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddVisitScreen({required this.onSaved});

  @override
  State<_AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<_AddVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameC = TextEditingController();
  final _notesC = TextEditingController();
  final _meetingNotesC = TextEditingController();

  String _purpose = 'meeting';
  Position? _position;
  String _address = '';
  bool _gettingLocation = false;
  bool _submitting = false;
  final List<String> _photoPaths = [];
  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;

  static const _purposes = ['meeting', 'demo', 'support', 'delivery', 'follow_up', 'other'];

  @override
  void initState() {
    super.initState();
    _getLocation();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _clientNameC.dispose();
    _notesC.dispose();
    _meetingNotesC.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await ApiService.instance.get('crm/customers');
      final data = res['data'];
      if (data is List && mounted) {
        setState(() {
          _customers = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable GPS.'), backgroundColor: AppColors.warning),
          );
        }
        setState(() => _gettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied'), backgroundColor: AppColors.error),
            );
          }
          setState(() => _gettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Please enable in settings.'), backgroundColor: AppColors.error),
          );
        }
        setState(() => _gettingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      String addr = '';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addr = [p.street, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
      } catch (_) {
        addr = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }

      if (mounted) {
        setState(() {
          _position = pos;
          _address = addr;
          _gettingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gettingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoPaths.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos allowed'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 70);
    if (img != null && mounted) {
      setState(() => _photoPaths.add(img.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for GPS location or tap the refresh button'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, String>{
        'purpose': _purpose,
        'client_name': _clientNameC.text.trim(),
        'notes': _notesC.text.trim(),
        'meeting_notes': _meetingNotesC.text.trim(),
        'latitude': _position!.latitude.toString(),
        'longitude': _position!.longitude.toString(),
        'address': _address,
        'visit_date': DateTime.now().toIso8601String(),
      };
      if (_selectedCustomerId != null) {
        data['customer_id'] = _selectedCustomerId!;
      }

      // Upload with photos if any
      if (_photoPaths.isNotEmpty) {
        await ApiService.instance.uploadFile(
          'client-visits',
          _photoPaths.first,
          fields: data,
        );
      } else {
        await ApiService.instance.post('client-visits', data);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit logged successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Visit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GPS Location card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _position != null
                      ? [AppColors.success, const Color(0xFF059669)]
                      : [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _gettingLocation
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Getting GPS location...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _position != null ? 'Location Captured' : 'Location Not Available',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            IconButton(
                              onPressed: _getLocation,
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (_address.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_address, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                        if (_position != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // Client selection
            const Text('Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (_customers.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedCustomerId, // ignore: deprecated_member_use
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select existing client...')),
                  ..._customers.map((c) {
                    final id = (c['id'] ?? c['userid'] ?? '').toString();
                    final name = (c['company'] ?? c['contact_name'] ?? '').toString();
                    return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (val) {
                  setState(() => _selectedCustomerId = val);
                  if (val != null) {
                    final c = _customers.firstWhere(
                      (c) => (c['id'] ?? c['userid'] ?? '').toString() == val,
                      orElse: () => {},
                    );
                    if (c.isNotEmpty) {
                      _clientNameC.text = (c['company'] ?? c['contact_name'] ?? '').toString();
                    }
                  }
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.business_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNameC,
              decoration: const InputDecoration(
                labelText: 'Client / Company Name *',
                prefixIcon: Icon(Icons.person_rounded, size: 20),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Client name is required' : null,
            ),
            const SizedBox(height: 16),

            // Purpose
            const Text('Visit Purpose', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _purposes.map((p) {
                final isSelected = _purpose == p;
                final label = p[0].toUpperCase() + p.substring(1).replaceAll('_', ' ');
                return GestureDetector(
                  onTap: () => setState(() => _purpose = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(label, style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesC,
              decoration: const InputDecoration(
                labelText: 'Visit Notes',
                hintText: 'What is the purpose of this visit?',
                prefixIcon: Icon(Icons.note_rounded, size: 20),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Meeting notes
            TextFormField(
              controller: _meetingNotesC,
              decoration: const InputDecoration(
                labelText: 'Meeting Notes',
                hintText: 'Key discussion points, decisions, action items...',
                prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Photos
            const Text('Photos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoPaths.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(entry.value), width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _photoPaths.removeAt(entry.key)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded, color: AppColors.textMuted, size: 24),
                          const SizedBox(height: 4),
                          Text('${_photoPaths.length}/5', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
