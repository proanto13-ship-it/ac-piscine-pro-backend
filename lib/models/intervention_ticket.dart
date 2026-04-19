class InterventionTicketData {
  final String clientName;
  final String dateLabel;
  final String technicianName;
  final String clientRepresentative;
  final String poolSummary;
  final String interventionSummary;
  final String recommendations;
  final String accessNotes;
  final String followUpLabel;
  final String estimateLabel;
  final bool estimateApproved;
  final bool interventionCompleted;
  final bool followUpRequired;

  const InterventionTicketData({
    required this.clientName,
    required this.dateLabel,
    required this.technicianName,
    required this.clientRepresentative,
    required this.poolSummary,
    required this.interventionSummary,
    required this.recommendations,
    required this.accessNotes,
    required this.followUpLabel,
    required this.estimateLabel,
    required this.estimateApproved,
    required this.interventionCompleted,
    required this.followUpRequired,
  });
}
