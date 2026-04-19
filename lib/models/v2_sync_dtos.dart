import 'client.dart';
import 'financial_document.dart';
import 'intervention_record.dart';

class V2ClientDto {
  final Client client;
  final String organizationId;
  final String updatedAtIso;

  const V2ClientDto({
    required this.client,
    required this.organizationId,
    required this.updatedAtIso,
  });

  factory V2ClientDto.fromClient(Client client) {
    return V2ClientDto(
      client: Client(
        id: client.id,
        name: client.name,
        phone: client.phone,
        email: client.email,
        address: client.address,
        volume: client.volume,
        treatment: client.treatment,
        bassinType: client.bassinType,
        revetement: client.revetement,
        filtration: client.filtration,
        equipements: client.equipements,
        visitFrequencyDays: client.visitFrequencyDays,
        createdAtIso: client.createdAtIso,
        updatedAtIso: client.updatedAtIso,
        version: client.version,
        deletedAtIso: client.deletedAtIso,
        notes: client.notes,
        analyses: [...client.analyses],
        interventions: const [],
        financialDocuments: const [],
      ),
      organizationId: '',
      updatedAtIso: _clientUpdatedAtIso(client),
    );
  }

  factory V2ClientDto.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['createdAtIso'] =
        normalized['createdAtIso'] ?? normalized['created_at_iso'] ?? '';
    normalized['updatedAtIso'] = normalized['updatedAtIso'] ??
        normalized['updatedAt'] ??
        normalized['updated_at_iso'] ??
        normalized['createdAtIso'] ??
        '';
    normalized['version'] = normalized['version'] ?? 1;
    normalized['deletedAtIso'] =
        normalized['deletedAtIso'] ?? normalized['deletedAt'] ?? '';
    normalized['interventions'] = const [];
    normalized['financialDocuments'] = const [];

    return V2ClientDto(
      client: Client.fromJson(normalized),
      organizationId: (json['organization_id'] ?? '').toString(),
      updatedAtIso: _serverUpdatedAtIso(json),
    );
  }

  Map<String, dynamic> toJson() => {
        ...client.toJson(),
        'display_name': client.name,
        'updatedAtIso': updatedAtIso,
        'version': client.version,
        'deletedAt': client.deletedAtIso,
      };

  static String _clientUpdatedAtIso(Client client) {
    final candidates = <String>[
      client.createdAtIso,
      ...client.analyses.map((item) => item.dateIso),
      ...client.interventions.map((item) => item.createdAtIso),
      ...client.financialDocuments.map((item) => item.createdAtIso),
    ].where((item) => item.trim().isNotEmpty);

    return _latestIso(candidates) ?? client.createdAtIso;
  }
}

class V2InterventionDto {
  final String clientId;
  final String clientName;
  final InterventionRecord intervention;
  final String organizationId;
  final String updatedAtIso;

  const V2InterventionDto({
    required this.clientId,
    required this.clientName,
    required this.intervention,
    required this.organizationId,
    required this.updatedAtIso,
  });

  factory V2InterventionDto.fromClient(
    Client client,
    InterventionRecord intervention,
  ) {
    return V2InterventionDto(
      clientId: client.id,
      clientName: client.name,
      intervention: intervention,
      organizationId: '',
      updatedAtIso: intervention.updatedAtIso,
    );
  }

  factory V2InterventionDto.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['createdAtIso'] =
        normalized['createdAtIso'] ?? normalized['created_at_iso'] ?? '';
    normalized['updatedAtIso'] = normalized['updatedAtIso'] ??
        normalized['updatedAt'] ??
        normalized['updated_at_iso'] ??
        normalized['createdAtIso'] ??
        '';
    normalized['version'] = normalized['version'] ?? 1;
    normalized['deletedAtIso'] =
        normalized['deletedAtIso'] ?? normalized['deletedAt'] ?? '';

    return V2InterventionDto(
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      clientName: (json['clientName'] ?? '').toString(),
      intervention: InterventionRecord.fromJson(normalized),
      organizationId: (json['organization_id'] ?? '').toString(),
      updatedAtIso: _serverUpdatedAtIso(json),
    );
  }

  Map<String, dynamic> toJson() => {
        ...intervention.toJson(),
        'client_id': clientId,
        'clientId': clientId,
        'clientName': clientName,
        'scheduled_at_iso': intervention.createdAtIso,
        'status': intervention.interventionCompleted ? 'completed' : 'pending',
        'updatedAtIso': updatedAtIso,
        'version': intervention.version,
        'deletedAt': intervention.deletedAtIso,
      };
}

class V2FinancialDocumentDto {
  final String clientId;
  final String clientName;
  final FinancialDocument document;
  final String organizationId;
  final String updatedAtIso;

  const V2FinancialDocumentDto({
    required this.clientId,
    required this.clientName,
    required this.document,
    required this.organizationId,
    required this.updatedAtIso,
  });

  factory V2FinancialDocumentDto.fromClient(
    Client client,
    FinancialDocument document,
  ) {
    return V2FinancialDocumentDto(
      clientId: client.id,
      clientName: client.name,
      document: document,
      organizationId: '',
      updatedAtIso: document.updatedAtIso,
    );
  }

  factory V2FinancialDocumentDto.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['createdAtIso'] =
        normalized['createdAtIso'] ?? normalized['created_at_iso'] ?? '';
    normalized['updatedAtIso'] = normalized['updatedAtIso'] ??
        normalized['updatedAt'] ??
        normalized['updated_at_iso'] ??
        normalized['createdAtIso'] ??
        '';
    normalized['version'] = normalized['version'] ?? 1;
    normalized['deletedAtIso'] =
        normalized['deletedAtIso'] ?? normalized['deletedAt'] ?? '';

    return V2FinancialDocumentDto(
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      clientName: (json['clientName'] ?? '').toString(),
      document: FinancialDocument.fromJson(normalized),
      organizationId: (json['organization_id'] ?? '').toString(),
      updatedAtIso: _serverUpdatedAtIso(json),
    );
  }

  Map<String, dynamic> toJson() => {
        ...document.toJson(),
        'client_id': clientId,
        'clientId': clientId,
        'clientName': clientName,
        'document_number': document.documentNumber,
        'document_type': document.type == FinancialDocumentType.invoice
            ? 'invoice'
            : 'quote',
        'updatedAtIso': updatedAtIso,
        'version': document.version,
        'deletedAt': document.deletedAtIso,
      };
}

String _serverUpdatedAtIso(Map<String, dynamic> json) {
  return (json['updated_at_iso'] ?? json['updatedAtIso'] ?? '').toString();
}

String? _latestIso(Iterable<String> candidates) {
  String? latest;
  DateTime? latestDate;
  for (final iso in candidates) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) continue;
    if (latestDate == null || parsed.isAfter(latestDate)) {
      latestDate = parsed;
      latest = iso;
    }
  }
  return latest;
}
