import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'estimates_screen.dart';
import 'invoices_screen.dart';
import 'task_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'client_visits_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    final provider = context.read<CRMProvider>();
    await Future.wait([
      provider.fetchDashboard(),
      provider.fetchAttendanceToday(),
      provider.fetchTasks(),
      provider.fetchLeads(),
      provider.fetchAnnouncements(),
      provider.fetchHolidays(),
      provider.fetchUnreadCount(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.userData;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _loadAll,
            child: CustomScrollView(
              slivers: [
                // ─── Profile Header ───
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (user?['firstname'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$greeting,',
                                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w400),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${user?['firstname'] ?? ''} ${user?['lastname'] ?? ''}'.trim(),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                                      ),
                                    ],
                                  ),
                                ),
                                // Search
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                                  ),
                                ),
                                // Notification bell
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Badge(
                                      isLabelVisible: provider.unreadCount > 0,
                                      label: Text('${provider.unreadCount}', style: const TextStyle(fontSize: 10)),
                                      backgroundColor: AppColors.accent,
                                      child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                                    ),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy').format(now),
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Body ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Clock In/Out Card ───
                        _ClockInOutCard(provider: provider),
                        const SizedBox(height: 20),

                        // ─── Quick Actions ───
                        const _SectionTitle(title: 'Quick Actions'),
                        const SizedBox(height: 12),
                        _buildQuickActions(context),
                        const SizedBox(height: 24),

                        // ─── Today's Tasks (Todo) ───
                        const _SectionTitle(title: "Today's Tasks"),
                        const SizedBox(height: 12),
                        _TodaysTasks(tasks: provider.tasks),
                        const SizedBox(height: 24),

                        // ─── Sales Pipeline ───
                        const _SectionTitle(title: 'Sales Pipeline'),
                        const SizedBox(height: 12),
                        _SalesPipelineCard(leads: provider.leads),
                        const SizedBox(height: 24),

                        // ─── Today's Follow-ups ───
                        const _SectionTitle(title: "Today's Follow-ups"),
                        const SizedBox(height: 12),
                        _TodaysFollowups(tasks: provider.tasks),
                        const SizedBox(height: 24),

                        // ─── Overview Stats ───
                        if (provider.dashboardData.isNotEmpty) ...[
                          const _SectionTitle(title: 'Overview'),
                          const SizedBox(height: 12),
                          _buildDashboardStats(provider.dashboardData),
                          const SizedBox(height: 24),
                        ],

                        // ─── Recent Activity ───
                        const _SectionTitle(title: 'Recent Activity'),
                        const SizedBox(height: 12),
                        _RecentActivityCard(leads: provider.leads, tasks: provider.tasks),
                        const SizedBox(height: 24),

                        // ─── Announcements ───
                        if (provider.announcements.isNotEmpty) ...[
                          const _SectionTitle(title: 'Announcements'),
                          const SizedBox(height: 12),
                          _AnnouncementsCard(announcements: provider.announcements),
                          const SizedBox(height: 24),
                        ],

                        // ─── Upcoming Holidays ───
                        if (provider.holidays.isNotEmpty) ...[
                          const _SectionTitle(title: 'Upcoming Holidays'),
                          const SizedBox(height: 12),
                          _HolidaysCard(holidays: provider.holidays),
                        ],

                        if (provider.isLoading && provider.dashboardData.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),

                        if (provider.error != null && provider.dashboardData.isEmpty)
                          _buildErrorCard(provider.error!),

                        const SizedBox(height: 16),
                      ],
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

  /// Returns true if the user is currently clocked in (state 1).
  /// Shows a gate dialog and returns false otherwise.
  bool _requireCheckedIn(BuildContext context) {
    final provider = context.read<CRMProvider>();
    final today = provider.attendanceToday;
    final hasIn  = today['check_in'] != null || today['checkin_time'] != null;
    final hasOut = today['check_out'] != null || today['checkout_time'] != null;

    if (hasIn && !hasOut) return true; // working — allow

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
                color: (hasOut ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasOut ? Icons.check_circle_rounded : Icons.login_rounded,
                color: hasOut ? AppColors.success : AppColors.primary, size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasOut ? 'Day Completed' : 'Please Check In First',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasOut
                  ? 'You have already checked out for today.\nSee you tomorrow!'
                  : 'You need to clock in before accessing this section.',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!hasOut)
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Go to Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            SizedBox(
              width: double.infinity, height: 40,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickActionChip(
        icon: Icons.face_rounded,
        label: 'Attendance',
        color: AppColors.success,
        bgColor: AppColors.cardGreen,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      ),
      _QuickActionChip(
        icon: Icons.add_task_rounded,
        label: 'New Task',
        color: AppColors.primary,
        bgColor: AppColors.cardBlue,
        onTap: () { if (_requireCheckedIn(context)) showAddTaskSheet(context); },
      ),
      _QuickActionChip(
        icon: Icons.description_rounded,
        label: 'Estimates',
        color: const Color(0xFF8B5CF6),
        bgColor: AppColors.cardPurple,
        onTap: () { if (_requireCheckedIn(context)) Navigator.push(context, MaterialPageRoute(builder: (_) => const EstimatesScreen())); },
      ),
      _QuickActionChip(
        icon: Icons.receipt_long_rounded,
        label: 'Invoices',
        color: const Color(0xFF14B8A6),
        bgColor: AppColors.cardTeal,
        onTap: () { if (_requireCheckedIn(context)) Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen())); },
      ),
      _QuickActionChip(
        icon: Icons.location_on_rounded,
        label: 'Visits',
        color: const Color(0xFFEF4444),
        bgColor: AppColors.cardRed,
        onTap: () { if (_requireCheckedIn(context)) Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientVisitsScreen())); },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 30) / 4; // 4 per row, 3 gaps of 10
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((chip) => SizedBox(width: itemWidth, child: chip)).toList(),
        );
      },
    );
  }

  Widget _buildDashboardStats(Map<String, dynamic> data) {
    final statCards = <Widget>[];
    final iconMap = {
      'leads': Icons.person_add_alt_1_rounded, 'customers': Icons.people_rounded,
      'tasks': Icons.check_circle_outline_rounded, 'projects': Icons.folder_rounded,
      'invoices': Icons.receipt_long_rounded, 'estimates': Icons.description_rounded,
      'tickets': Icons.support_agent_rounded, 'expenses': Icons.account_balance_wallet_rounded,
      'revenue': Icons.currency_rupee_rounded,
      'total_leads': Icons.person_add_alt_1_rounded, 'total_customers': Icons.people_rounded,
      'total_tasks': Icons.check_circle_outline_rounded, 'total_projects': Icons.folder_rounded,
      'total_invoices': Icons.receipt_long_rounded, 'pending_tasks': Icons.pending_actions_rounded,
      'open_tickets': Icons.support_agent_rounded,
    };
    final colorMap = {
      'leads': AppColors.primary, 'customers': AppColors.success,
      'tasks': AppColors.accent, 'projects': const Color(0xFF8B5CF6),
      'invoices': const Color(0xFF14B8A6), 'estimates': const Color(0xFF6366F1),
      'tickets': AppColors.error, 'expenses': const Color(0xFF78716C),
      'revenue': const Color(0xFF7C3AED),
      'total_leads': AppColors.primary, 'total_customers': AppColors.success,
      'total_tasks': AppColors.accent, 'total_projects': const Color(0xFF8B5CF6),
      'total_invoices': const Color(0xFF14B8A6), 'pending_tasks': AppColors.warning,
      'open_tickets': AppColors.error,
    };
    final bgMap = {
      'leads': AppColors.cardBlue, 'customers': AppColors.cardGreen,
      'tasks': AppColors.cardOrange, 'projects': AppColors.cardPurple,
      'invoices': AppColors.cardTeal, 'tickets': AppColors.cardRed,
      'total_leads': AppColors.cardBlue, 'total_customers': AppColors.cardGreen,
      'total_tasks': AppColors.cardOrange, 'total_projects': AppColors.cardPurple,
      'pending_tasks': AppColors.cardOrange, 'open_tickets': AppColors.cardRed,
    };

    data.forEach((key, value) {
      if (value is num || (value is String && int.tryParse(value.toString()) != null)) {
        statCards.add(_StatCard(
          title: _formatKey(key),
          value: value.toString(),
          icon: iconMap[key] ?? Icons.analytics_rounded,
          color: colorMap[key] ?? AppColors.primary,
          bgColor: bgMap[key] ?? AppColors.cardBlue,
        ));
      } else if (value is Map) {
        value.forEach((subKey, subValue) {
          if (subValue is num) {
            statCards.add(_StatCard(
              title: '${_formatKey(key)} - ${_formatKey(subKey.toString())}',
              value: subValue.toString(),
              icon: iconMap[key] ?? Icons.analytics_rounded,
              color: colorMap[key] ?? AppColors.primary,
              bgColor: bgMap[key] ?? AppColors.cardBlue,
            ));
          }
        });
      }
    });

    if (statCards.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: statCards,
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.cardRed, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.cloud_off_rounded, size: 24, color: AppColors.error),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not load dashboard', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  error.replaceFirst('Exception: ', ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}

// ═══════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionTitle({required this.title, this.onSeeAll}); // ignore: unused_element_parameter

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// CLOCK IN/OUT CARD (Keka-style punch card)
// ═══════════════════════════════════════════════

class _ClockInOutCard extends StatelessWidget {
  final CRMProvider provider;

  const _ClockInOutCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final attendance = provider.attendanceToday;
    final isCheckedIn = attendance['check_in'] != null && attendance['check_out'] == null;
    final isDayCompleted = attendance['check_in'] != null && attendance['check_out'] != null;
    final checkInTime = attendance['check_in']?.toString();
    final checkOutTime = attendance['check_out']?.toString();
    final hoursWorked = attendance['hours_worked']?.toString() ?? attendance['total_hours']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCheckedIn
                    ? [AppColors.success, const Color(0xFF059669)]
                    : isDayCompleted
                        ? [AppColors.success, const Color(0xFF059669)]
                        : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isCheckedIn ? Icons.timer_rounded : isDayCompleted ? Icons.check_circle_rounded : Icons.login_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckedIn ? 'Clocked In' : (checkOutTime != null ? 'Day Completed' : 'Not Clocked In'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isCheckedIn ? AppColors.success : (checkOutTime != null ? AppColors.primary : AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                if (checkInTime != null)
                  Row(
                    children: [
                      _TimeChip(label: 'In', time: _formatTime(checkInTime), color: AppColors.success),
                      if (checkOutTime != null) ...[
                        const SizedBox(width: 8),
                        _TimeChip(label: 'Out', time: _formatTime(checkOutTime), color: AppColors.error),
                      ],
                      if (hoursWorked != null) ...[
                        const SizedBox(width: 8),
                        _TimeChip(label: 'Hrs', time: hoursWorked, color: AppColors.primary),
                      ],
                    ],
                  )
                else
                  const Text('Tap to mark your attendance', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          // Action button — hidden after day is completed
          if (!isDayCompleted)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCheckedIn ? AppColors.cardRed : AppColors.cardGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCheckedIn ? 'Clock Out' : 'Clock In',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isCheckedIn ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              ),
            )
          else
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      if (time.contains('T') || time.contains(' ')) {
        final dt = DateTime.tryParse(time);
        if (dt != null) return DateFormat('hh:mm a').format(dt);
      }
      return time.length > 5 ? time.substring(0, 5) : time;
    } catch (_) {
      return time;
    }
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String time;
  final Color color;

  const _TimeChip({required this.label, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $time',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// QUICK ACTION CHIP (Horizontal scroll)
// ═══════════════════════════════════════════════

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.color, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// TODAY'S TASKS (Todo list for the day)
// ═══════════════════════════════════════════════

class _TodaysTasks extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;

  const _TodaysTasks({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Filter tasks that are due today or not completed
    final todayTasks = tasks.where((t) {
      final statusId = (t['status'] ?? '0').toString();
      if (statusId == '5') return false; // skip completed
      final due = (t['duedate'] ?? t['due_date'] ?? t['startdate'] ?? '').toString();
      if (due.isEmpty) return false;
      return due.startsWith(today);
    }).toList();

    // Also get overdue incomplete tasks
    final overdueTasks = tasks.where((t) {
      final statusId = (t['status'] ?? '0').toString();
      if (statusId == '5') return false;
      final due = (t['duedate'] ?? t['due_date'] ?? '').toString();
      if (due.isEmpty) return false;
      try {
        final dueDate = DateTime.tryParse(due);
        if (dueDate == null) return false;
        return dueDate.isBefore(DateTime.now()) && !due.startsWith(today);
      } catch (_) {
        return false;
      }
    }).toList();

    final allTodoTasks = [...overdueTasks, ...todayTasks];

    if (allTodoTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.cardGreen, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No tasks for today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('You\'re all clear!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Summary header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.cardBlue, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('${allTodoTasks.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                const Text('pending', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (overdueTasks.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.cardRed, borderRadius: BorderRadius.circular(8)),
                    child: Text('${overdueTasks.length} overdue', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Task list
          ...allTodoTasks.take(5).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final task = entry.value;
            final name = task['name'] ?? task['subject'] ?? 'Untitled';
            final due = (task['duedate'] ?? task['due_date'] ?? '').toString();
            final isOverdue = due.isNotEmpty && !due.startsWith(today);
            final priority = task['priority']?.toString() ?? '';
            final statusId = (task['status'] ?? '0').toString();

            Color priorityColor = AppColors.textMuted;
            String priorityLabel = '';
            if (priority == '1' || priority.toLowerCase().contains('high') || priority.toLowerCase().contains('urgent')) {
              priorityColor = AppColors.error;
              priorityLabel = 'High';
            } else if (priority == '2' || priority.toLowerCase().contains('medium')) {
              priorityColor = AppColors.warning;
              priorityLabel = 'Medium';
            } else if (priority == '3' || priority.toLowerCase().contains('low')) {
              priorityColor = AppColors.success;
              priorityLabel = 'Low';
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Checkbox-style indicator
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOverdue ? AppColors.error : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: statusId == '4'
                            ? Icon(Icons.check_rounded, size: 14, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (isOverdue)
                                  Text('Overdue · ${_formatDate(due)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.error))
                                else
                                  Text('Due today', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                if (priorityLabel.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(priorityLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < allTodoTasks.take(5).length - 1)
                  const Divider(height: 1, indent: 50),
              ],
            );
          }),
          if (allTodoTasks.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '+ ${allTodoTasks.length - 5} more tasks',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.tryParse(date);
      if (dt != null) return DateFormat('dd MMM').format(dt);
    } catch (_) {}
    return date;
  }
}

// ═══════════════════════════════════════════════
// SALES PIPELINE CARD (CRM adaptation of Keka attendance summary)
// ═══════════════════════════════════════════════

class _SalesPipelineCard extends StatelessWidget {
  final List<Map<String, dynamic>> leads;

  const _SalesPipelineCard({required this.leads});

  @override
  Widget build(BuildContext context) {
    // Count leads by status
    int newLeads = 0, contacted = 0, qualified = 0, proposal = 0, won = 0, lost = 0;
    for (final lead in leads) {
      final status = (lead['status'] ?? lead['lead_status'] ?? '').toString().toLowerCase();
      if (status.contains('new') || status.contains('1') || status.isEmpty) {
        newLeads++;
      } else if (status.contains('contact')) {
        contacted++;
      } else if (status.contains('qualif')) {
        qualified++;
      } else if (status.contains('propos') || status.contains('negotiat')) {
        proposal++;
      } else if (status.contains('won') || status.contains('convert') || status.contains('close') || status.contains('5')) {
        won++;
      } else if (status.contains('lost') || status.contains('dead') || status.contains('6')) {
        lost++;
      } else {
        newLeads++;
      }
    }

    final total = leads.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Total leads bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.cardBlue, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              const Text('Total Leads', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              if (won > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.cardGreen, borderRadius: BorderRadius.circular(8)),
                  child: Text('$won Won', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Pipeline progress bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (newLeads > 0) Expanded(flex: newLeads, child: Container(color: AppColors.primary)),
                    if (contacted > 0) Expanded(flex: contacted, child: Container(color: AppColors.info)),
                    if (qualified > 0) Expanded(flex: qualified, child: Container(color: AppColors.warning)),
                    if (proposal > 0) Expanded(flex: proposal, child: Container(color: AppColors.accent)),
                    if (won > 0) Expanded(flex: won, child: Container(color: AppColors.success)),
                    if (lost > 0) Expanded(flex: lost, child: Container(color: AppColors.error)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Stage chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PipelineChip(label: 'New', count: newLeads, color: AppColors.primary),
              _PipelineChip(label: 'Contacted', count: contacted, color: AppColors.info),
              _PipelineChip(label: 'Qualified', count: qualified, color: AppColors.warning),
              _PipelineChip(label: 'Proposal', count: proposal, color: AppColors.accent),
              _PipelineChip(label: 'Won', count: won, color: AppColors.success),
              _PipelineChip(label: 'Lost', count: lost, color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _PipelineChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PipelineChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// TODAY'S FOLLOW-UPS (CRM adaptation of Keka pending actions)
// ═══════════════════════════════════════════════

class _TodaysFollowups extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;

  const _TodaysFollowups({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayTasks = tasks.where((t) {
      final due = (t['duedate'] ?? t['due_date'] ?? t['startdate'] ?? '').toString();
      return due.startsWith(today);
    }).toList();

    // Also get overdue tasks
    final overdue = tasks.where((t) {
      final due = (t['duedate'] ?? t['due_date'] ?? '').toString();
      if (due.isEmpty) return false;
      try {
        final dueDate = DateTime.tryParse(due);
        if (dueDate == null) return false;
        return dueDate.isBefore(DateTime.now()) && !due.startsWith(today);
      } catch (_) {
        return false;
      }
    }).toList();

    final pending = [...overdue, ...todayTasks].take(5).toList();

    if (pending.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.cardGreen, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All caught up!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('No follow-ups due today', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          ...pending.asMap().entries.map((entry) {
            final i = entry.key;
            final task = entry.value;
            final name = task['name'] ?? task['subject'] ?? 'Untitled';
            final due = (task['duedate'] ?? task['due_date'] ?? '').toString();
            final isOverdue = due.isNotEmpty && !due.startsWith(today);
            final priority = task['priority']?.toString() ?? '';

            Color priorityColor = AppColors.textMuted;
            if (priority == '1' || priority.toLowerCase().contains('high') || priority.toLowerCase().contains('urgent')) {
              priorityColor = AppColors.error;
            } else if (priority == '2' || priority.toLowerCase().contains('medium')) {
              priorityColor = AppColors.warning;
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isOverdue ? AppColors.cardRed : AppColors.cardBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isOverdue ? Icons.warning_amber_rounded : Icons.task_alt_rounded,
                          color: isOverdue ? AppColors.error : AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (isOverdue)
                                  const Text('Overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.error))
                                else
                                  const Text('Due today', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                if (priority.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < pending.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            );
          }),
          if (overdue.length + todayTasks.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '+ ${overdue.length + todayTasks.length - 5} more',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RECENT ACTIVITY CARD (CRM adaptation of Keka announcements)
// ═══════════════════════════════════════════════

class _RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> leads;
  final List<Map<String, dynamic>> tasks;

  const _RecentActivityCard({required this.leads, required this.tasks});

  @override
  Widget build(BuildContext context) {
    // Build activity items from recent leads and tasks
    final activities = <_ActivityItem>[];

    for (final lead in leads.take(3)) {
      final name = lead['name'] ?? lead['company'] ?? 'Unknown';
      final status = lead['status'] ?? lead['lead_status'] ?? '';
      final date = lead['dateadded'] ?? lead['created_at'] ?? '';
      activities.add(_ActivityItem(
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.primary,
        title: 'Lead: $name',
        subtitle: 'Status: ${_formatStatus(status.toString())}',
        time: _formatDate(date.toString()),
      ));
    }

    for (final task in tasks.take(3)) {
      final name = task['name'] ?? task['subject'] ?? 'Untitled';
      final statusId = task['status']?.toString() ?? '0';
      final date = task['dateadded'] ?? task['created_at'] ?? '';
      activities.add(_ActivityItem(
        icon: Icons.task_alt_rounded,
        color: AppColors.accent,
        title: 'Task: $name',
        subtitle: statusId == '5' ? 'Completed' : 'In progress',
        time: _formatDate(date.toString()),
      ));
    }

    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No recent activity', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: activities.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(item.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (item.time.isNotEmpty)
                      Text(item.time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (i < activities.length - 1)
                const Divider(height: 1, indent: 64),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'New';
    return status.replaceAll('_', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(date);
      if (dt == null) return date;
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return date;
    }
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  _ActivityItem({required this.icon, required this.color, required this.title, required this.subtitle, required this.time});
}

// ═══════════════════════════════════════════════
// ANNOUNCEMENTS CARD
// ═══════════════════════════════════════════════

class _AnnouncementsCard extends StatelessWidget {
  final List<Map<String, dynamic>> announcements;

  const _AnnouncementsCard({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final items = announcements.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.cardPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFF8B5CF6), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title']?.toString() ?? a['subject']?.toString() ?? 'Announcement',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (a['message'] != null || a['description'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              (a['message'] ?? a['description'] ?? '').toString(),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1, indent: 64),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// HOLIDAYS CARD
// ═══════════════════════════════════════════════

class _HolidaysCard extends StatelessWidget {
  final List<Map<String, dynamic>> holidays;

  const _HolidaysCard({required this.holidays});

  @override
  Widget build(BuildContext context) {
    // Filter upcoming holidays
    final now = DateTime.now();
    final upcoming = holidays.where((h) {
      final date = DateTime.tryParse(h['date']?.toString() ?? h['holiday_date']?.toString() ?? '');
      return date != null && (date.isAfter(now) || DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now));
    }).take(4).toList();

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('No upcoming holidays', style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: upcoming.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          final dateStr = h['date']?.toString() ?? h['holiday_date']?.toString() ?? '';
          final dt = DateTime.tryParse(dateStr);
          final name = h['name']?.toString() ?? h['title']?.toString() ?? 'Holiday';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Date badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dt != null) ...[
                            Text(DateFormat('dd').format(dt), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent, height: 1)),
                            Text(DateFormat('MMM').format(dt), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.accent)),
                          ] else
                            const Icon(Icons.event_rounded, color: AppColors.accent, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (dt != null) ...[
                            const SizedBox(height: 2),
                            Text(DateFormat('EEEE').format(dt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < upcoming.length - 1) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// STAT CARD (Existing, refined)
// ═══════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
