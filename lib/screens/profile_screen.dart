import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CRMProvider>().fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localUser = ApiService.instance.userData;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final profile = provider.profile.isNotEmpty ? provider.profile : (localUser ?? {});

          if (profile.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final name = '${profile['firstname'] ?? profile['first_name'] ?? ''} ${profile['lastname'] ?? profile['last_name'] ?? ''}'.trim();
          final avatar = profile['avatar'] ?? profile['profile_image'];

          return RefreshIndicator(
            onRefresh: () => provider.fetchProfile(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: avatar != null ? NetworkImage(avatar.toString()) : null,
                          child: avatar == null
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w700))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      if (profile['email'] != null) ...[
                        const SizedBox(height: 4),
                        Text(profile['email'].toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal Information
                ..._buildSection(context, 'Personal Information', [
                  _ProfileField(key: 'firstname', label: 'First Name', icon: Icons.person_rounded, profile: profile),
                  _ProfileField(key: 'lastname', label: 'Last Name', icon: Icons.person_rounded, profile: profile),
                  _ProfileField(key: 'email', label: 'Email', icon: Icons.mail_outline_rounded, profile: profile),
                  _ProfileField(key: 'phonenumber', label: 'Phone', icon: Icons.phone_rounded, profile: profile, altKeys: ['phone', 'mobile']),
                  _ProfileField(key: 'date_of_birth', label: 'Date of Birth', icon: Icons.cake_rounded, profile: profile, altKeys: ['dob', 'birthday'], isDate: true),
                  _ProfileField(key: 'gender', label: 'Gender', icon: Icons.wc_rounded, profile: profile),
                  _ProfileField(key: 'blood_group', label: 'Blood Group', icon: Icons.water_drop_rounded, profile: profile),
                  _ProfileField(key: 'marital_status', label: 'Marital Status', icon: Icons.favorite_rounded, profile: profile),
                ]),

                // Employment Details
                ..._buildSection(context, 'Employment Details', [
                  _ProfileField(key: 'designation', label: 'Designation', icon: Icons.badge_rounded, profile: profile, altKeys: ['role', 'position', 'job_title']),
                  _ProfileField(key: 'department', label: 'Department', icon: Icons.business_rounded, profile: profile, altKeys: ['department_name']),
                  _ProfileField(key: 'employee_id', label: 'Employee ID', icon: Icons.numbers_rounded, profile: profile, altKeys: ['emp_id', 'staffid']),
                  _ProfileField(key: 'date_of_joining', label: 'Date of Joining', icon: Icons.calendar_today_rounded, profile: profile, altKeys: ['joining_date', 'datecreated', 'created'], isDate: true),
                  _ProfileField(key: 'reporting_to', label: 'Reporting To', icon: Icons.supervisor_account_rounded, profile: profile, altKeys: ['manager', 'reporting_manager']),
                  _ProfileField(key: 'employment_type', label: 'Employment Type', icon: Icons.work_rounded, profile: profile, altKeys: ['job_type']),
                  _ProfileField(key: 'status', label: 'Status', icon: Icons.toggle_on_rounded, profile: profile, formatFn: _formatStatus),
                ]),

                // Contact & Address
                ..._buildSection(context, 'Contact & Address', [
                  _ProfileField(key: 'address', label: 'Address', icon: Icons.location_on_rounded, profile: profile, altKeys: ['street', 'address_line_1']),
                  _ProfileField(key: 'city', label: 'City', icon: Icons.location_city_rounded, profile: profile),
                  _ProfileField(key: 'state', label: 'State', icon: Icons.map_rounded, profile: profile),
                  _ProfileField(key: 'country', label: 'Country', icon: Icons.public_rounded, profile: profile),
                  _ProfileField(key: 'zip', label: 'ZIP Code', icon: Icons.pin_drop_rounded, profile: profile, altKeys: ['zipcode', 'pincode', 'postal_code']),
                  _ProfileField(key: 'emergency_contact', label: 'Emergency Contact', icon: Icons.emergency_rounded, profile: profile, altKeys: ['emergency_phone']),
                ]),

                // Bank & Tax
                ..._buildSection(context, 'Bank & Tax Information', [
                  _ProfileField(key: 'bank_name', label: 'Bank Name', icon: Icons.account_balance_rounded, profile: profile),
                  _ProfileField(key: 'bank_account_number', label: 'Account Number', icon: Icons.credit_card_rounded, profile: profile, altKeys: ['account_number']),
                  _ProfileField(key: 'ifsc_code', label: 'IFSC Code', icon: Icons.numbers_rounded, profile: profile, altKeys: ['ifsc']),
                  _ProfileField(key: 'pan_number', label: 'PAN Number', icon: Icons.badge_rounded, profile: profile, altKeys: ['pan']),
                  _ProfileField(key: 'aadhaar_number', label: 'Aadhaar Number', icon: Icons.fingerprint_rounded, profile: profile, altKeys: ['aadhaar', 'aadhar']),
                  _ProfileField(key: 'uan_number', label: 'UAN Number', icon: Icons.account_box_rounded, profile: profile, altKeys: ['uan', 'pf_number', 'epf_number']),
                  _ProfileField(key: 'esi_number', label: 'ESI Number', icon: Icons.health_and_safety_rounded, profile: profile, altKeys: ['esi']),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSection(BuildContext context, String title, List<_ProfileField> fields) {
    // Only include fields that have values
    final validFields = fields.where((f) => f.value != null && f.value!.isNotEmpty).toList();
    if (validFields.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
      ),
      Card(
        child: Column(
          children: validFields.asMap().entries.map((entry) {
            final f = entry.value;
            final isLast = entry.key == validFields.length - 1;
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(f.icon, color: AppColors.primary, size: 18),
                  ),
                  title: Text(f.label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  subtitle: Text(f.displayValue, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                ),
                if (!isLast) const Divider(height: 1, indent: 56),
              ],
            );
          }).toList(),
        ),
      ),
    ];
  }

  String _formatStatus(String value) {
    switch (value.toLowerCase()) {
      case '1': case 'active': return 'Active';
      case '0': case 'inactive': return 'Inactive';
      case '2': case 'suspended': return 'Suspended';
      default: return value;
    }
  }
}

class _ProfileField {
  final String key;
  final String label;
  final IconData icon;
  final Map<String, dynamic> profile;
  final List<String> altKeys;
  final bool isDate;
  final String Function(String)? formatFn;

  _ProfileField({
    required this.key,
    required this.label,
    required this.icon,
    required this.profile,
    this.altKeys = const [],
    this.isDate = false,
    this.formatFn,
  });

  String? get value {
    // Try primary key first, then alternate keys
    for (final k in [key, ...altKeys]) {
      final v = profile[k];
      if (v != null && v.toString().trim().isNotEmpty && v.toString() != '0' && v.toString() != 'null') {
        // Skip internal-looking values (hashes, long random strings)
        final str = v.toString().trim();
        if (str.length > 60 && !str.contains(' ')) return null;
        return str;
      }
    }
    return null;
  }

  String get displayValue {
    final raw = value ?? '';
    if (raw.isEmpty) return '';

    if (formatFn != null) return formatFn!(raw);

    if (isDate) {
      try {
        final dt = DateTime.tryParse(raw);
        if (dt != null) {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
        }
      } catch (_) {}
    }

    return raw;
  }
}
