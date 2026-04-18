class TaskModel {
  final String? id;
  final String? name;
  final String? title;
  final String? description;
  final String? status;
  final String? priority;
  final String? dueDate;
  final String? startDate;
  final String? billable;
  final String? isPublic;
  final String? hourlyRate;
  final String? relType;
  final String? relId;
  final String? dateAdded;

  TaskModel({
    this.id,
    this.name,
    this.title,
    this.description,
    this.status,
    this.priority,
    this.dueDate,
    this.startDate,
    this.billable,
    this.isPublic,
    this.hourlyRate,
    this.relType,
    this.relId,
    this.dateAdded,
  });

  /// Returns name or title, whichever is available.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (title != null && title!.trim().isNotEmpty) return title!;
    return 'Task #${id ?? "unknown"}';
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString(),
      priority: json['priority']?.toString(),
      dueDate: (json['duedate'] ?? json['due_date'])?.toString(),
      startDate: (json['startdate'] ?? json['start_date'])?.toString(),
      billable: json['billable']?.toString(),
      isPublic: json['is_public']?.toString(),
      hourlyRate: json['hourly_rate']?.toString(),
      relType: json['rel_type']?.toString(),
      relId: json['rel_id']?.toString(),
      dateAdded: (json['dateadded'] ?? json['created_at'] ?? json['date_added'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'duedate': dueDate,
      'startdate': startDate,
      'billable': billable,
      'is_public': isPublic,
      'hourly_rate': hourlyRate,
      'rel_type': relType,
      'rel_id': relId,
      'dateadded': dateAdded,
    };
  }

  static List<TaskModel> fromList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => TaskModel.fromJson(json))
        .toList();
  }

  @override
  String toString() => 'TaskModel(id: $id, displayName: $displayName)';
}
