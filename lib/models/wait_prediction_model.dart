class WaitPredictionModel {
  final int estimatedMinutes;
  final String confidence; // e.g., High/Medium/Low
  final Map<String, dynamic> factors;

  WaitPredictionModel({required this.estimatedMinutes, required this.confidence, required this.factors});
}
