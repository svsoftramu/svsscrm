import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';

class QuickLogFAB extends StatefulWidget {
  const QuickLogFAB({super.key});

  @override
  State<QuickLogFAB> createState() => _QuickLogFABState();
}

class _QuickLogFABState extends State<QuickLogFAB> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  void _logCall() {
    setState(() => _isExpanded = false);
    _showLogForm(context, 'call');
  }

  void _logMeeting() {
    setState(() => _isExpanded = false);
    _showLogForm(context, 'meeting');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded) ...[
          _MiniFab(
            icon: Icons.call_rounded,
            label: 'Log Call',
            color: AppColors.success,
            onTap: _logCall,
          ),
          const SizedBox(height: 8),
          _MiniFab(
            icon: Icons.people_rounded,
            label: 'Log Meeting',
            color: const Color(0xFF8B5CF6),
            onTap: _logMeeting,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: AppColors.primary,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showLogForm(BuildContext context, String type) {
    final subjectC = TextEditingController();
    final notesC = TextEditingController();
    final durationC = TextEditingController();
    String? selectedLeadId;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final provider = context.read<CRMProvider>();
          return DraggableScrollableSheet(
            expand: false, initialChildSize: 0.75, maxChildSize: 0.9,
            builder: (_, controller) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: type == 'call' ? AppColors.success.withValues(alpha: 0.1) : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          type == 'call' ? Icons.call_rounded : Icons.people_rounded,
                          color: type == 'call' ? AppColors.success : const Color(0xFF8B5CF6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(type == 'call' ? 'Log Call' : 'Log Meeting', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Lead selector
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Lead *', prefixIcon: Icon(Icons.person_rounded, size: 20)),
                    items: provider.leads.map((l) {
                      final name = l['name'] ?? '${l['first_name'] ?? ''} ${l['last_name'] ?? ''}'.trim();
                      return DropdownMenuItem<String>(value: l['id'].toString(), child: Text(name.toString(), overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (v) => selectedLeadId = v,
                  ),
                  const SizedBox(height: 14),

                  // Subject
                  TextField(controller: subjectC, decoration: InputDecoration(labelText: 'Subject *', prefixIcon: const Icon(Icons.subject_rounded, size: 20),
                      hintText: type == 'call' ? 'e.g., Follow-up call' : 'e.g., Product demo')),
                  const SizedBox(height: 14),

                  // Duration
                  TextField(
                    controller: durationC,
                    decoration: InputDecoration(labelText: 'Duration (minutes)', prefixIcon: const Icon(Icons.timer_rounded, size: 20),
                        hintText: type == 'call' ? 'e.g., 15' : 'e.g., 60'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, size: 20),
                    title: Text(DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate)),
                    subtitle: const Text('Date & Time'),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (date != null && ctx.mounted) {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                        if (time != null) {
                          setSheetState(() => selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true), maxLines: 3),
                  const SizedBox(height: 24),

                  // Save
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedLeadId == null || subjectC.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lead and subject are required'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        provider.logActivity(selectedLeadId!, {
                          'type': type,
                          'subject': subjectC.text.trim(),
                          'description': notesC.text.trim(),
                          'duration': durationC.text.trim(),
                          'date': selectedDate.toIso8601String(),
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${type == 'call' ? 'Call' : 'Meeting'} logged successfully'), backgroundColor: AppColors.success),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('Save ${type == 'call' ? 'Call' : 'Meeting'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniFab({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ]),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          onPressed: onTap,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}
