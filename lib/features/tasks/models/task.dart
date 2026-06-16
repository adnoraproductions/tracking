class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.assigneeId,
    this.assigneeName,
    this.assigneeAvatar,
    this.dueDate,
    this.checklist = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      id: json['id'],
      projectId: json['project_id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      assigneeId: json['assignee_id'],
      assigneeName: json['assignee_name'],
      assigneeAvatar: json['assignee_avatar'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      checklist: (json['checklist'] as List?)?.map((e) => TaskChecklistItem.fromJson(e)).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  final String id;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatar;
  final DateTime? dueDate;
  final List<TaskChecklistItem> checklist;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProjectTask copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeName,
    String? assigneeAvatar,
    DateTime? dueDate,
    List<TaskChecklistItem>? checklist,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectTask(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      assigneeAvatar: assigneeAvatar ?? this.assigneeAvatar,
      dueDate: dueDate ?? this.dueDate,
      checklist: checklist ?? this.checklist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assignee_id': assigneeId,
      'assignee_name': assigneeName,
      'assignee_avatar': assigneeAvatar,
      'due_date': dueDate?.toIso8601String(),
      'checklist': checklist.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) {
    return TaskChecklistItem(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  final String id;
  final String title;
  final bool isCompleted;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}
