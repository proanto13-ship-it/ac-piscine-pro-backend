import 'package:ac_piscine_pro/models/client.dart';
import 'package:ac_piscine_pro/models/intervention_record.dart';
import 'package:ac_piscine_pro/models/media_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Client JSON roundtrip preserves interventions and photo attachments',
      () {
    final client = Client(
      id: 'client_1',
      name: 'Piscine Martin',
      phone: '0102030405',
      email: 'martin@example.test',
      address: '1 rue du Test',
      volume: 42,
      treatment: 'chlore',
      bassinType: 'Enterree',
      revetement: 'Liner',
      filtration: 'Sable',
      equipements: 'PAC',
      visitFrequencyDays: 14,
      createdAtIso: '2026-04-17T10:00:00Z',
      notes: 'Client prioritaire',
      analyses: const [],
      interventions: const [
        InterventionRecord(
          id: 'intervention_1',
          createdAtIso: '2026-04-17T11:00:00Z',
          dateLabel: '17/04/2026',
          technicianName: 'Alex',
          clientRepresentative: 'Mme Martin',
          poolSummary: '42 m3 • chlore',
          interventionSummary: 'Lavage filtre',
          recommendations: 'Controle dans 7 jours',
          accessNotes: 'Portillon cote jardin',
          followUpLabel: 'Stabilisation 48h',
          estimateLabel: '120 EUR',
          estimateApproved: true,
          interventionCompleted: true,
          followUpRequired: true,
          attachments: [
            MediaAttachment(
              id: 'media_1',
              localPath: '/tmp/intervention_1.jpg',
              remoteUrl: '',
              mimeType: 'image/jpeg',
              uploadStatus: 'local',
              createdAtIso: '2026-04-17T11:05:00Z',
            ),
          ],
        ),
      ],
      financialDocuments: const [],
    );

    final restored = Client.fromJson(client.toJson());

    expect(restored.name, 'Piscine Martin');
    expect(restored.interventions, hasLength(1));
    expect(restored.interventions.first.attachments, hasLength(1));
    expect(
      restored.interventions.first.attachments.first.localPath,
      '/tmp/intervention_1.jpg',
    );
    expect(
      restored.interventions.first.photoPaths,
      ['/tmp/intervention_1.jpg'],
    );
  });
}
