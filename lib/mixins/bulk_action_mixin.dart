import 'package:flutter/material.dart';

/// A mixin that adds bulk selection capabilities to any StatefulWidget.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with BulkActionMixin {
///   // Use isSelectionMode, selectedIds, toggleSelection(), etc.
/// }
/// ```
mixin BulkActionMixin<T extends StatefulWidget> on State<T> {
  bool isSelectionMode = false;
  final Set<String> selectedIds = {};

  /// Toggle selection of an item by its ID.
  /// Exits selection mode if the last item is deselected.
  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) isSelectionMode = false;
      } else {
        selectedIds.add(id);
      }
    });
  }

  /// Select all items from the given list of IDs.
  void selectAll(List<String> ids) {
    setState(() {
      isSelectionMode = true;
      selectedIds.addAll(ids);
    });
  }

  /// Clear all selections and exit selection mode.
  void clearSelection() {
    setState(() {
      selectedIds.clear();
      isSelectionMode = false;
    });
  }

  /// Enter selection mode with the first selected item.
  void enterSelectionMode(String firstId) {
    setState(() {
      isSelectionMode = true;
      selectedIds.add(firstId);
    });
  }

  /// Whether a specific item is currently selected.
  bool isSelected(String id) => selectedIds.contains(id);

  /// The number of currently selected items.
  int get selectedCount => selectedIds.length;

  /// Build a selection-aware AppBar that shows selection count
  /// and action buttons when in selection mode.
  AppBar buildSelectionAppBar({
    required String defaultTitle,
    required List<Widget> selectionActions,
    List<Widget>? defaultActions,
    PreferredSizeWidget? bottom,
  }) {
    if (isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: clearSelection,
        ),
        title: Text(
          '$selectedCount selected',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: selectionActions,
        bottom: bottom,
      );
    }
    return AppBar(
      title: Text(defaultTitle),
      actions: defaultActions,
      bottom: bottom,
    );
  }

  /// Build a checkbox widget for use in list items.
  Widget buildSelectionCheckbox(String id) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelectionMode ? 40 : 0,
      child: isSelectionMode
          ? Checkbox(
              value: isSelected(id),
              onChanged: (_) => toggleSelection(id),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
