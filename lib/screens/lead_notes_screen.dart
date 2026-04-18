import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';

class LeadNotesScreen extends StatefulWidget {
  final String leadId;
  final String leadName;

  const LeadNotesScreen({super.key, required this.leadId, required this.leadName});

  @override
  State<LeadNotesScreen> createState() => _LeadNotesScreenState();
}

class _LeadNotesScreenState extends State<LeadNotesScreen> {
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      _notes = await context.read<CRMProvider>().fetchLeadNotes(widget.leadId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    _noteController.clear();
    FocusScope.of(context).unfocus();

    try {
      await context.read<CRMProvider>().addLeadNote(widget.leadId, content);
      await _loadNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add note: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CRMProvider>().deleteLeadNote(widget.leadId, noteId);
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes - ${widget.leadName}')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : _notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sticky_note_2_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No notes yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('Add a note below to get started', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final content = note['content'] ?? note['description'] ?? note['note'] ?? '';
                            final author = note['addedfrom_name'] ?? note['author'] ?? note['staff_name'] ?? '';
                            final dateStr = note['dateadded'] ?? note['created_at'] ?? '';
                            String formattedDate = '';
                            try {
                              if (dateStr.toString().isNotEmpty) {
                                formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(dateStr.toString()));
                              }
                            } catch (_) {
                              formattedDate = dateStr.toString();
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 16),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (author.toString().isNotEmpty)
                                                Text(author.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                              if (formattedDate.isNotEmpty)
                                                Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                          onPressed: () => _deleteNote(note['id']?.toString() ?? ''),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(content.toString(), style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          // Note input
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Type a note...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _addNote,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
