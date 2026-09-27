class AuditLog {
  final String id;
  final String actorId;
  final String actorRole;
  final String centreId;
  final String action;
  final String targetId;
  final DateTime timestamp;
  final bool success;
  final Map<String, dynamic>? metadata;

  AuditLog({required this.id, required this.actorId, required this.actorRole, required this.centreId, required this.action, required this.targetId, required this.timestamp, required this.success, this.metadata});

  Map<String, dynamic> toMap() => {
    'id': id,
    'actorId': actorId,
    'actorRole': actorRole,
    'centreId': centreId,
    'action': action,
    'targetId': targetId,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'metadata': metadata ?? {}
  };
}
