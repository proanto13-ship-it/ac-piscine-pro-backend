import '../models/client.dart';
import '../models/financial_document.dart';
import '../models/intervention_record.dart';
import '../models/media_attachment.dart';

class SyncMergeService {
  const SyncMergeService._();

  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static int nextVersion(int current) => current <= 0 ? 1 : current + 1;

  static bool prefersIncoming({
    required int existingVersion,
    required String existingUpdatedAtIso,
    required int incomingVersion,
    required String incomingUpdatedAtIso,
  }) {
    if (incomingVersion != existingVersion) {
      return incomingVersion > existingVersion;
    }

    final existingUpdatedAt = DateTime.tryParse(existingUpdatedAtIso);
    final incomingUpdatedAt = DateTime.tryParse(incomingUpdatedAtIso);
    if (incomingUpdatedAt == null) {
      return false;
    }
    if (existingUpdatedAt == null) {
      return true;
    }
    return incomingUpdatedAt.isAfter(existingUpdatedAt);
  }

  static List<Client> mergeClients({
    required List<Client> existing,
    required List<Client> incoming,
  }) {
    final clientsById = <String, Client>{
      for (final item in existing) item.id: item
    };

    for (final candidate in incoming) {
      final current = clientsById[candidate.id];
      if (current == null ||
          prefersIncoming(
            existingVersion: current.version,
            existingUpdatedAtIso: current.updatedAtIso,
            incomingVersion: candidate.version,
            incomingUpdatedAtIso: candidate.updatedAtIso,
          )) {
        clientsById[candidate.id] = _mergeClient(current, candidate);
      }
    }

    final merged = clientsById.values.toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAtIso) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b.createdAtIso) ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });
    return merged;
  }

  static Client _mergeClient(Client? existing, Client incoming) {
    if (existing == null) {
      return incoming;
    }

    return Client(
      id: incoming.id,
      name: incoming.name,
      phone: incoming.phone,
      email: incoming.email,
      address: incoming.address,
      volume: incoming.volume,
      treatment: incoming.treatment,
      bassinType: incoming.bassinType,
      revetement: incoming.revetement,
      filtration: incoming.filtration,
      equipements: incoming.equipements,
      visitFrequencyDays: incoming.visitFrequencyDays,
      createdAtIso: incoming.createdAtIso,
      updatedAtIso: incoming.updatedAtIso,
      version: incoming.version,
      deletedAtIso: incoming.deletedAtIso,
      notes: incoming.notes,
      analyses: incoming.analyses,
      interventions: mergeInterventions(
        existing: existing.interventions,
        incoming: incoming.interventions,
      ),
      financialDocuments: mergeFinancialDocuments(
        existing: existing.financialDocuments,
        incoming: incoming.financialDocuments,
      ),
    );
  }

  static List<InterventionRecord> mergeInterventions({
    required List<InterventionRecord> existing,
    required List<InterventionRecord> incoming,
  }) {
    final items = <String, InterventionRecord>{
      for (final item in existing) item.id: item,
    };
    for (final candidate in incoming) {
      final current = items[candidate.id];
      if (current == null ||
          prefersIncoming(
            existingVersion: current.version,
            existingUpdatedAtIso: current.updatedAtIso,
            incomingVersion: candidate.version,
            incomingUpdatedAtIso: candidate.updatedAtIso,
          )) {
        items[candidate.id] = candidate.copyWith(
          attachments: mergeAttachments(
            existing: current?.attachments ?? const [],
            incoming: candidate.attachments,
          ),
        );
      }
    }

    final merged = items.values.toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAtIso) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b.createdAtIso) ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });
    return merged;
  }

  static List<FinancialDocument> mergeFinancialDocuments({
    required List<FinancialDocument> existing,
    required List<FinancialDocument> incoming,
  }) {
    final items = <String, FinancialDocument>{
      for (final item in existing) item.id: item,
    };
    for (final candidate in incoming) {
      final current = items[candidate.id];
      if (current == null ||
          prefersIncoming(
            existingVersion: current.version,
            existingUpdatedAtIso: current.updatedAtIso,
            incomingVersion: candidate.version,
            incomingUpdatedAtIso: candidate.updatedAtIso,
          )) {
        items[candidate.id] = candidate;
      }
    }

    final merged = items.values.toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAtIso) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b.createdAtIso) ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });
    return merged;
  }

  static List<MediaAttachment> mergeAttachments({
    required List<MediaAttachment> existing,
    required List<MediaAttachment> incoming,
  }) {
    final items = <String, MediaAttachment>{
      for (final item in existing) item.id: item,
    };
    for (final candidate in incoming) {
      final current = items[candidate.id];
      if (current == null ||
          prefersIncoming(
            existingVersion: current.version,
            existingUpdatedAtIso: current.updatedAtIso,
            incomingVersion: candidate.version,
            incomingUpdatedAtIso: candidate.updatedAtIso,
          )) {
        items[candidate.id] = candidate;
      }
    }
    return items.values.toList();
  }
}
