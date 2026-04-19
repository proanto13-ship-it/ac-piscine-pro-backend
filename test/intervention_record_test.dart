import 'package:ac_piscine_pro/models/intervention_record.dart';
import 'package:ac_piscine_pro/models/media_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads legacy photoPaths as local attachments', () {
    final record = InterventionRecord.fromJson({
      'id': 'intervention-1',
      'createdAtIso': '2026-04-17T10:15:00.000',
      'dateLabel': '17/04/2026',
      'technicianName': 'Alex',
      'clientRepresentative': 'Client',
      'poolSummary': 'Piscine',
      'interventionSummary': 'RAS',
      'recommendations': '',
      'accessNotes': '',
      'followUpLabel': '',
      'estimateLabel': '',
      'estimateApproved': true,
      'interventionCompleted': true,
      'followUpRequired': false,
      'photoPaths': [
        '/tmp/photo-a.jpg',
        '/tmp/photo-b.png',
      ],
    });

    expect(record.attachments, hasLength(2));
    expect(record.attachments.first.localPath, '/tmp/photo-a.jpg');
    expect(record.attachments.first.uploadStatus, MediaAttachment.pending);
    expect(record.attachments.first.createdAtIso, '2026-04-17T10:15:00.000');
    expect(record.photoPaths, ['/tmp/photo-a.jpg', '/tmp/photo-b.png']);
  });

  test('writes attachments and legacy photoPaths for compatibility', () {
    final record = InterventionRecord(
      id: 'intervention-2',
      createdAtIso: '2026-04-17T11:00:00.000',
      dateLabel: '17/04/2026',
      technicianName: 'Sam',
      clientRepresentative: 'Client',
      poolSummary: 'Piscine',
      interventionSummary: 'Nettoyage',
      recommendations: '',
      accessNotes: '',
      followUpLabel: '',
      estimateLabel: '',
      estimateApproved: false,
      interventionCompleted: true,
      followUpRequired: true,
      attachments: const [
        MediaAttachment(
          id: 'media-1',
          localPath: '/tmp/photo-a.jpg',
          remoteUrl: '',
          mimeType: 'image/jpeg',
          uploadStatus: MediaAttachment.pending,
          createdAtIso: '2026-04-17T11:00:00.000',
        ),
      ],
    );

    final json = record.toJson();

    expect(json['attachments'], isA<List<dynamic>>());
    expect(json['photoPaths'], ['/tmp/photo-a.jpg']);
  });
}
