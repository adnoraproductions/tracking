class JournalNote {
  const JournalNote({
    required this.id,
    required this.projectId,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.title,
    required this.content,
    required this.noteType,
    this.isPinned = false,
    this.isPrivate = false,
    this.attachments = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory JournalNote.fromJson(Map<String, dynamic> json) {
    return JournalNote(
      id: json['id'],
      projectId: json['project_id'],
      authorId: json['author_id'],
      authorName: json['author_name'],
      authorAvatar: json['author_avatar'],
      title: json['title'],
      content: json['content'],
      noteType: json['note_type'],
      isPinned: json['is_pinned'] ?? false,
      isPrivate: json['is_private'] ?? false,
      attachments: (json['attachments'] as List?)?.map((e) => JournalAttachment.fromJson(e)).toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  final String id;
  final String projectId;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;
  final String title;
  final String content;
  final String noteType;
  final bool isPinned;
  final bool isPrivate;
  final List<JournalAttachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'title': title,
      'content': content,
      'note_type': noteType,
      'is_pinned': isPinned,
      'is_private': isPrivate,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class JournalAttachment {
  const JournalAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
  });

  factory JournalAttachment.fromJson(Map<String, dynamic> json) {
    return JournalAttachment(
      id: json['id'],
      fileName: json['file_name'],
      fileUrl: json['file_url'],
      fileType: json['file_type'],
    );
  }

  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
    };
  }
}
