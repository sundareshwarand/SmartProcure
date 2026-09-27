class QueueStatusModel {
  final String bookingToken;
  final String nowServing;
  final int farmersAhead;
  final int estimatedWaitMinutes;
  final int currentCounter;
  final String status;

  QueueStatusModel({required this.bookingToken, required this.nowServing, required this.farmersAhead, required this.estimatedWaitMinutes, required this.currentCounter, required this.status});
}
