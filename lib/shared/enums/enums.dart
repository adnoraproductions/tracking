/// Enums used across ADNORA OS
library;

enum UserRole {
  admin,
  employee;

  bool get isAdmin => this == UserRole.admin;
}

enum ProjectStatus {
  planning,
  active,
  onHold,
  completed,
  archived;

  String get label => switch (this) {
    ProjectStatus.planning => 'Planning',
    ProjectStatus.active => 'Active',
    ProjectStatus.onHold => 'On Hold',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.archived => 'Archived',
  };
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
    TaskPriority.urgent => 'Urgent',
  };
}

enum TaskStatus {
  todo,
  inProgress,
  review,
  done;

  String get label => switch (this) {
    TaskStatus.todo => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.review => 'Review',
    TaskStatus.done => 'Done',
  };
}

enum LeaveType {
  casual,
  sick,
  earned,
  unpaid,
  other;

  String get label => switch (this) {
    LeaveType.casual => 'Casual Leave',
    LeaveType.sick => 'Sick Leave',
    LeaveType.earned => 'Earned Leave',
    LeaveType.unpaid => 'Unpaid Leave',
    LeaveType.other => 'Other',
  };
}

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
    LeaveStatus.pending => 'Pending',
    LeaveStatus.approved => 'Approved',
    LeaveStatus.rejected => 'Rejected',
    LeaveStatus.cancelled => 'Cancelled',
  };
}

enum AttendanceAction {
  clockIn,
  clockOut,
  breakStart,
  breakEnd;

  String get label => switch (this) {
    AttendanceAction.clockIn => 'Clock In',
    AttendanceAction.clockOut => 'Clock Out',
    AttendanceAction.breakStart => 'Break Start',
    AttendanceAction.breakEnd => 'Break End',
  };
}
