import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'leave_screen.dart';
import 'expenses_screen.dart';
import 'directory_screen.dart';
import 'projects_screen.dart';
import 'payslips_screen.dart';
import 'approvals_screen.dart';
import 'documents_screen.dart';
import 'login_screen.dart';
// import 'reports_screen.dart'; // Removed

import 'chat_list_screen.dart';
import 'task_calendar_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.userData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Profile header card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _push(context, const ProfileScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: user?['avatar'] != null ? NetworkImage(user!['avatar']) : null,
                          child: user?['avatar'] == null
                              ? Text((user?['firstname'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user?['firstname'] ?? ''} ${user?['lastname'] ?? ''}'.trim(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(user?['email'] ?? '',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ESS Section
          _SectionHeader(title: 'EMPLOYEE SELF SERVICE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  _MenuTile(icon: Icons.face_rounded, title: 'Face Attendance', color: AppColors.success,
                      onTap: () => _push(context, const AttendanceScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.calendar_month_rounded, title: 'Leaves', color: AppColors.accent,
                      onTap: () => _push(context, const LeaveScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.receipt_long_rounded, title: 'Payslips', color: AppColors.success,
                      onTap: () => _push(context, const PayslipsScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.account_balance_wallet_rounded, title: 'Expenses', color: const Color(0xFF78716C),
                      onTap: () => _push(context, const ExpensesScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.folder_copy_rounded, title: 'Documents', color: const Color(0xFF6366F1),
                      onTap: () => _push(context, const DocumentsScreen())),
                ],
              ),
            ),
          ),

          // CRM Section
          _SectionHeader(title: 'CRM'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  _MenuTile(icon: Icons.folder_rounded, title: 'Projects', color: const Color(0xFF8B5CF6),
                      onTap: () => _push(context, const ProjectsScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.calendar_month_rounded, title: 'Task Calendar', color: AppColors.primary,
                      onTap: () => _push(context, const TaskCalendarScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.chat_rounded, title: 'Team Chat', color: AppColors.success,
                      onTap: () => _push(context, const ChatListScreen())),
                ],
              ),
            ),
          ),

          // Team Section
          _SectionHeader(title: 'TEAM & ORGANIZATION'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  _MenuTile(icon: Icons.people_rounded, title: 'Employee Directory', color: AppColors.primary,
                      onTap: () => _push(context, const DirectoryScreen())),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(
                    icon: Icons.approval_rounded,
                    title: 'Pending Approvals',
                    color: AppColors.error,
                    badge: context.watch<CRMProvider>().pendingApprovals.length,
                    onTap: () => _push(context, const ApprovalsScreen()),
                  ),
                ],
              ),
            ),
          ),

          // Info Section
          _SectionHeader(title: 'INFORMATION'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    color: AppColors.warning,
                    badge: context.watch<CRMProvider>().unreadCount,
                    onTap: () => _push(context, const NotificationsScreen()),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.campaign_rounded, title: 'Announcements', color: const Color(0xFFEC4899),
                      onTap: () => _pushGenericList(context, 'Announcements', () => context.read<CRMProvider>().fetchAnnouncements(), () => context.read<CRMProvider>().announcements)),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(icon: Icons.event_rounded, title: 'Holidays', color: const Color(0xFF06B6D4),
                      onTap: () => _pushGenericList(context, 'Holidays', () => context.read<CRMProvider>().fetchHolidays(), () => context.read<CRMProvider>().holidays)),
                ],
              ),
            ),
          ),

          // Preferences Section
          _SectionHeader(title: 'PREFERENCES'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final currentMode = themeProvider.themeMode;
                  final label = switch (currentMode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  };
                  final icon = switch (currentMode) {
                    ThemeMode.light => Icons.light_mode_rounded,
                    ThemeMode.dark => Icons.dark_mode_rounded,
                    ThemeMode.system => Icons.brightness_auto_rounded,
                  };
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Appearance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    trailing: PopupMenuButton<ThemeMode>(
                      initialValue: currentMode,
                      onSelected: (mode) => themeProvider.setThemeMode(mode),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
                        PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        PopupMenuItem(value: ThemeMode.system, child: Text('System')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: _MenuTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                color: AppColors.error,
                onTap: () => _handleLogout(context),
                showArrow: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _pushGenericList(BuildContext context, String title, Future<void> Function() fetch, List<Map<String, dynamic>> Function() getData) {
    fetch();
    Navigator.push(context, MaterialPageRoute(builder: (_) => _GenericListScreen(title: title, getData: getData)));
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await PushNotificationService.instance.unregisterToken();
      await ApiService.instance.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.adaptive(context).textMuted, letterSpacing: 1.2)),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;
  final int badge;
  final bool showArrow;

  const _MenuTile({required this.icon, required this.title, required this.onTap, required this.color, this.badge = 0, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: showArrow
          ? (badge > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                )
              : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : AppColors.textMuted))
          : null,
      onTap: onTap,
    );
  }
}

class _GenericListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> Function() getData;

  const _GenericListScreen({required this.title, required this.getData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final data = getData();
          if (provider.isLoading && data.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: AppColors.adaptive(context).textMuted),
                  const SizedBox(height: 12),
                  Text('No $title found', style: TextStyle(color: AppColors.adaptive(context).textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final displayTitle = item['title'] ?? item['name'] ?? item['subject'] ?? item['leave_type'] ?? 'Item ${index + 1}';
              final subtitle = item['description'] ?? item['date'] ?? item['holiday_date'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(displayTitle.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: subtitle.toString().isNotEmpty ? Text(subtitle.toString(), style: TextStyle(color: AppColors.adaptive(context).textSecondary)) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
