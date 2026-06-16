class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    this.clientId,
    this.clientName,
    required this.status,
    required this.progress,
    this.startDate,
    this.dueDate,
    this.teamMembers = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      clientId: json['client_id'],
      clientName: json['client_name'],
      status: json['status'] ?? 'Planning',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      teamMembers: (json['team_members'] as List?)?.map((e) => ProjectTeamMember.fromJson(e)).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  final String id;
  final String name;
  final String description;
  final String? clientId;
  final String? clientName;
  final String status;
  final double progress;
  final DateTime? startDate;
  final DateTime? dueDate;
  final List<ProjectTeamMember> teamMembers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? clientId,
    String? clientName,
    String? status,
    double? progress,
    DateTime? startDate,
    DateTime? dueDate,
    List<ProjectTeamMember>? teamMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      teamMembers: teamMembers ?? this.teamMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'client_id': clientId,
      'client_name': clientName,
      'status': status,
      'progress': progress,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'team_members': teamMembers.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ProjectTeamMember {
  const ProjectTeamMember({
    required this.userId,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  factory ProjectTeamMember.fromJson(Map<String, dynamic> json) {
    return ProjectTeamMember(
      userId: json['user_id'],
      name: json['name'],
      role: json['role'] ?? 'Member',
      avatarUrl: json['avatar_url'],
    );
  }

  final String userId;
  final String name;
  final String role;
  final String? avatarUrl;


  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'role': role,
      'avatar_url': avatarUrl,
    };
  }
}
