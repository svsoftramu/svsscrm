class AppNotification {
  final String? id;
  final String? title;
  final String? description;
  final String? message;
  final String? isRead;
  final String? createdAt;
  final String? type;

  AppNotification({
    this.id,
    this.title,
    this.description,
    this.message,
    this.isRead,
    this.createdAt,
    this.type,
  });

  /// Returns the best available display text for this notification.
  String get displayName {
    if (title != null && title!.trim().isNotEmpty) return title!;
    if (message != null && message!.trim().isNotEmpty) return message!;
    if (description != null && description!.trim().isNotEmpty) return description!;
    return 'Notification #${id ?? "unknown"}';
  }

  /// Whether this notification has been read.
  bool get read => isRead == '1' || isRead == 'true';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString(),
      title: (json['title'] ?? json['subject'])?.toString(),
      description: json['description']?.toString(),
      message: (json['message'] ?? json['body'])?.toString(),
      isRead: json['is_read']?.toString(),
      createdAt: (json['created_at'] ?? json['date'] ?? json['timestamp'])?.toString(),
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt,
      'type': type,
    };
  }

  static List<AppNotification> fromList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  @override
  String toString() => 'AppNotification(id: $id, displayName: $displayName)';
}
