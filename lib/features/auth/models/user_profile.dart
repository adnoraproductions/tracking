import '../../../shared/enums/enums.dart';

/// ADNORA OS User Profile Model
class UserProfile {

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.department,
    this.designation,
    this.phone,
    this.isActive = true,
    this.onboardingComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
  final String? department;
  final String? designation;
  final String? phone;
  final bool isActive;
  final bool onboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'avatar_url': avatarUrl,
      'department': department,
      'designation': designation,
      'phone': phone,
      'is_active': isActive,
      'onboarding_complete': onboardingComplete,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? department,
    String? designation,
    String? phone,
    bool? isActive,
    bool? onboardingComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static UserRole _parseRole(String? role) {
    return switch (role) {
      'admin' => UserRole.admin,
      _ => UserRole.employee,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
