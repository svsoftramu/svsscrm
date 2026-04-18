import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final provider = context.read<CRMProvider>();
      final results = await provider.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _hasSearched = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _hasSearched = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search leads, customers, tasks...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            hintStyle: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 20),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (!_hasSearched) {
      return const EmptyStateWidget(
        icon: Icons.search_rounded,
        title: 'Search',
        subtitle: 'Search leads, customers, tasks...',
      );
    }

    if (_results.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = _results[index];
        final name = item['name'] ?? item['title'] ?? '';
        final subtitle = item['email'] ?? item['phone'] ?? item['description'] ?? '';
        final type = item['type'] ?? '';

        return ListTile(
          title: Text(
            name.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: subtitle.toString().isNotEmpty
              ? Text(
                  subtitle.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: type.toString().isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeColor(type.toString()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _badgeTextColor(type.toString()),
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Color _badgeColor(String type) {
    switch (type.toLowerCase()) {
      case 'lead':
        return AppColors.cardBlue;
      case 'customer':
        return AppColors.cardGreen;
      case 'task':
        return AppColors.cardOrange;
      case 'project':
        return AppColors.cardPurple;
      default:
        return AppColors.surfaceVariant;
    }
  }

  Color _badgeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'lead':
        return AppColors.primary;
      case 'customer':
        return AppColors.success;
      case 'task':
        return AppColors.accent;
      case 'project':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textSecondary;
    }
  }
}
