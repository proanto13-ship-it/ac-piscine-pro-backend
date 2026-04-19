import 'financial_document.dart';
import 'intervention_record.dart';
import 'water_analysis.dart';

class Client {
  String id;
  String name;
  String phone;
  String email;
  String address;
  double volume;
  String treatment;
  String bassinType;
  String revetement;
  String filtration;
  String equipements;
  int visitFrequencyDays;
  String createdAtIso;
  String updatedAtIso;
  int version;
  String deletedAtIso;
  String notes;
  List<WaterAnalysis> analyses;
  List<InterventionRecord> interventions;
  List<FinancialDocument> financialDocuments;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.volume,
    required this.treatment,
    required this.bassinType,
    required this.revetement,
    required this.filtration,
    required this.equipements,
    required this.visitFrequencyDays,
    required this.createdAtIso,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
    required this.notes,
    required this.analyses,
    required this.interventions,
    required this.financialDocuments,
  })  : updatedAtIso = updatedAtIso ?? createdAtIso,
        version = version ?? 1,
        deletedAtIso = deletedAtIso ?? '';

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      treatment: json['treatment'] ?? '',
      bassinType: json['bassinType'] ?? '',
      revetement: json['revetement'] ?? '',
      filtration: json['filtration'] ?? '',
      equipements: json['equipements'] ?? '',
      visitFrequencyDays: (json['visitFrequencyDays'] ?? 14) is int
          ? (json['visitFrequencyDays'] ?? 14) as int
          : ((json['visitFrequencyDays'] ?? 14) as num).toInt(),
      createdAtIso: json['createdAtIso'] ?? '',
      updatedAtIso: json['updatedAtIso'] ??
          json['updatedAt'] ??
          json['createdAtIso'] ??
          '',
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ?? 1,
      deletedAtIso: json['deletedAtIso'] ?? json['deletedAt'] ?? '',
      notes: json['notes'] ?? '',
      analyses: ((json['analyses'] ?? []) as List)
          .map((e) => WaterAnalysis.fromJson(e))
          .toList(),
      interventions: ((json['interventions'] ?? []) as List)
          .map((e) => InterventionRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      financialDocuments: ((json['financialDocuments'] ?? []) as List)
          .map((e) => FinancialDocument.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'volume': volume,
        'treatment': treatment,
        'bassinType': bassinType,
        'revetement': revetement,
        'filtration': filtration,
        'equipements': equipements,
        'visitFrequencyDays': visitFrequencyDays,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
        'updatedAt': updatedAtIso,
        'version': version,
        'deletedAtIso': deletedAtIso,
        'deletedAt': deletedAtIso,
        'notes': notes,
        'analyses': analyses.map((e) => e.toJson()).toList(),
        'interventions': interventions.map((e) => e.toJson()).toList(),
        'financialDocuments':
            financialDocuments.map((e) => e.toJson()).toList(),
      };

  WaterAnalysis? get latestAnalysis => analyses.isEmpty ? null : analyses.last;

  DateTime? get latestAnalysisDate {
    final analysis = latestAnalysis;
    if (analysis == null) return null;
    return DateTime.tryParse(analysis.dateIso)?.toLocal();
  }

  DateTime? get nextVisitDate {
    final date = latestAnalysisDate;
    if (date == null) return null;
    return date.add(Duration(days: visitFrequencyDays));
  }

  bool get hasOverdueVisit {
    final date = nextVisitDate;
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  bool get requiresFirstVisit => analyses.isEmpty;

  bool get isDeleted => deletedAtIso.trim().isNotEmpty;
}
