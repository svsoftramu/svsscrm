import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Provider.of<CRMProvider>(context, listen: false).fetchDirectory();
  }


  List<Map<String, dynamic>> _filteredDirectory(
      List<Map<String, dynamic>> directory) {
    if (_searchQuery.isEmpty) return directory;
    final query = _searchQuery.toLowerCase();
    return directory.where((record) {
      final firstName = (record['firstname'] ?? '').toString().toLowerCase();
      final lastName = (record['lastname'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName';
      final email = (record['email'] ?? '').toString().toLowerCase();
      final department =
          (record['department_name'] ?? '').toString().toLowerCase();
      return firstName.contains(query) ||
          lastName.contains(query) ||
          fullName.contains(query) ||
          email.contains(query) ||
          department.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<CRMProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.error!,
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

          final directory = provider.directory;

          if (directory.isEmpty) {
            return const Center(
              child: Text('No employees found.'),
            );
          }

          final filtered = _filteredDirectory(directory);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or department...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No matching employees found.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final record = filtered[index];
                            final firstName =
                                record['firstname']?.toString() ?? '';
                            final lastName =
                                record['lastname']?.toString() ?? '';
                            final email = record['email']?.toString() ?? '';
                            final phone =
                                record['phonenumber']?.toString() ?? '';
                            final department =
                                record['department_name']?.toString() ?? '';
                            final avatarUrl = record['avatar']?.toString();
                            final initials = firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : '?';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundImage: avatarUrl != null &&
                                          avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          initials,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  '$firstName $lastName',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (email.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.email_outlined,
                                              size: 14,
                                              color: theme.colorScheme.outline),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style:
                                                  theme.textTheme.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (phone.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.phone_outlined,
                                              size: 14,
                                              color: theme.colorScheme.outline),
                                          const SizedBox(width: 4),
                                          Text(
                                            phone,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    if (department.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.business_outlined,
                                              size: 14,
                                              color: theme.colorScheme.outline),
                                          const SizedBox(width: 4),
                                          Text(
                                            department,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
