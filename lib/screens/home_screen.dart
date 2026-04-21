import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import '../widgets/quick_log_fab.dart';
import 'dashboard_screen.dart';
import 'leads_screen.dart';
import 'customer_list_screen.dart';
import 'task_screen.dart';
import 'more_screen.dart';
import 'attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    LeadsScreen(),
    CustomerListScreen(),
    TaskScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<CRMProvider>();
      p.fetchUnreadCount();
      p.fetchAttendanceToday();
    });
  }

  /// Check attendance state: 0 = not clocked in, 1 = clocked in (working), 2 = day completed
  int _getAttendanceState(CRMProvider provider) {
    final today = provider.attendanceToday;
    final hasCheckIn = today['check_in'] != null || today['checkin_time'] != null;
    final hasCheckOut = today['check_out'] != null || today['checkout_time'] != null;
    if (hasCheckIn && hasCheckOut) return 2; // day completed
    if (hasCheckIn) return 1; // working
    return 0; // not clocked in
  }

  void _onTabSelected(int index, int attendanceState) {
    // Dashboard (index 0) is always accessible
    if (index == 0) {
      setState(() => _currentIndex = index);
      return;
    }

    if (attendanceState == 0) {
      // Not clocked in
      _showAttendanceGate(
        icon: Icons.login_rounded,
        color: AppColors.primary,
        title: 'Please Check In First',
        message: 'You need to clock in before accessing this section.',
        buttonText: 'Go to Attendance',
      );
    } else if (attendanceState == 2) {
      // Day completed
      _showAttendanceGate(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        title: 'Day Completed',
        message: 'You have already checked out for today.\nSee you tomorrow!',
        buttonText: null,
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  void _showAttendanceGate({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String? buttonText,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (buttonText != null)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CRMProvider>(
      builder: (context, provider, _) {
        final attendanceState = _getAttendanceState(provider);

        return Scaffold(
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _screens[_currentIndex],
                ),
              ),
            ],
          ),
          floatingActionButton: _currentIndex <= 1 && attendanceState == 1 ? const QuickLogFAB() : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => _onTabSelected(index, attendanceState),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Dashboard',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_add_alt_1_outlined),
                  selectedIcon: Icon(Icons.person_add_alt_1),
                  label: 'Leads',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Customers',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.check_circle_outline_rounded),
                  selectedIcon: Icon(Icons.check_circle_rounded),
                  label: 'Tasks',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: provider.unreadCount > 0,
                    label: Text('${provider.unreadCount}'),
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.menu_rounded),
                  ),
                  selectedIcon: const Icon(Icons.menu_rounded),
                  label: 'More',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
