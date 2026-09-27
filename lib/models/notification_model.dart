class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final bool read;
  final DateTime timestamp;

  NotificationModel({required this.id, required this.title, required this.body, required this.category, required this.read, required this.timestamp});

  factory NotificationModel.fromMap(Map<String, dynamic> m) => NotificationModel(id: m['id'], title: m['title'], body: m['body'], category: m['category'], read: m['read'] ?? false, timestamp: DateTime.parse(m['timestamp']));
}
