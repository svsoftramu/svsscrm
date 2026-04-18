import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../utils/status_helpers.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await Provider.of<CRMProvider>(context, listen: false).fetchDocuments();
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Color _statusColor(String? status) => documentStatusColor(status);

  IconData _typeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
      case 'jpg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
      case 'word':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'excel':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          final documents = provider.documents;

          if (documents.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (documents.isEmpty && provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.error!.replaceFirst('Exception: ', ''),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (documents.isEmpty) {
            return const Center(
              child: Text('No documents found.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                final name =
                    doc['name'] ?? doc['title'] ?? 'Untitled Document';
                final status = doc['status']?.toString();
                final type = doc['type']?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(
                        _typeIcon(type),
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      '$name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: type != null
                        ? Text(
                            _formatKey(type),
                            style: theme.textTheme.bodySmall,
                          )
                        : null,
                    trailing: status != null
                        ? Chip(
                            label: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            backgroundColor: _statusColor(status),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
