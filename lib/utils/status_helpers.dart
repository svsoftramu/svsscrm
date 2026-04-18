import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized status label + color mappings.
///
/// All screens should use these instead of inline switch statements.
/// Unknown codes fall back gracefully instead of crashing.

// ─── Task Status ───

const Map<String, String> _taskStatusLabels = {
  '1': 'Not Started',
  '2': 'In Progress',
  '3': 'Testing',
  '4': 'Awaiting Feedback',
  '5': 'Completed',
};

const Map<String, Color> _taskStatusColors = {
  '1': AppColors.textMuted,
  '2': AppColors.primary,
  '3': AppColors.accent,
  '4': Color(0xFF8B5CF6),
  '5': AppColors.success,
};

String taskStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Unknown';
  return _taskStatusLabels[status] ?? status;
}

Color taskStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.textMuted;
  return _taskStatusColors[status] ?? AppColors.textMuted;
}

// ─── Invoice Status ───

const Map<String, String> _invoiceStatusLabels = {
  '1': 'Unpaid',
  '2': 'Paid',
  '3': 'Partially Paid',
  '4': 'Overdue',
  '5': 'Cancelled',
  '6': 'Draft',
};

const Map<String, Color> _invoiceStatusColors = {
  '1': AppColors.error,
  '2': AppColors.success,
  '3': AppColors.warning,
  '4': AppColors.error,
  '5': AppColors.textMuted,
  '6': AppColors.textMuted,
};

String invoiceStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Unpaid';
  return _invoiceStatusLabels[status] ?? status;
}

Color invoiceStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.warning;
  return _invoiceStatusColors[status] ?? AppColors.warning;
}

// ─── Estimate Status ───

const Map<String, String> _estimateStatusLabels = {
  '1': 'Draft',
  '2': 'Sent',
  '3': 'Declined',
  '4': 'Accepted',
  '5': 'Expired',
};

const Map<String, Color> _estimateStatusColors = {
  '1': AppColors.textMuted,
  '2': AppColors.primary,
  '3': AppColors.error,
  '4': AppColors.success,
  '5': AppColors.warning,
};

String estimateStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Draft';
  return _estimateStatusLabels[status] ?? status;
}

Color estimateStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.textMuted;
  return _estimateStatusColors[status] ?? AppColors.textMuted;
}

// ─── Leave Status ───

String leaveStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Unknown';
  switch (status.toLowerCase()) {
    case '0':
    case 'pending':
      return 'Pending';
    case '1':
    case 'approved':
      return 'Approved';
    case '2':
    case 'rejected':
      return 'Rejected';
    case '3':
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

Color leaveStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.textMuted;
  switch (status.toLowerCase()) {
    case '0':
    case 'pending':
      return AppColors.warning;
    case '1':
    case 'approved':
      return AppColors.success;
    case '2':
    case 'rejected':
      return AppColors.error;
    case '3':
    case 'cancelled':
      return AppColors.textMuted;
    default:
      return AppColors.textMuted;
  }
}

// ─── Project Status ───

String projectStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Unknown';
  switch (status.toLowerCase()) {
    case '1':
    case 'not started':
      return 'Not Started';
    case '2':
    case 'in progress':
      return 'In Progress';
    case '3':
    case 'on hold':
      return 'On Hold';
    case '4':
    case 'cancelled':
      return 'Cancelled';
    case '5':
    case 'completed':
    case 'finished':
      return 'Completed';
    default:
      return status;
  }
}

Color projectStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.textMuted;
  switch (status.toLowerCase()) {
    case '1':
    case 'not started':
      return AppColors.textMuted;
    case '2':
    case 'in progress':
      return AppColors.primary;
    case '3':
    case 'on hold':
      return AppColors.warning;
    case '4':
    case 'cancelled':
      return AppColors.error;
    case '5':
    case 'completed':
    case 'finished':
      return AppColors.success;
    default:
      return AppColors.textMuted;
  }
}

// ─── Document Status ───

Color documentStatusColor(String? status) {
  if (status == null || status.isEmpty) return AppColors.textMuted;
  switch (status.toLowerCase()) {
    case 'verified':
    case 'approved':
      return AppColors.success;
    case 'pending':
      return AppColors.warning;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}
