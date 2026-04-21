import 'package:flutter/material.dart';
import '../models/api_response.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class CRMProvider with ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final CacheService _cache = CacheService.instance;

  // Dashboard
  Map<String, dynamic> _dashboardData = {};

  // CRM
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _projects = [];

  // CRM: Estimates & Invoices
  List<Map<String, dynamic>> _estimates = [];
  List<Map<String, dynamic>> _invoices = [];

  // ESS
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _attendanceToday = {};
  List<Map<String, dynamic>> _attendanceMonthly = [];
  List<Map<String, dynamic>> _leaveBalances = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _directory = [];
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _pendingApprovals = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _payslips = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _loans = [];
  Map<String, dynamic> _salaryStructure = {};
  int _unreadCount = 0;

  int _loadingCount = 0;
  String? _error;

  // Getters
  Map<String, dynamic> get dashboardData => _dashboardData;
  List<Map<String, dynamic>> get leads => _leads;
  List<Map<String, dynamic>> get customers => _customers;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get projects => _projects;
  List<Map<String, dynamic>> get estimates => _estimates;
  List<Map<String, dynamic>> get invoices => _invoices;
  Map<String, dynamic> get profile => _profile;
  Map<String, dynamic> get attendanceToday => _attendanceToday;
  List<Map<String, dynamic>> get attendanceMonthly => _attendanceMonthly;
  List<Map<String, dynamic>> get leaveBalances => _leaveBalances;
  List<Map<String, dynamic>> get leaveRequests => _leaveRequests;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get announcements => _announcements;
  List<Map<String, dynamic>> get holidays => _holidays;
  List<Map<String, dynamic>> get directory => _directory;
  List<Map<String, dynamic>> get teamMembers => _teamMembers;
  List<Map<String, dynamic>> get pendingApprovals => _pendingApprovals;
  List<Map<String, dynamic>> get expenses => _expenses;
  List<Map<String, dynamic>> get expenseCategories => _expenseCategories;
  List<Map<String, dynamic>> get payslips => _payslips;
  List<Map<String, dynamic>> get documents => _documents;
  List<Map<String, dynamic>> get loans => _loans;
  Map<String, dynamic> get salaryStructure => _salaryStructure;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  // ─── Dashboard ───
  Future<void> fetchDashboard() async {
    _setLoading(true);
    try {
      final response = await _api.get('dashboard');
      _dashboardData = _extractData(response) ?? {};
      await _cache.cacheData('dashboard', _dashboardData);
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      // Try loading from cache on error
      final cached = await _cache.getCachedData('dashboard', maxAge: const Duration(hours: 24));
      if (cached is Map<String, dynamic> && _dashboardData.isEmpty) {
        _dashboardData = cached;
      }
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ─── Profile ───
  Future<void> fetchProfile() async {
    try {
      final response = await _api.get('profile');
      _profile = _extractData(response) ?? {};
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── CRM: Lead Sources & Statuses ───
  List<Map<String, dynamic>> _leadSources = [];
  List<Map<String, dynamic>> _leadStatuses = [];
  List<Map<String, dynamic>> get leadSources => _leadSources;
  List<Map<String, dynamic>> get leadStatuses => _leadStatuses;

  Future<void> fetchLeadSources() async {
    try {
      final response = await _api.get('crm/lead-sources');
      _leadSources = _extractList(response);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchLeadStatuses() async {
    try {
      final response = await _api.get('crm/lead-statuses');
      _leadStatuses = _extractList(response);
      notifyListeners();
    } catch (_) {}
  }

  // ─── CRM: Leads ───
  int _leadsPage = 1;
  bool _leadsHasMore = true;
  bool get leadsHasMore => _leadsHasMore;

  Future<void> fetchLeads({bool loadMore = false}) async {
    if (loadMore && !_leadsHasMore) return;
    _setLoading(true);
    try {
      final page = loadMore ? _leadsPage + 1 : 1;
      final response = await _api.get('crm/leads?page=$page&per_page=20');
      final newItems = _extractList(response);
      if (loadMore) {
        final existingIds = _leads.map((l) => l['id']?.toString()).toSet();
        final unique = newItems.where((l) => !existingIds.contains(l['id']?.toString())).toList();
        _leads.addAll(unique);
      } else {
        _leads = newItems;
      }
      _leadsPage = page;
      _leadsHasMore = newItems.length >= 20;
      await _cache.cacheData('leads', _leads);
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      if (!loadMore) {
        final cached = await _cache.getCachedData('leads', maxAge: const Duration(hours: 24));
        if (cached is List && _leads.isEmpty) {
          _leads = cached.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
        }
      }
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> fetchLeadDetail(String id) async {
    final response = await _api.get('crm/leads/$id');
    return _extractData(response) ?? {};
  }

  Future<ApiResponse> addLead(Map<String, dynamic> data) async {
    try {
      final response = ApiResponse.from(await _api.post('crm/leads', data));
      if (!response.isQueued) await fetchLeads();
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<ApiResponse> updateLead(String id, Map<String, dynamic> data) async {
    try {
      final response = ApiResponse.from(await _api.put('crm/leads/$id', data));
      if (!response.isQueued) await fetchLeads();
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await _api.delete('crm/leads/$id');
      _leads.removeWhere((l) => l['id'].toString() == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── CRM: Customers ───
  int _customersPage = 1;
  bool _customersHasMore = true;
  bool get customersHasMore => _customersHasMore;

  Future<void> fetchCustomers({bool loadMore = false}) async {
    if (loadMore && !_customersHasMore) return;
    _setLoading(true);
    try {
      final page = loadMore ? _customersPage + 1 : 1;
      final response = await _api.get('crm/customers?page=$page&per_page=20');
      final newItems = _extractList(response);
      if (loadMore) {
        // Deduplicate by userid
        final existingIds = _customers.map((c) => c['userid']?.toString()).toSet();
        final unique = newItems.where((c) => !existingIds.contains(c['userid']?.toString())).toList();
        _customers.addAll(unique);
      } else {
        _customers = newItems;
      }
      _customersPage = page;
      _customersHasMore = newItems.length >= 20;
      await _cache.cacheData('customers', _customers);
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      if (!loadMore) {
        final cached = await _cache.getCachedData('customers', maxAge: const Duration(hours: 24));
        if (cached is List && _customers.isEmpty) {
          _customers = cached.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
        }
      }
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<ApiResponse> addCustomer(Map<String, dynamic> data) async {
    try {
      final response = ApiResponse.from(await _api.post('crm/customers', data));
      if (!response.isQueued) await fetchCustomers();
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _api.delete('crm/customers/$id');
      _customers.removeWhere((c) => c['userid']?.toString() == id || c['id']?.toString() == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── CRM: Tasks ───
  int _tasksPage = 1;
  bool _tasksHasMore = true;
  bool get tasksHasMore => _tasksHasMore;

  Future<void> fetchTasks({bool loadMore = false}) async {
    if (loadMore && !_tasksHasMore) return;
    _setLoading(true);
    try {
      final page = loadMore ? _tasksPage + 1 : 1;
      final response = await _api.get('crm/tasks?page=$page&per_page=20');
      final newItems = _extractList(response);
      if (loadMore) {
        _tasks.addAll(newItems);
      } else {
        _tasks = newItems;
      }
      _tasksPage = page;
      _tasksHasMore = newItems.length >= 20;
      await _cache.cacheData('tasks', _tasks);
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      if (!loadMore) {
        final cached = await _cache.getCachedData('tasks', maxAge: const Duration(hours: 24));
        if (cached is List && _tasks.isEmpty) {
          _tasks = cached.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
        }
      }
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<ApiResponse> addTask(Map<String, dynamic> data) async {
    try {
      final response = ApiResponse.from(await _api.post('crm/tasks', data));
      if (!response.isQueued) await fetchTasks();
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTaskStatus(String id, int status) async {
    try {
      await _api.put('crm/tasks/$id/status', {'status': status});
      await fetchTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _api.delete('crm/tasks/$id');
      _tasks.removeWhere((t) => t['id'].toString() == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── CRM: Estimates ───
  int _estimatesPage = 1;
  bool _estimatesHasMore = true;
  bool get estimatesHasMore => _estimatesHasMore;

  Future<void> fetchEstimates({bool loadMore = false}) async {
    if (loadMore && !_estimatesHasMore) return;
    _setLoading(true);
    try {
      final page = loadMore ? _estimatesPage + 1 : 1;
      final response = await _api.get('crm/estimates?page=$page&per_page=20');
      final newItems = _extractList(response);
      if (loadMore) {
        _estimates.addAll(newItems);
      } else {
        _estimates = newItems;
      }
      _estimatesPage = page;
      _estimatesHasMore = newItems.length >= 20;
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ─── CRM: Invoices ───
  int _invoicesPage = 1;
  bool _invoicesHasMore = true;
  bool get invoicesHasMore => _invoicesHasMore;

  Future<void> fetchInvoices({bool loadMore = false}) async {
    if (loadMore && !_invoicesHasMore) return;
    _setLoading(true);
    try {
      final page = loadMore ? _invoicesPage + 1 : 1;
      final response = await _api.get('crm/invoices?page=$page&per_page=20');
      final newItems = _extractList(response);
      if (loadMore) {
        _invoices.addAll(newItems);
      } else {
        _invoices = newItems;
      }
      _invoicesPage = page;
      _invoicesHasMore = newItems.length >= 20;
      if (_loadingCount <= 1) _error = null;
    } catch (e) {
      _error ??= e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ─── CRM: Lead Notes ───
  Future<List<Map<String, dynamic>>> fetchLeadNotes(String leadId) async {
    final response = await _api.get('crm/leads/$leadId/notes');
    return _extractList(response);
  }

  Future<void> addLeadNote(String leadId, String content) async {
    await _api.post('crm/leads/$leadId/notes', {'content': content});
  }

  Future<void> deleteLeadNote(String leadId, String noteId) async {
    await _api.delete('crm/leads/$leadId/notes/$noteId');
  }

  // ─── CRM: Lead Conversion ───
  Future<ApiResponse> convertLeadToCustomer(String leadId, {Map<String, dynamic>? additionalData}) async {
    final raw = await _api.post('crm/leads/$leadId/convert', additionalData ?? {});
    final response = ApiResponse.from(raw);
    if (!response.isQueued) {
      await fetchLeads();
      await fetchCustomers();
    }
    return response;
  }

  // ─── CRM: Activity Logging ───
  Future<void> logActivity(String leadId, Map<String, dynamic> data) async {
    await _api.post('crm/leads/$leadId/activities', data);
  }

  Future<List<Map<String, dynamic>>> fetchLeadActivities(String leadId) async {
    final response = await _api.get('crm/leads/$leadId/activities');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> fetchCustomerActivities(String customerId) async {
    final response = await _api.get('crm/customers/$customerId/activities');
    return _extractList(response);
  }

  // ─── CRM: Bulk Actions ───
  Future<void> bulkUpdateLeads(List<String> ids, Map<String, dynamic> data) async {
    await _api.put('crm/leads/bulk-update', {'ids': ids, ...data});
    await fetchLeads();
  }

  Future<void> bulkDeleteLeads(List<String> ids) async {
    await _api.post('crm/leads/bulk-delete', {'ids': ids});
    _leads.removeWhere((l) => ids.contains(l['id'].toString()));
    notifyListeners();
  }

  Future<void> bulkUpdateTasks(List<String> ids, Map<String, dynamic> data) async {
    await _api.put('crm/tasks/bulk-update', {'ids': ids, ...data});
    await fetchTasks();
  }

  Future<void> bulkDeleteTasks(List<String> ids) async {
    await _api.post('crm/tasks/bulk-delete', {'ids': ids});
    _tasks.removeWhere((t) => ids.contains(t['id'].toString()));
    notifyListeners();
  }

  // ─── CRM: Reports ───
  Future<Map<String, dynamic>> fetchSalesReport({String? month, String? year}) async {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _api.get('crm/reports/sales$query');
    return _extractData(response) ?? {};
  }

  Future<Map<String, dynamic>> fetchLeadSourceReport() async {
    final response = await _api.get('crm/reports/lead-sources');
    return _extractData(response) ?? {};
  }

  Future<Map<String, dynamic>> fetchTeamPerformanceReport() async {
    final response = await _api.get('crm/reports/team-performance');
    return _extractData(response) ?? {};
  }

  // ─── CRM: Birthdays & Anniversaries ───
  List<Map<String, dynamic>> _upcomingBirthdays = [];
  List<Map<String, dynamic>> _upcomingAnniversaries = [];
  List<Map<String, dynamic>> get upcomingBirthdays => _upcomingBirthdays;
  List<Map<String, dynamic>> get upcomingAnniversaries => _upcomingAnniversaries;

  Future<void> fetchUpcomingBirthdays() async {
    try {
      final response = await _api.get('crm/customers/upcoming-birthdays');
      _upcomingBirthdays = _extractList(response);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchUpcomingAnniversaries() async {
    try {
      final response = await _api.get('crm/customers/upcoming-anniversaries');
      _upcomingAnniversaries = _extractList(response);
      notifyListeners();
    } catch (_) {}
  }

  // ─── CRM: Projects ───
  Future<void> fetchProjects() async {
    _setLoading(true);
    try {
      final response = await _api.get('crm/projects');
      _projects = _extractList(response);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ─── Attendance ───
  Future<void> fetchAttendanceToday() async {
    try {
      final response = await _api.get('attendance/today');
      _attendanceToday = _extractData(response) ?? {};
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchAttendanceMonthly() async {
    try {
      final response = await _api.get('attendance/monthly');
      _attendanceMonthly = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> checkIn({String? faceImage, double? matchScore, String? faceMeshData}) async {
    final body = <String, dynamic>{};
    if (faceImage != null) body['face_image'] = faceImage;
    if (matchScore != null) body['face_match_score'] = matchScore;
    if (faceMeshData != null) body['face_mesh_data'] = faceMeshData;
    final response = await _api.post('attendance/check-in', body);
    await fetchAttendanceToday();
    return response;
  }

  Future<Map<String, dynamic>> checkOut({String? faceImage, double? matchScore, String? faceMeshData}) async {
    final body = <String, dynamic>{};
    if (faceImage != null) body['face_image'] = faceImage;
    if (matchScore != null) body['face_match_score'] = matchScore;
    if (faceMeshData != null) body['face_mesh_data'] = faceMeshData;
    final response = await _api.post('attendance/check-out', body);
    await fetchAttendanceToday();
    return response;
  }

  Future<void> clearTodayAttendance() async {
    await _api.post('attendance/clear-today', {});
    await fetchAttendanceToday();
    await fetchAttendanceMonthly();
  }

  // ─── Face Enrollment ───
  bool _isFaceEnrolled = false;
  String? _enrolledMeshJson;
  Map<String, dynamic> _faceEnrollmentData = {};
  bool get isFaceEnrolled => _isFaceEnrolled;
  Map<String, dynamic> get faceEnrollmentData => _faceEnrollmentData;

  Future<void> checkFaceEnrollment() async {
    try {
      final response = await _api.get('face/enrollment-status');
      final data = _extractData(response);
      _isFaceEnrolled = data?['enrolled'] == true;
      _faceEnrollmentData = data ?? {};
      notifyListeners();
    } catch (_) {
      _isFaceEnrolled = false;
      _enrolledMeshJson = null;
      _faceEnrollmentData = {};
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> enrollFace({required String faceImage, required String meshData}) async {
    final response = await _api.post('face/enroll', {
      'face_image': faceImage,
      'face_mesh_data': meshData,
    });
    _isFaceEnrolled = true;
    _enrolledMeshJson = meshData;
    notifyListeners();
    return response;
  }

  Future<Map<String, dynamic>> faceVerifyCheckin({required int enrollmentId}) async {
    final response = await _api.post('face/verify-checkin', {
      'enrollment_id': enrollmentId,
    });
    await fetchAttendanceToday();
    return response;
  }

  Future<void> deleteFaceEnrollment(String id) async {
    await _api.delete('face/$id');
    _isFaceEnrolled = false;
    _enrolledMeshJson = null;
    _faceEnrollmentData = {};
    notifyListeners();
  }

  Future<String?> getReferenceMeshJson() async {
    if (_enrolledMeshJson != null) return _enrolledMeshJson;
    try {
      final response = await _api.get('face/reference');
      final data = _extractData(response);
      _enrolledMeshJson = data?['face_mesh_data'];
      return _enrolledMeshJson;
    } catch (_) {
      return null;
    }
  }

  // ─── Leaves ───
  Future<void> fetchLeaveBalances() async {
    try {
      _error = null;
      final response = await _api.get('leaves/balances');
      _leaveBalances = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchLeaveRequests() async {
    try {
      _error = null;
      final response = await _api.get('leaves/requests');
      _leaveRequests = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<ApiResponse> applyLeave(Map<String, dynamic> data) async {
    final raw = await _api.post('leaves/apply', data);
    final response = ApiResponse.from(raw);
    if (!response.isQueued) {
      await fetchLeaveBalances();
      await fetchLeaveRequests();
    }
    return response;
  }

  Future<void> cancelLeave(String id) async {
    await _api.post('leaves/cancel/$id', {});
    await fetchLeaveRequests();
  }

  // ─── Payroll ───
  Future<void> fetchPayslips() async {
    try {
      _error = null;
      final response = await _api.get('payroll/payslips');
      _payslips = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchSalaryStructure() async {
    try {
      _error = null;
      final response = await _api.get('payroll/salary-structure');
      _salaryStructure = _extractData(response) ?? {};
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Expenses ───
  Future<void> fetchExpenses() async {
    try {
      _error = null;
      final response = await _api.get('expenses');
      _expenses = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchExpenseCategories() async {
    try {
      _error = null;
      final response = await _api.get('expense-categories');
      _expenseCategories = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<ApiResponse> addExpense(Map<String, dynamic> data) async {
    final response = ApiResponse.from(await _api.post('expenses', data));
    if (!response.isQueued) await fetchExpenses();
    return response;
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('expenses/$id');
    _expenses.removeWhere((e) => e['id'].toString() == id);
    notifyListeners();
  }

  // ─── Documents ───
  Future<void> fetchDocuments() async {
    try {
      _error = null;
      final response = await _api.get('documents');
      _documents = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Loans ───
  Future<void> fetchLoans() async {
    try {
      _error = null;
      final response = await _api.get('loans');
      _loans = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Notifications ───
  Future<void> fetchNotifications() async {
    try {
      _error = null;
      final response = await _api.get('notifications');
      _notifications = _extractList(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _api.get('notifications/unread-count');
      final data = _extractData(response);
      _unreadCount = data?['count'] ?? data?['unread_count'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    await _api.post('notifications/$id/read', {});
    await fetchNotifications();
    await fetchUnreadCount();
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post('notifications/read-all', {});
    await fetchNotifications();
    _unreadCount = 0;
    notifyListeners();
  }

  // ─── Announcements & Holidays ───
  Future<void> fetchAnnouncements() async {
    try {
      final response = await _api.get('announcements');
      _announcements = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchHolidays() async {
    try {
      final response = await _api.get('holidays');
      _holidays = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Directory & Team ───
  Future<void> fetchDirectory() async {
    try {
      final response = await _api.get('directory');
      _directory = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchTeamMembers() async {
    try {
      final response = await _api.get('team/members');
      _teamMembers = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Approvals ───
  Future<void> fetchPendingApprovals() async {
    try {
      final response = await _api.get('approvals/pending');
      _pendingApprovals = _extractList(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> approveRequest(String id) async {
    await _api.post('approvals/$id/approve', {});
    await fetchPendingApprovals();
  }

  Future<void> rejectRequest(String id, String reason) async {
    await _api.post('approvals/$id/reject', {'reason': reason});
    await fetchPendingApprovals();
  }

  // ─── Search ───
  Future<List<Map<String, dynamic>>> search(String query) async {
    final response = await _api.get('search?q=$query');
    return _extractList(response);
  }

  // ─── Helpers ───
  Map<String, dynamic>? _extractData(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      if (data == null) return response;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
      }
      if (data is Map<String, dynamic>) {
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) {
            return value.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
          }
        }
      }
    }
    if (response is List) {
      return response.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    return [];
  }

  void _setLoading(bool value) {
    if (value) {
      _loadingCount++;
    } else {
      _loadingCount = (_loadingCount - 1).clamp(0, 999);
    }
    notifyListeners();
  }
}
