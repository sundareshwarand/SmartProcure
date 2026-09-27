class OperatorQueueItem {
  final String queueId;
  final String token;
  final String farmerName;
  final String crop;
  final double expectedQty;
  final DateTime bookingTime;
  final String checkInStatus;
  final int waitingMinutes;
  final int? counter;
  final String bookingId;

  OperatorQueueItem({required this.queueId, required this.token, required this.farmerName, required this.crop, required this.expectedQty, required this.bookingTime, required this.checkInStatus, required this.waitingMinutes, this.counter, required this.bookingId});

  factory OperatorQueueItem.fromMap(Map<String, dynamic> m) => OperatorQueueItem(
    queueId: m['queueId'], token: m['token'], farmerName: m['farmerName'], crop: m['crop'], expectedQty: (m['expectedQty'] as num).toDouble(), bookingTime: DateTime.parse(m['bookingTime']), checkInStatus: m['checkInStatus'], waitingMinutes: (m['waitingMinutes'] as num).toInt(), counter: m['counter'] as int?, bookingId: m['bookingId']);
}
