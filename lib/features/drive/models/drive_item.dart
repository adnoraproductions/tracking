class DriveItem {
  const DriveItem({
    required this.id,
    required this.projectId,
    this.parentFolderId,
    required this.name,
    required this.mimeType,
    this.isFolder = false,
    this.isFinalExport = false,
    this.gdriveFileId,
    this.webViewLink,
    this.webContentLink,
    this.deliveryStatus,
    this.deliveredAt,
    this.sizeBytes,
    this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory DriveItem.fromJson(Map<String, dynamic> json) {
    return DriveItem(
      id: json['id'],
      projectId: json['project_id'],
      parentFolderId: json['parent_folder_id'],
      name: json['name'],
      mimeType: json['mime_type'],
      isFolder: json['is_folder'] ?? false,
      isFinalExport: json['is_final_export'] ?? false,
      gdriveFileId: json['gdrive_file_id'],
      webViewLink: json['web_view_link'],
      webContentLink: json['web_content_link'],
      deliveryStatus: json['delivery_status'],
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      sizeBytes: json['size_bytes'],
      uploadedBy: json['uploaded_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  final String id;
  final String projectId;
  final String? parentFolderId;
  final String name;
  final String mimeType;
  final bool isFolder;
  final bool isFinalExport;
  final String? gdriveFileId;
  final String? webViewLink;
  final String? webContentLink;
  final String? deliveryStatus;
  final DateTime? deliveredAt;
  final int? sizeBytes;
  final String? uploadedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

}

class UploadJob {
  const UploadJob({
    required this.id,
    required this.fileName,
    required this.progress,
    this.status = 'Uploading',
  });

  factory UploadJob.fromJson(Map<String, dynamic> json) {
    return UploadJob(
      id: json['id'],
      fileName: json['fileName'],
      progress: (json['progress'] as num).toDouble(),
      status: json['status'] ?? 'Uploading',
    );
  }

  final String id;
  final String fileName;
  final double progress;
  final String status;

}
