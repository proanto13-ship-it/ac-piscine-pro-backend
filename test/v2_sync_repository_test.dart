import 'package:ac_piscine_pro/services/cloud_sync_service.dart';
import 'package:ac_piscine_pro/services/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2SyncRepository pull merges only records newer than sinceIso',
      () async {
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
                  'name': 'Client A (remote)',
                  'display_name': 'Client A (remote)',
                  'phone': '',
                  'email': '',
                  'address': '',
                  'volume': 42.0,
                  'treatment': '',
                  'bassinType': '',
                  'revetement': '',
                  'filtration': '',
                  'equipements': '',
                  'visitFrequencyDays': 14,
                  'notes': '',
                  'analyses': [],
                },
                {
                  'id': 'client_b',
                  'organization_id': 'org_demo',
                  'updated_at_iso': '2026-04-10T12:00:00Z',
                  'createdAtIso': '2026-04-02T10:00:00Z',
                  'name': 'Client B (stale)',
                  'display_name': 'Client B (stale)',
                  'phone': '',
                  'email': '',
                  'address': '',
                  'volume': 10.0,
                  'treatment': '',
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
      sinceIso: '2026-04-12T00:00:00Z',
      basePayload: {
        'clients': [
          {
            'id': 'client_a',
            'name': 'Client A (local)',
            'phone': '',
            'email': '',
            'address': '',
            'volume': 5.0,
            'treatment': '',
            'bassinType': '',
            'revetement': '',
            'filtration': '',
            'equipements': '',
            'visitFrequencyDays': 14,
            'createdAtIso': '2026-04-01T10:00:00Z',
            'notes': '',
            'analyses': [],
            'interventions': [],
            'financialDocuments': [],
          },
          {
            'id': 'client_b',
            'name': 'Client B (local)',
            'phone': '',
            'email': '',
            'address': '',
            'volume': 6.0,
            'treatment': '',
            'bassinType': '',
            'revetement': '',
            'filtration': '',
            'equipements': '',
            'visitFrequencyDays': 14,
            'createdAtIso': '2026-04-02T10:00:00Z',
            'notes': '',
            'analyses': [],
            'interventions': [],
            'financialDocuments': [],
          },
        ],
      },
    );

    expect(result.ok, isTrue);
    final clients =
        (result.payload!['clients'] as List).cast<Map<String, dynamic>>();
    final clientA = clients.firstWhere((item) => item['id'] == 'client_a');
    final clientB = clients.firstWhere((item) => item['id'] == 'client_b');

    expect(clientA['name'], 'Client A (remote)');
    expect(clientA['volume'], 42.0);
    expect(clientB['name'], 'Client B (local)');
    expect(clientB['volume'], 6.0);
  });

  test('V2SyncRepository push upserts clients with POST fallback after 404',
      () async {
    final calls = <String>[];
    final repository = V2SyncRepository(
      transport: ({
        required String method,
        required String endpoint,
        String? apiKey,
        Map<String, dynamic>? payload,
      }) async {
        calls.add('$method $endpoint');
        if (method == 'PUT') {
          return const CloudSyncResult(
            ok: false,
            message: 'missing',
            statusCode: 404,
          );
        }
        return const CloudSyncResult(
          ok: true,
          message: 'created',
          payload: {'data': {}},
          statusCode: 201,
        );
      },
    );

    final result = await repository.push(
      endpoint: 'https://sync.example.com/sync',
      apiKey: 'token',
      payload: {
        'clients': [
          {
            'id': 'client_a',
            'name': 'Client A',
            'phone': '',
            'email': '',
            'address': '',
            'volume': 5.0,
            'treatment': '',
            'bassinType': '',
            'revetement': '',
            'filtration': '',
            'equipements': '',
            'visitFrequencyDays': 14,
            'createdAtIso': '2026-04-01T10:00:00Z',
            'notes': '',
            'analyses': [],
            'interventions': [],
            'financialDocuments': [],
          },
        ],
      },
    );

    expect(result.ok, isTrue);
    expect(
      calls,
      containsAll([
        'PUT https://sync.example.com/v2/clients/client_a',
        'POST https://sync.example.com/v2/clients',
      ]),
    );
  });

  test(
      'V2SyncRepository push uploads pending attachments and persists remoteUrl',
      () async {
    final uploadCalls = <Map<String, String>>[];
    final repository = V2SyncRepository(
      transport: ({
        required String method,
        required String endpoint,
        String? apiKey,
        Map<String, dynamic>? payload,
      }) async {
        return const CloudSyncResult(
          ok: true,
          message: 'ok',
          payload: {'data': {}},
          statusCode: 200,
        );
      },
      mediaUploadTransport: ({
        required String endpoint,
        String? apiKey,
        required Map<String, String> metadata,
        required List<int> bytes,
      }) async {
        uploadCalls.add(metadata);
        expect(bytes, [1, 2, 3]);
        return const CloudSyncResult(
          ok: true,
          message: 'uploaded',
          payload: {
            'data': {
              'id': 'media_1',
              'remoteUrl': '/v2/media/media_1/download',
              'mimeType': 'image/jpeg',
            },
          },
          statusCode: 201,
        );
      },
      binaryReadTransport: (path) async =>
          path == '/tmp/photo-a.jpg' ? <int>[1, 2, 3] : null,
    );

    final result = await repository.push(
      endpoint: 'https://sync.example.com/sync',
      apiKey: 'token',
      payload: {
        'clients': [
          {
            'id': 'client_a',
            'name': 'Client A',
            'phone': '',
            'email': '',
            'address': '',
            'volume': 5.0,
            'treatment': '',
            'bassinType': '',
            'revetement': '',
            'filtration': '',
            'equipements': '',
            'visitFrequencyDays': 14,
            'createdAtIso': '2026-04-01T10:00:00Z',
            'notes': '',
            'analyses': [],
            'financialDocuments': [],
            'interventions': [
              {
                'id': 'intervention_a',
                'createdAtIso': '2026-04-17T08:00:00Z',
                'dateLabel': '17/04/2026',
                'technicianName': 'Alex',
                'clientRepresentative': 'Client',
                'poolSummary': 'Piscine',
                'interventionSummary': 'Nettoyage',
                'recommendations': '',
                'accessNotes': '',
                'followUpLabel': '',
                'estimateLabel': '',
                'estimateApproved': false,
                'interventionCompleted': true,
                'followUpRequired': false,
                'attachments': [
                  {
                    'id': 'media_1',
                    'localPath': '/tmp/photo-a.jpg',
                    'remoteUrl': '',
                    'mimeType': 'image/jpeg',
                    'uploadStatus': 'pending',
                    'createdAtIso': '2026-04-17T08:00:00Z',
                  },
                ],
                'photoPaths': ['/tmp/photo-a.jpg'],
              },
            ],
          },
        ],
      },
    );

    expect(result.ok, isTrue);
    expect(uploadCalls, hasLength(1));
    expect(uploadCalls.single['attachmentId'], 'media_1');
    final clients =
        (result.payload!['clients'] as List).cast<Map<String, dynamic>>();
    final intervention =
        (clients.single['interventions'] as List).cast<Map<String, dynamic>>();
    final attachment = (intervention.single['attachments'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      attachment.single['remoteUrl'],
      'https://sync.example.com/v2/media/media_1/download',
    );
    expect(attachment.single['uploadStatus'], 'uploaded');
    expect(
      (intervention.single['photoPaths'] as List).cast<String>(),
      ['/tmp/photo-a.jpg'],
    );
  });

  test('V2SyncRepository pull downloads remote media when local path is absent',
      () async {
    final savedFiles = <String, List<int>>{};
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
                  'treatment': '',
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
                  'updated_at_iso': '2026-04-17T12:00:00Z',
                  'createdAtIso': '2026-04-17T08:00:00Z',
                  'dateLabel': '17/04/2026',
                  'technicianName': 'Alex',
                  'clientRepresentative': 'Client',
                  'poolSummary': 'Piscine',
                  'interventionSummary': 'Nettoyage',
                  'recommendations': '',
                  'accessNotes': '',
                  'followUpLabel': '',
                  'estimateLabel': '',
                  'estimateApproved': false,
                  'interventionCompleted': true,
                  'followUpRequired': false,
                  'attachments': [
                    {
                      'id': 'media_1',
                      'localPath': '',
                      'remoteUrl': '',
                      'mimeType': 'image/jpeg',
                      'uploadStatus': 'pending',
                      'createdAtIso': '2026-04-17T08:00:00Z',
                    },
                  ],
                },
              ],
            },
          );
        }
        if (method == 'GET' && endpoint.contains('/financial-documents')) {
          return const CloudSyncResult(
            ok: true,
            message: 'documents',
            payload: {'data': []},
          );
        }
        if (method == 'GET' && endpoint.contains('/media')) {
          return const CloudSyncResult(
            ok: true,
            message: 'media',
            payload: {
              'data': [
                {
                  'id': 'media_1',
                  'organization_id': 'org_demo',
                  'client_id': 'client_a',
                  'intervention_id': 'intervention_a',
                  'originalFileName': 'photo-a.jpg',
                  'mimeType': 'image/jpeg',
                  'downloadPath': '/v2/media/media_1/download',
                  'createdAtIso': '2026-04-17T08:00:00Z',
                  'updatedAtIso': '2026-04-17T12:00:00Z',
                },
              ],
            },
          );
        }

        return const CloudSyncResult(
          ok: false,
          message: 'unexpected',
          statusCode: 500,
        );
      },
      mediaDownloadTransport: ({
        required String endpoint,
        String? apiKey,
      }) async {
        expect(
          endpoint,
          'https://sync.example.com/v2/media/media_1/download',
        );
        return const BinarySyncResult(
          ok: true,
          message: 'downloaded',
          bytes: [9, 8, 7],
          statusCode: 200,
        );
      },
      binaryReadTransport: (path) async => null,
      binarySaveTransport: (folderName, fileName, bytes) async {
        final path = '/local/$folderName/$fileName';
        savedFiles[path] = bytes;
        return path;
      },
    );

    final result = await repository.pull(
      endpoint: 'https://sync.example.com/sync',
      apiKey: 'token',
      basePayload: const {'clients': []},
    );

    expect(result.ok, isTrue);
    expect(savedFiles, hasLength(1));
    final clients =
        (result.payload!['clients'] as List).cast<Map<String, dynamic>>();
    final intervention =
        (clients.single['interventions'] as List).cast<Map<String, dynamic>>();
    final attachment = (intervention.single['attachments'] as List)
        .cast<Map<String, dynamic>>();
    expect(attachment.single['localPath'], contains('/local/synced_media/'));
    expect(
      attachment.single['remoteUrl'],
      'https://sync.example.com/v2/media/media_1/download',
    );
    expect(attachment.single['uploadStatus'], 'uploaded');
  });

  test('V2SyncRepository pull keeps local record when local version is newer',
      () async {
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
                  'updated_at_iso': '2026-04-17T11:00:00Z',
                  'version': 2,
                  'createdAtIso': '2026-04-01T10:00:00Z',
                  'name': 'Client A (remote stale)',
                  'display_name': 'Client A (remote stale)',
                  'phone': '',
                  'email': '',
                  'address': '',
                  'volume': 42.0,
                  'treatment': '',
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
      basePayload: {
        'clients': [
          {
            'id': 'client_a',
            'name': 'Client A (local newer)',
            'phone': '',
            'email': '',
            'address': '',
            'volume': 6.0,
            'treatment': '',
            'bassinType': '',
            'revetement': '',
            'filtration': '',
            'equipements': '',
            'visitFrequencyDays': 14,
            'createdAtIso': '2026-04-01T10:00:00Z',
            'updatedAtIso': '2026-04-17T12:00:00Z',
            'version': 3,
            'deletedAtIso': '',
            'notes': '',
            'analyses': [],
            'interventions': [],
            'financialDocuments': [],
          },
        ],
      },
    );

    expect(result.ok, isTrue);
    final clients =
        (result.payload!['clients'] as List).cast<Map<String, dynamic>>();
    expect(clients.single['name'], 'Client A (local newer)');
    expect(clients.single['version'], 3);
  });
}
