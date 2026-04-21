import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'face_capture_screen.dart';
import 'face_enrollment_screen.dart';
import 'attendance_report_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<CRMProvider>();
      p.fetchAttendanceToday();
      p.fetchAttendanceMonthly();
      p.checkFaceEnrollment();
    });
  }

  String _formatTime(dynamic value) {
    if (value == null) return '--:--';
    final str = value.toString();
    try {
      if (str.contains(' ') && str.length > 10) {
        return DateFormat('hh:mm a').format(DateTime.parse(str));
      }
      if (str.contains(':')) {
        final parts = str.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$h12:$minute $period';
      }
    } catch (_) {}
    return str;
  }

  Future<void> _doCheckIn(BuildContext context) async {
    final provider = context.read<CRMProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Get reference mesh for verification
    String? referenceMesh;
    if (provider.isFaceEnrolled) {
      referenceMesh = await provider.getReferenceMeshJson();
    }

    if (!mounted) return;

    final result = await navigator.push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(action: 'check_in', referenceMeshJson: referenceMesh),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      final response = await provider.checkIn(faceImage: result.base64Image, matchScore: result.matchScore, faceMeshData: result.meshJson);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Checked in successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _doCheckOut(BuildContext context) async {
    // Capture refs before async gaps
    final provider = context.read<CRMProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: Show mandatory work report dialog
    final reportResult = await _showWorkReportDialog(context);
    if (reportResult == null || !mounted) return; // User cancelled

    // Step 2: Face verification

    String? referenceMesh;
    if (provider.isFaceEnrolled) {
      referenceMesh = await provider.getReferenceMeshJson();
    }

    if (!mounted) return;

    final result = await navigator.push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(action: 'check_out', referenceMeshJson: referenceMesh),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      // Step 3: Submit work report
      await ApiService.instance.uploadFile(
        'attendance/work-report',
        reportResult['image_path'] ?? '',
        fields: {
          'tasks_completed': reportResult['tasks'] ?? '',
          'notes': reportResult['notes'] ?? '',
        },
      ).catchError((_) {
        // If image upload fails (no image), try without file
        return ApiService.instance.post('attendance/work-report', {
          'tasks_completed': reportResult['tasks'] ?? '',
          'notes': reportResult['notes'] ?? '',
        });
      });

      // Step 4: Do checkout
      final response = await provider.checkOut(faceImage: result.base64Image, matchScore: result.matchScore, faceMeshData: result.meshJson);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Checked out successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<Map<String, String>?> _showWorkReportDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final tasksC = TextEditingController();
    final notesC = TextEditingController();
    String? imagePath;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text('Daily Work Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submit your work report before checkout', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: tasksC,
                    decoration: const InputDecoration(
                      labelText: 'Tasks Completed *',
                      hintText: 'What did you work on today?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.task_alt_rounded, size: 20),
                    ),
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please describe tasks completed' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesC,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Blockers',
                      hintText: 'Any notes or issues?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_rounded, size: 20),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  const Text('Photo Attachment *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (imagePath != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(imagePath!), height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                              if (img != null) setDialogState(() => imagePath = img.path);
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                              if (img != null) setDialogState(() => imagePath = img.path);
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (imagePath == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please attach a photo'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'tasks': tasksC.text.trim(),
                  'notes': notesC.text.trim(),
                  'image_path': imagePath!,
                });
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Submit & Checkout'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.assessment_rounded, size: 20),
              tooltip: 'Attendance Report',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final today = provider.attendanceToday;
          final checkedIn = today['check_in'] != null || today['checkin_time'] != null;
          final checkedOut = today['check_out'] != null || today['checkout_time'] != null;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchAttendanceToday();
              await provider.fetchAttendanceMonthly();
              await provider.checkFaceEnrollment();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Enrollment banner
                if (!provider.isFaceEnrolled)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.face_rounded, color: AppColors.warning, size: 22),
                      ),
                      title: const Text('Face Not Enrolled', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Set up face recognition for attendance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final prov = context.read<CRMProvider>();
                          final enrolled = await nav.push<bool>(
                            MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                          );
                          if (enrolled == true && mounted) {
                            prov.checkFaceEnrollment();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Enroll'),
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Face enrolled - verification active',
                            style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),

                // Today's card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: checkedIn && !checkedOut
                          ? [AppColors.success, const Color(0xFF059669)]
                          : [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (checkedIn && !checkedOut ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.face_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Face Attendance', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 20),
                      if (today.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _TimeBox(label: 'Check In', time: _formatTime(today['check_in'] ?? today['checkin_time']), icon: Icons.login_rounded),
                            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                            _TimeBox(label: 'Check Out', time: _formatTime(today['check_out'] ?? today['checkout_time']), icon: Icons.logout_rounded),
                            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                            _TimeBox(
                              label: 'Hours',
                              time: today['working_hours'] != null
                                  ? '${double.tryParse(today['working_hours'].toString())?.toStringAsFixed(1) ?? '--'}h'
                                  : '--',
                              icon: Icons.timer_rounded,
                            ),
                          ],
                        ),
                      ] else
                        Text('No attendance data for today', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (checkedIn || _actionLoading) ? null : () => _doCheckIn(context),
                          icon: _actionLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.face_rounded, size: 20),
                          label: const Text('Check In'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.success.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (!checkedIn || checkedOut || _actionLoading) ? null : () => _doCheckOut(context),
                          icon: _actionLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.face_rounded, size: 20),
                          label: const Text('Check Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Monthly
                const Text('Monthly History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                if (provider.attendanceMonthly.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          const Text('No monthly data', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...provider.attendanceMonthly.map((record) {
                    final date = record['attendance_date'] ?? record['date'] ?? '';
                    final checkIn = _formatTime(record['check_in'] ?? record['checkin_time']);
                    final checkOut = _formatTime(record['check_out'] ?? record['checkout_time']);
                    final status = record['status'] ?? '';
                    final isPresent = status.toString().toLowerCase() == 'present';
                    final hours = record['working_hours'] ?? record['total_hours'];
                    final hoursStr = hours != null ? '${double.tryParse(hours.toString())?.toStringAsFixed(1) ?? '--'}h' : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isPresent ? AppColors.cardGreen : AppColors.cardRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isPresent ? AppColors.success : AppColors.error, size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(date.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('In: $checkIn  |  Out: $checkOut${hoursStr.isNotEmpty ? '  |  $hoursStr' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPresent ? AppColors.cardGreen : AppColors.cardRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: isPresent ? AppColors.success : AppColors.error)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;

  const _TimeBox({required this.label, required this.time, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}
