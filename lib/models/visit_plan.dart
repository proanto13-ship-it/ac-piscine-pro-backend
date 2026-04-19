class VisitPlan {
  final String id;
  final String clientId;
  final int frequencyDays;
  final String nextVisitAtIso;
  final String note;
  final bool reminderEnabled;
  final String createdAtIso;
  final String updatedAtIso;

  const VisitPlan({
    required this.id,
    required this.clientId,
    required this.frequencyDays,
    required this.nextVisitAtIso,
    required this.note,
    required this.reminderEnabled,
    required this.createdAtIso,
    String? updatedAtIso,
  }) : updatedAtIso = updatedAtIso ?? createdAtIso;

  factory VisitPlan.fromJson(Map<String, dynamic> json) {
    final createdAtIso = json['createdAtIso']?.toString() ?? '';
    return VisitPlan(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      frequencyDays: json['frequencyDays'] is int
          ? json['frequencyDays'] as int
          : int.tryParse(json['frequencyDays']?.toString() ?? '') ?? 14,
      nextVisitAtIso: json['nextVisitAtIso']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      reminderEnabled: json['reminderEnabled'] == true,
      createdAtIso: createdAtIso,
      updatedAtIso: json['updatedAtIso']?.toString() ?? createdAtIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'frequencyDays': frequencyDays,
        'nextVisitAtIso': nextVisitAtIso,
        'note': note,
        'reminderEnabled': reminderEnabled,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
      };

  VisitPlan copyWith({
    String? id,
    String? clientId,
    int? frequencyDays,
    String? nextVisitAtIso,
    String? note,
    bool? reminderEnabled,
    String? createdAtIso,
    String? updatedAtIso,
  }) {
    return VisitPlan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      nextVisitAtIso: nextVisitAtIso ?? this.nextVisitAtIso,
      note: note ?? this.note,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }
}
