class AuditLog {
  final int id;
  final String createdAt;
  final int? userId;
  final String userRepr;
  final String action;
  final String actionDisplay;
  final String modelName;
  final int objectId;
  final String objectRepr;
  final Map<String, dynamic> changes;
  final Map<String, dynamic> snapshot;

  AuditLog({
    required this.id, required this.createdAt,
    this.userId, required this.userRepr,
    required this.action, required this.actionDisplay,
    required this.modelName, required this.objectId, required this.objectRepr,
    this.changes = const {}, this.snapshot = const {},
  });

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'] as int,
        createdAt: (j['created_at'] ?? '').toString(),
        userId: j['user'] as int?,
        userRepr: (j['user_repr'] ?? '').toString(),
        action: (j['action'] ?? '').toString(),
        actionDisplay: (j['action_display'] ?? '').toString(),
        modelName: (j['model_name'] ?? '').toString(),
        objectId: j['object_id'] as int? ?? 0,
        objectRepr: (j['object_repr'] ?? '').toString(),
        changes: (j['changes'] is Map)
            ? Map<String, dynamic>.from(j['changes'] as Map)
            : const {},
        snapshot: (j['snapshot'] is Map)
            ? Map<String, dynamic>.from(j['snapshot'] as Map)
            : const {},
      );
}
