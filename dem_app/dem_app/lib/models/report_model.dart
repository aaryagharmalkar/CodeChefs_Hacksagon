class ReportModel {
  final String date;
  final String risk; // LOW / MEDIUM / HIGH
  final List<double> scores;

  ReportModel({
    required this.date,
    required this.risk,
    required this.scores,
  });
}