import 'package:ac_piscine_pro/services/cloud_sync_service.dart';
import 'package:ac_piscine_pro/services/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2SyncRepository pull preserves intervention photo metadata', () async {
    final repository = V2SyncRepository(
      transport: ({
        required String method,
        required String endpoint,
        String? apiKey,
        Map<String, dynamic>? payload,
      }) async {
        if (method == 'GET' && endpoint.contains('/clients')) {
          return const CloudSyncResult(
            ok: true,
            message: 'clients',
            payload: {
              'data': [
                {
                  'id': 'client_a',
                  'organization_id': 'org_demo',
                  'updated_at_iso': '2026-04-17T12:00:00Z',
                  'createdAtIso': '2026-04-01T10:00:00Z',
                  'name': 'Client A',
                  'display_name': 'Client A',
                  'phone': '',
                  'email': '',
                  'address': '',
                  'volume': 42.0,
                  'treatment': 'chlore',
                  'bassinType': '',
                  'revetement': '',
                  'filtration': '',
                  'equipements': '',
                  'visitFrequencyDays': 14,
                  'notes': '',
                  'analyses': [],
                },
              ],
            },
          );
        }

        if (method == 'GET' && endpoint.contains('/interventions')) {
          return const CloudSyncResult(
            ok: true,
            message: 'interventions',
            payload: {
              'data': [
                {
                  'id': 'intervention_a',
                  'organization_id': 'org_demo',
                  'client_id': 'client_a',
                  'clientName': 'Client A',
                  'updated_at_iso': '2026-04-17T12:10:00Z',
                  'createdAtIso': '2026-04-17T12:00:00Z',
                  'dateLabel': '17/04/2026',
                  'technicianName': 'Alex',
                  'clientRepresentative': 'Mme Martin',
                  'poolSummary': '42 m3 • chlore',
                  'interventionSummary': 'Contre-lavage filtre',
                  'recommendations': 'Controle dans 7 jours',
                  'accessNotes': 'RAS',
                  'followUpLabel': '48h',
                  'estimateLabel': '120 EUR',
                  'estimateApproved': true,
                  'interventionCompleted': true,
                  'followUpRequired': true,
                  'attachments': [
                    {
                      'id': 'media_1',
                      'localPath': '/tmp/photo-a.jpg',
                      'remoteUrl': '',
                      'mimeType': 'image/jpeg',
                      'uploadStatus': 'local',
                      'createdAtIso': '2026-04-17T12:01:00Z',
                    },
                  ],
                },
              ],
            },
          );
        }

        return const CloudSyncResult(
          ok: true,
          message: 'empty',
          payload: {'data': []},
        );
      },
    );

    final result = await repository.pull(
      endpoint: 'https://sync.example.com',
      apiKey: 'token',
      basePayload: const {
        'clients': [],
      },
    );

    expect(result.ok, isTrue);
    final clients =
        (result.payload!['clients'] as List).cast<Map<String, dynamic>>();
    expect(clients, hasLength(1));

    final interventions =
        (clients.first['interventions'] as List).cast<Map<String, dynamic>>();
    expect(interventions, hasLength(1));
    expect(interventions.first['attachments'], isA<List<dynamic>>());
    expect(
      (interventions.first['photoPaths'] as List).cast<String>(),
      ['/tmp/photo-a.jpg'],
    );
  });
}
