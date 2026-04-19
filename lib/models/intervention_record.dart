import 'dart:convert';
import 'dart:typed_data';

import 'intervention_ticket.dart';
import 'media_attachment.dart';

class InterventionRecord {
  final String id;
  final String createdAtIso;
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
  final String? signatureBase64;
  final List<MediaAttachment> attachments;
  final String updatedAtIso;
  final int version;
  final String deletedAtIso;

  const InterventionRecord({
    required this.id,
    required this.createdAtIso,
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
    this.signatureBase64,
    required this.attachments,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  })  : updatedAtIso = updatedAtIso ?? createdAtIso,
        version = version ?? 1,
        deletedAtIso = deletedAtIso ?? '';

  factory InterventionRecord.fromJson(Map<String, dynamic> json) {
    final createdAtIso = json['createdAtIso'] ?? '';
    final attachmentsJson = json['attachments'];
    final attachments = attachmentsJson is List
        ? attachmentsJson
            .map(
              (item) => MediaAttachment.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
        : ((json['photoPaths'] ?? []) as List)
            .map(
              (item) => MediaAttachment.fromLegacyPhotoPath(
                item.toString(),
                createdAtIso: createdAtIso.toString(),
              ),
            )
            .toList();

    return InterventionRecord(
      id: json['id'] ?? '',
      createdAtIso: createdAtIso,
      dateLabel: json['dateLabel'] ?? '',
      technicianName: json['technicianName'] ?? '',
      clientRepresentative: json['clientRepresentative'] ?? '',
      poolSummary: json['poolSummary'] ?? '',
      interventionSummary: json['interventionSummary'] ?? '',
      recommendations: json['recommendations'] ?? '',
      accessNotes: json['accessNotes'] ?? '',
      followUpLabel: json['followUpLabel'] ?? '',
      estimateLabel: json['estimateLabel'] ?? '',
      estimateApproved: json['estimateApproved'] ?? false,
      interventionCompleted: json['interventionCompleted'] ?? false,
      followUpRequired: json['followUpRequired'] ?? false,
      signatureBase64: json['signatureBase64'],
      attachments: attachments,
      updatedAtIso: json['updatedAtIso'] ?? json['updatedAt'] ?? createdAtIso,
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ?? 1,
      deletedAtIso: json['deletedAtIso'] ?? json['deletedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAtIso': createdAtIso,
        'dateLabel': dateLabel,
        'technicianName': technicianName,
        'clientRepresentative': clientRepresentative,
        'poolSummary': poolSummary,
        'interventionSummary': interventionSummary,
        'recommendations': recommendations,
        'accessNotes': accessNotes,
        'followUpLabel': followUpLabel,
        'estimateLabel': estimateLabel,
        'estimateApproved': estimateApproved,
        'interventionCompleted': interventionCompleted,
        'followUpRequired': followUpRequired,
        'signatureBase64': signatureBase64,
        'updatedAtIso': updatedAtIso,
        'updatedAt': updatedAtIso,
        'version': version,
        'deletedAtIso': deletedAtIso,
        'deletedAt': deletedAtIso,
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'photoPaths': photoPaths,
      };

  List<String> get photoPaths => attachments
      .where((item) => item.hasLocalPath)
      .map((item) => item.localPath)
      .toList();

  Uint8List? get signatureBytes {
    if (signatureBase64 == null || signatureBase64!.isEmpty) {
      return null;
    }
    return base64Decode(signatureBase64!);
  }

  InterventionTicketData toTicketData(String clientName) {
    return InterventionTicketData(
      clientName: clientName,
      dateLabel: dateLabel,
      technicianName: technicianName,
      clientRepresentative: clientRepresentative,
      poolSummary: poolSummary,
      interventionSummary: interventionSummary,
      recommendations: recommendations,
      accessNotes: accessNotes,
      followUpLabel: followUpLabel,
      estimateLabel: estimateLabel,
      estimateApproved: estimateApproved,
      interventionCompleted: interventionCompleted,
      followUpRequired: followUpRequired,
    );
  }

  InterventionRecord copyWith({
    String? id,
    String? createdAtIso,
    String? dateLabel,
    String? technicianName,
    String? clientRepresentative,
    String? poolSummary,
    String? interventionSummary,
    String? recommendations,
    String? accessNotes,
    String? followUpLabel,
    String? estimateLabel,
    bool? estimateApproved,
    bool? interventionCompleted,
    bool? followUpRequired,
    String? signatureBase64,
    List<MediaAttachment>? attachments,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  }) {
    return InterventionRecord(
      id: id ?? this.id,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      dateLabel: dateLabel ?? this.dateLabel,
      technicianName: technicianName ?? this.technicianName,
      clientRepresentative: clientRepresentative ?? this.clientRepresentative,
      poolSummary: poolSummary ?? this.poolSummary,
      interventionSummary: interventionSummary ?? this.interventionSummary,
      recommendations: recommendations ?? this.recommendations,
      accessNotes: accessNotes ?? this.accessNotes,
      followUpLabel: followUpLabel ?? this.followUpLabel,
      estimateLabel: estimateLabel ?? this.estimateLabel,
      estimateApproved: estimateApproved ?? this.estimateApproved,
      interventionCompleted:
          interventionCompleted ?? this.interventionCompleted,
      followUpRequired: followUpRequired ?? this.followUpRequired,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      attachments: attachments ?? this.attachments,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      version: version ?? this.version,
      deletedAtIso: deletedAtIso ?? this.deletedAtIso,
    );
  }

  bool get isDeleted => deletedAtIso.trim().isNotEmpty;
}
