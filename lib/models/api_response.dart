/// Typed wrapper for API responses.
///
/// Provides safe extraction of data, lists, and messages
/// so callers don't need to do raw Map access.
class ApiResponse {
  final bool success;
  final String? message;
  final Map<String, dynamic> raw;

  ApiResponse._({required this.success, this.message, required this.raw});

  factory ApiResponse.from(dynamic response) {
    if (response is Map<String, dynamic>) {
      return ApiResponse._(
        success: response['status'] == true || response['success'] == true,
        message: response['message']?.toString(),
        raw: response,
      );
    }
    return ApiResponse._(success: false, message: null, raw: {});
  }

  /// Extract `data` as a Map. Returns empty map if missing or wrong type.
  Map<String, dynamic> get data {
    final d = raw['data'];
    if (d is Map<String, dynamic>) return d;
    if (d == null) return raw;
    return {};
  }

  /// Extract `data` as a List of Maps (for paginated endpoints).
  List<Map<String, dynamic>> get dataList {
    final d = raw['data'];
    if (d is List) {
      return d
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }
    // Some endpoints nest the list inside data.{key}
    if (d is Map<String, dynamic>) {
      for (final value in d.values) {
        if (value is List && value.isNotEmpty) {
          return value
              .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
              .toList();
        }
      }
    }
    // Response itself might be a list
    if (raw is List) {
      return (raw as List)
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }
    return [];
  }

  /// Check if the response indicates a queued offline action.
  bool get isQueued => raw['queued'] == true;
}
