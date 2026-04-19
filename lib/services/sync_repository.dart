import 'dart:convert';
import 'dart:io';

import '../models/client.dart';
import '../models/media_attachment.dart';
import '../models/v2_sync_dtos.dart';
import 'cloud_sync_service.dart';
import 'local_storage_service.dart';
import 'sync_merge_service.dart';

typedef SyncPushTransport = Future<CloudSyncResult> Function({
  required String endpoint,
  String? apiKey,
  required Map<String, dynamic> payload,
});

typedef SyncPullTransport = Future<CloudSyncResult> Function({
  required String endpoint,
  String? apiKey,
});

typedef V2SyncTransport = Future<CloudSyncResult> Function({
  required String method,
  required String endpoint,
  String? apiKey,
  Map<String, dynamic>? payload,
});

typedef V2MediaUploadTransport = Future<CloudSyncResult> Function({
  required String endpoint,
  String? apiKey,
  required Map<String, String> metadata,
  required List<int> bytes,
});

typedef BinaryReadTransport = Future<List<int>?> Function(String path);
typedef BinarySaveTransport = Future<String> Function(
  String folderName,
  String fileName,
  List<int> bytes,
);

typedef V2MediaDownloadTransport = Future<BinarySyncResult> Function({
  required String endpoint,
  String? apiKey,
});

abstract class SyncRepository {
  const SyncRepository();

  Future<CloudSyncResult> push({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  });

  Future<CloudSyncResult> pull({
    required String endpoint,
    String? apiKey,
    Map<String, dynamic>? basePayload,
    String? sinceIso,
  });

  Future<CloudSyncResult> syncClients({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  });

  Future<CloudSyncResult> syncInterventions({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  });

  Future<CloudSyncResult> syncDocuments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  });

  Future<CloudSyncResult> syncAttachments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  });
}

class LegacyCloudSyncRepository implements SyncRepository {
  final SyncPushTransport _pushTransport;
  final SyncPullTransport _pullTransport;

  const LegacyCloudSyncRepository({
    SyncPushTransport pushTransport = CloudSyncService.push,
    SyncPullTransport pullTransport = CloudSyncService.pull,
  })  : _pushTransport = pushTransport,
        _pullTransport = pullTransport;

  @override
  Future<CloudSyncResult> push({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) {
    return _pushTransport(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: payload,
    );
  }

  @override
  Future<CloudSyncResult> pull({
    required String endpoint,
    String? apiKey,
    Map<String, dynamic>? basePayload,
    String? sinceIso,
  }) {
    return _pullTransport(
      endpoint: endpoint,
      apiKey: apiKey,
    );
  }

  @override
  Future<CloudSyncResult> syncClients({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) {
    return push(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: payload,
    );
  }

  @override
  Future<CloudSyncResult> syncInterventions({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) {
    return push(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: payload,
    );
  }

  @override
  Future<CloudSyncResult> syncDocuments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) {
    return push(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: payload,
    );
  }

  @override
  Future<CloudSyncResult> syncAttachments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) {
    return push(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: payload,
    );
  }
}

class V2SyncRepository implements SyncRepository {
  final V2SyncTransport _transport;
  final V2MediaUploadTransport _mediaUploadTransport;
  final V2MediaDownloadTransport _mediaDownloadTransport;
  final BinaryReadTransport _binaryReadTransport;
  final BinarySaveTransport _binarySaveTransport;

  const V2SyncRepository({
    V2SyncTransport transport = _defaultTransport,
    V2MediaUploadTransport mediaUploadTransport = _defaultMediaUploadTransport,
    V2MediaDownloadTransport mediaDownloadTransport =
        _defaultMediaDownloadTransport,
    BinaryReadTransport binaryReadTransport = LocalStorageService.readBinary,
    BinarySaveTransport binarySaveTransport = LocalStorageService.saveBinary,
  })  : _transport = transport,
        _mediaUploadTransport = mediaUploadTransport,
        _mediaDownloadTransport = mediaDownloadTransport,
        _binaryReadTransport = binaryReadTransport,
        _binarySaveTransport = binarySaveTransport;

  @override
  Future<CloudSyncResult> push({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final workingPayload = _deepCopyPayload(payload);

    final clientsResult = await syncClients(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: workingPayload,
    );
    if (!clientsResult.ok) {
      return clientsResult;
    }

    final interventionsResult = await syncInterventions(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: workingPayload,
    );
    if (!interventionsResult.ok) {
      return interventionsResult;
    }

    final documentsResult = await syncDocuments(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: workingPayload,
    );
    if (!documentsResult.ok) {
      return documentsResult;
    }

    final attachmentsResult = await syncAttachments(
      endpoint: endpoint,
      apiKey: apiKey,
      payload: workingPayload,
    );
    final updatedPayload = attachmentsResult.payload ?? workingPayload;
    final reconciliationResult = await pull(
      endpoint: endpoint,
      apiKey: apiKey,
      basePayload: updatedPayload,
    );
    final finalPayload =
        reconciliationResult.ok && reconciliationResult.payload != null
            ? reconciliationResult.payload!
            : updatedPayload;
    final snapshot = _snapshotFromPayload(finalPayload);
    return CloudSyncResult(
      ok: true,
      message:
          'Synchronisation V2 envoyee (${snapshot.clients.length} clients, '
          '${snapshot.interventions.length} interventions, '
          '${snapshot.documents.length} documents). '
          '${attachmentsResult.message}',
      payload: finalPayload,
    );
  }

  @override
  Future<CloudSyncResult> pull({
    required String endpoint,
    String? apiKey,
    Map<String, dynamic>? basePayload,
    String? sinceIso,
  }) async {
    final clientsResult = await _fetchResourceList(
      endpoint: endpoint,
      apiKey: apiKey,
      resourcePath: 'clients',
      sinceIso: sinceIso,
    );
    if (!clientsResult.ok) {
      return clientsResult;
    }

    final interventionsResult = await _fetchResourceList(
      endpoint: endpoint,
      apiKey: apiKey,
      resourcePath: 'interventions',
      sinceIso: sinceIso,
    );
    if (!interventionsResult.ok) {
      return interventionsResult;
    }

    final documentsResult = await _fetchResourceList(
      endpoint: endpoint,
      apiKey: apiKey,
      resourcePath: 'financial-documents',
      sinceIso: sinceIso,
    );
    if (!documentsResult.ok) {
      return documentsResult;
    }

    final mergedPayload = _mergePulledPayload(
      basePayload: basePayload,
      clientRecords: _decodeDataList(clientsResult.payload),
      interventionRecords: _decodeDataList(interventionsResult.payload),
      documentRecords: _decodeDataList(documentsResult.payload),
      sinceIso: sinceIso,
    );

    final mediaResult = await _fetchResourceList(
      endpoint: endpoint,
      apiKey: apiKey,
      resourcePath: 'media',
      sinceIso: sinceIso,
    );
    final mergedWithMedia = mediaResult.ok
        ? await _mergePulledMediaPayload(
            payload: mergedPayload,
            mediaRecords: _decodeDataList(mediaResult.payload),
            endpoint: endpoint,
            apiKey: apiKey,
          )
        : mergedPayload;
    final message = mediaResult.ok
        ? 'Synchronisation V2 recuperée.'
        : 'Synchronisation V2 recuperée (medias distants indisponibles, '
            'fallback local conserve).';

    return CloudSyncResult(
      ok: true,
      message: message,
      payload: mergedWithMedia,
    );
  }

  @override
  Future<CloudSyncResult> syncClients({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final snapshot = _snapshotFromPayload(payload);
    for (final client in snapshot.clients) {
      final result = await _upsertResource(
        endpoint: endpoint,
        apiKey: apiKey,
        resourcePath: 'clients',
        recordId: client.client.id,
        payload: client.toJson(),
      );
      if (!result.ok) {
        return result;
      }
    }

    return CloudSyncResult(
      ok: true,
      message: 'Clients V2 synchronises (${snapshot.clients.length}).',
      payload: {'count': snapshot.clients.length},
    );
  }

  @override
  Future<CloudSyncResult> syncInterventions({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final snapshot = _snapshotFromPayload(payload);
    for (final intervention in snapshot.interventions) {
      final result = await _upsertResource(
        endpoint: endpoint,
        apiKey: apiKey,
        resourcePath: 'interventions',
        recordId: intervention.intervention.id,
        payload: intervention.toJson(),
      );
      if (!result.ok) {
        return result;
      }
    }

    return CloudSyncResult(
      ok: true,
      message:
          'Interventions V2 synchronisees (${snapshot.interventions.length}).',
      payload: {'count': snapshot.interventions.length},
    );
  }

  @override
  Future<CloudSyncResult> syncDocuments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final snapshot = _snapshotFromPayload(payload);
    for (final document in snapshot.documents) {
      final result = await _upsertResource(
        endpoint: endpoint,
        apiKey: apiKey,
        resourcePath: 'financial-documents',
        recordId: document.document.id,
        payload: document.toJson(),
      );
      if (!result.ok) {
        return result;
      }
    }

    return CloudSyncResult(
      ok: true,
      message: 'Documents V2 synchronises (${snapshot.documents.length}).',
      payload: {'count': snapshot.documents.length},
    );
  }

  @override
  Future<CloudSyncResult> syncAttachments({
    required String endpoint,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final workingPayload = _deepCopyPayload(payload);
    final clients = ((workingPayload['clients'] ?? const []) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    var uploadedCount = 0;
    var failedCount = 0;
    var skippedCount = 0;

    for (final client in clients) {
      final clientId = (client['id'] ?? '').toString();
      final interventions = ((client['interventions'] ?? const []) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      for (var interventionIndex = 0;
          interventionIndex < interventions.length;
          interventionIndex++) {
        final intervention = interventions[interventionIndex];
        final interventionId = (intervention['id'] ?? '').toString();
        final attachments = ((intervention['attachments'] ?? const []) as List)
            .map(
              (item) => MediaAttachment.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        final updatedAttachments = <MediaAttachment>[];

        for (final attachment in attachments) {
          if (!attachment.needsUpload) {
            skippedCount++;
            updatedAttachments.add(
              attachment.copyWith(
                uploadStatus: attachment.hasRemoteUrl
                    ? MediaAttachment.uploaded
                    : attachment.uploadStatus,
              ),
            );
            continue;
          }

          final uploadingAttachment = attachment.copyWith(
            uploadStatus: MediaAttachment.uploading,
          );
          final bytes =
              await _binaryReadTransport(uploadingAttachment.localPath);
          if (bytes == null || bytes.isEmpty) {
            failedCount++;
            updatedAttachments.add(
              uploadingAttachment.copyWith(
                uploadStatus: MediaAttachment.failed,
              ),
            );
            continue;
          }

          final uploadResult = await _mediaUploadTransport(
            endpoint: _resourceEndpoint(endpoint, 'media/upload'),
            apiKey: apiKey,
            metadata: {
              'attachmentId': uploadingAttachment.id,
              'clientId': clientId,
              'interventionId': interventionId,
              'fileName': _attachmentFileName(uploadingAttachment),
              'mimeType': uploadingAttachment.mimeType,
              'createdAtIso': uploadingAttachment.createdAtIso,
            },
            bytes: bytes,
          );

          if (!uploadResult.ok) {
            failedCount++;
            updatedAttachments.add(
              uploadingAttachment.copyWith(
                uploadStatus: MediaAttachment.failed,
              ),
            );
            continue;
          }

          final payloadData = _extractDataMap(uploadResult.payload);
          final remoteUrl = _resolveRemoteUrl(
            endpoint,
            payloadData?['remoteUrl']?.toString() ??
                payloadData?['downloadPath']?.toString() ??
                '',
          );
          uploadedCount++;
          updatedAttachments.add(
            uploadingAttachment.copyWith(
              remoteUrl: remoteUrl,
              mimeType:
                  payloadData?['mimeType']?.toString().trim().isNotEmpty == true
                      ? payloadData!['mimeType'].toString()
                      : uploadingAttachment.mimeType,
              uploadStatus: MediaAttachment.uploaded,
              updatedAtIso: payloadData?['updatedAtIso']?.toString() ??
                  payloadData?['updatedAt']?.toString() ??
                  uploadingAttachment.updatedAtIso,
              version: payloadData?['version'] is int
                  ? payloadData!['version'] as int
                  : int.tryParse(payloadData?['version']?.toString() ?? '') ??
                      uploadingAttachment.version,
              deletedAtIso: payloadData?['deletedAt']?.toString() ??
                  uploadingAttachment.deletedAtIso,
            ),
          );
        }

        intervention['attachments'] =
            updatedAttachments.map((item) => item.toJson()).toList();
        intervention['photoPaths'] = updatedAttachments
            .where((item) => item.hasLocalPath)
            .map((item) => item.localPath)
            .toList();
        interventions[interventionIndex] = intervention;
      }

      client['interventions'] = interventions;
    }

    workingPayload['clients'] = clients;
    return CloudSyncResult(
      ok: true,
      message:
          'Pieces jointes V2: $uploadedCount upload(s), $failedCount echec(s), '
          '$skippedCount deja disponibles.',
      payload: workingPayload,
    );
  }

  Future<CloudSyncResult> _fetchResourceList({
    required String endpoint,
    required String resourcePath,
    String? apiKey,
    String? sinceIso,
  }) {
    final resourceEndpoint = _resourceEndpoint(
      endpoint,
      resourcePath,
      sinceIso: sinceIso,
    );
    return _transport(
      method: 'GET',
      endpoint: resourceEndpoint,
      apiKey: apiKey,
    );
  }

  Future<CloudSyncResult> _upsertResource({
    required String endpoint,
    required String resourcePath,
    required String recordId,
    String? apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final updateResult = await _transport(
      method: 'PUT',
      endpoint: _resourceEndpoint(endpoint, '$resourcePath/$recordId'),
      apiKey: apiKey,
      payload: payload,
    );
    if (updateResult.ok || updateResult.statusCode != 404) {
      if (updateResult.ok || updateResult.statusCode != 409) {
        return updateResult;
      }

      final currentResult = await _transport(
        method: 'GET',
        endpoint: _resourceEndpoint(endpoint, '$resourcePath/$recordId'),
        apiKey: apiKey,
      );
      if (currentResult.ok) {
        return CloudSyncResult(
          ok: true,
          message:
              'Conflit detecte sur $resourcePath/$recordId, etat distant conserve.',
          payload: currentResult.payload,
          statusCode: 409,
        );
      }
      return updateResult;
    }

    return _transport(
      method: 'POST',
      endpoint: _resourceEndpoint(endpoint, resourcePath),
      apiKey: apiKey,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> _mergePulledMediaPayload({
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> mediaRecords,
    required String endpoint,
    String? apiKey,
  }) async {
    final workingPayload = _deepCopyPayload(payload);
    final clients = ((workingPayload['clients'] ?? const []) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final mediaByIntervention = <String, List<Map<String, dynamic>>>{};

    for (final mediaRecord in mediaRecords) {
      final interventionId = (mediaRecord['intervention_id'] ??
              mediaRecord['interventionId'] ??
              '')
          .toString();
      if (interventionId.isEmpty) {
        continue;
      }
      mediaByIntervention
          .putIfAbsent(interventionId, () => [])
          .add(mediaRecord);
    }

    for (final client in clients) {
      final interventions = ((client['interventions'] ?? const []) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      for (var interventionIndex = 0;
          interventionIndex < interventions.length;
          interventionIndex++) {
        final intervention = interventions[interventionIndex];
        final interventionId = (intervention['id'] ?? '').toString();
        final remoteMedia = mediaByIntervention[interventionId] ?? const [];
        if (remoteMedia.isEmpty) {
          continue;
        }

        final attachments = ((intervention['attachments'] ?? const []) as List)
            .map(
              (item) => MediaAttachment.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        final remoteById = <String, Map<String, dynamic>>{
          for (final item in remoteMedia) (item['id'] ?? '').toString(): item,
        };
        final updatedAttachments = <MediaAttachment>[];

        for (final attachment in attachments) {
          final remoteRecord = remoteById.remove(attachment.id);
          if (remoteRecord == null) {
            updatedAttachments.add(attachment);
            continue;
          }
          updatedAttachments.add(
            await _hydrateAttachmentFromRemote(
              attachment: attachment,
              remoteRecord: remoteRecord,
              endpoint: endpoint,
              apiKey: apiKey,
            ),
          );
        }

        for (final remoteRecord in remoteById.values) {
          updatedAttachments.add(
            await _hydrateAttachmentFromRemote(
              attachment: MediaAttachment.fromJson({
                'id': remoteRecord['id'] ?? '',
                'localPath': '',
                'remoteUrl': remoteRecord['remoteUrl'] ??
                    remoteRecord['downloadPath'] ??
                    '',
                'mimeType': remoteRecord['mimeType'] ?? '',
                'uploadStatus': MediaAttachment.uploaded,
                'createdAtIso': remoteRecord['createdAtIso'] ?? '',
                'updatedAtIso': remoteRecord['updatedAtIso'] ??
                    remoteRecord['updatedAt'] ??
                    '',
                'version': remoteRecord['version'] ?? 1,
                'deletedAt': remoteRecord['deletedAt'] ?? '',
              }),
              remoteRecord: remoteRecord,
              endpoint: endpoint,
              apiKey: apiKey,
            ),
          );
        }

        intervention['attachments'] =
            updatedAttachments.map((item) => item.toJson()).toList();
        intervention['photoPaths'] = updatedAttachments
            .where((item) => item.hasLocalPath)
            .map((item) => item.localPath)
            .toList();
        interventions[interventionIndex] = intervention;
      }

      client['interventions'] = interventions;
    }

    workingPayload['clients'] = clients;
    return workingPayload;
  }

  Future<MediaAttachment> _hydrateAttachmentFromRemote({
    required MediaAttachment attachment,
    required Map<String, dynamic> remoteRecord,
    required String endpoint,
    String? apiKey,
  }) async {
    final remoteUrl = _resolveRemoteUrl(
      endpoint,
      remoteRecord['remoteUrl']?.toString() ??
          remoteRecord['downloadPath']?.toString() ??
          attachment.remoteUrl,
    );
    var merged = attachment.copyWith(
      remoteUrl: remoteUrl,
      mimeType: remoteRecord['mimeType']?.toString().trim().isNotEmpty == true
          ? remoteRecord['mimeType'].toString()
          : attachment.mimeType,
      createdAtIso:
          remoteRecord['createdAtIso']?.toString() ?? attachment.createdAtIso,
      updatedAtIso: remoteRecord['updatedAtIso']?.toString() ??
          remoteRecord['updatedAt']?.toString() ??
          attachment.updatedAtIso,
      version: remoteRecord['version'] is int
          ? remoteRecord['version'] as int
          : int.tryParse(remoteRecord['version']?.toString() ?? '') ??
              attachment.version,
      deletedAtIso:
          remoteRecord['deletedAt']?.toString() ?? attachment.deletedAtIso,
      uploadStatus: remoteUrl.isNotEmpty
          ? MediaAttachment.uploaded
          : attachment.uploadStatus,
    );

    if (remoteUrl.isEmpty || await _hasUsableLocalFile(merged.localPath)) {
      return merged;
    }

    final downloadResult = await _mediaDownloadTransport(
      endpoint: remoteUrl,
      apiKey: apiKey,
    );
    final bytes = downloadResult.bytes;
    if (!downloadResult.ok || bytes == null || bytes.isEmpty) {
      return merged;
    }

    final filePath = await _binarySaveTransport(
      'synced_media',
      _mediaFileName(remoteRecord, merged),
      bytes,
    );
    return merged.copyWith(localPath: filePath);
  }

  Future<bool> _hasUsableLocalFile(String path) async {
    if (path.trim().isEmpty) {
      return false;
    }
    final bytes = await _binaryReadTransport(path);
    return bytes != null && bytes.isNotEmpty;
  }

  static Future<CloudSyncResult> _defaultTransport({
    required String method,
    required String endpoint,
    String? apiKey,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      late HttpClientRequest request;
      switch (method.toUpperCase()) {
        case 'GET':
          request = await client.getUrl(uri);
          break;
        case 'POST':
          request = await client.postUrl(uri);
          break;
        case 'PUT':
          request = await client.putUrl(uri);
          break;
        default:
          return CloudSyncResult(
            ok: false,
            message: 'Methode HTTP non supportee: $method',
          );
      }

      _applyHeaders(request, apiKey);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      client.close();

      final decodedPayload = _tryParseMap(raw);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CloudSyncResult(
          ok: true,
          message: _parseMessage(
            raw,
            fallback: 'Synchronisation V2 reussie.',
          ),
          payload: decodedPayload,
          statusCode: response.statusCode,
        );
      }

      return CloudSyncResult(
        ok: false,
        message: _parseMessage(
          raw,
          fallback: 'Erreur HTTP ${response.statusCode} pendant la synchro V2.',
        ),
        payload: decodedPayload,
        statusCode: response.statusCode,
      );
    } on FormatException {
      return const CloudSyncResult(
        ok: false,
        message: 'Endpoint V2 invalide.',
      );
    } on SocketException catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Connexion au cloud impossible : ${error.message}',
      );
    } catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Synchronisation V2 impossible : $error',
      );
    }
  }

  static Future<CloudSyncResult> _defaultMediaUploadTransport({
    required String endpoint,
    String? apiKey,
    required Map<String, String> metadata,
    required List<int> bytes,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      _applyHeaders(request, apiKey);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        metadata['mimeType']?.trim().isNotEmpty == true
            ? metadata['mimeType']!
            : 'application/octet-stream',
      );
      request.headers.set('X-Attachment-Id', metadata['attachmentId'] ?? '');
      request.headers.set('X-Client-Id', metadata['clientId'] ?? '');
      request.headers.set(
        'X-Intervention-Id',
        metadata['interventionId'] ?? '',
      );
      request.headers.set('X-File-Name', metadata['fileName'] ?? '');
      request.headers.set('X-Mime-Type', metadata['mimeType'] ?? '');
      request.headers.set('X-Created-At-Iso', metadata['createdAtIso'] ?? '');
      request.add(bytes);

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      client.close();

      final decodedPayload = _tryParseMap(raw);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CloudSyncResult(
          ok: true,
          message: _parseMessage(
            raw,
            fallback: 'Upload media V2 reussi.',
          ),
          payload: decodedPayload,
          statusCode: response.statusCode,
        );
      }

      return CloudSyncResult(
        ok: false,
        message: _parseMessage(
          raw,
          fallback:
              'Erreur HTTP ${response.statusCode} pendant l’upload media.',
        ),
        payload: decodedPayload,
        statusCode: response.statusCode,
      );
    } on FormatException {
      return const CloudSyncResult(
        ok: false,
        message: 'Endpoint media V2 invalide.',
      );
    } on SocketException catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Upload media impossible : ${error.message}',
      );
    } catch (error) {
      return CloudSyncResult(
        ok: false,
        message: 'Upload media V2 impossible : $error',
      );
    }
  }

  static Future<BinarySyncResult> _defaultMediaDownloadTransport({
    required String endpoint,
    String? apiKey,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      _applyHeaders(request, apiKey);
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BinarySyncResult(
          ok: true,
          message: 'Download media V2 reussi.',
          bytes: bytes,
          statusCode: response.statusCode,
        );
      }

      return BinarySyncResult(
        ok: false,
        message:
            'Erreur HTTP ${response.statusCode} pendant le download media.',
        statusCode: response.statusCode,
      );
    } on FormatException {
      return const BinarySyncResult(
        ok: false,
        message: 'Endpoint media V2 invalide.',
      );
    } on SocketException catch (error) {
      return BinarySyncResult(
        ok: false,
        message: 'Download media impossible : ${error.message}',
      );
    } catch (error) {
      return BinarySyncResult(
        ok: false,
        message: 'Download media V2 impossible : $error',
      );
    }
  }
}

class BinarySyncResult {
  final bool ok;
  final String message;
  final List<int>? bytes;
  final int? statusCode;

  const BinarySyncResult({
    required this.ok,
    required this.message,
    this.bytes,
    this.statusCode,
  });
}

Map<String, dynamic> _deepCopyPayload(Map<String, dynamic> payload) {
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
  );
}

Map<String, dynamic>? _extractDataMap(Map<String, dynamic>? payload) {
  if (payload == null) {
    return null;
  }
  final data = payload['data'];
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return payload;
}

String _resolveRemoteUrl(String endpoint, String rawUrl) {
  final normalized = rawUrl.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final uri = Uri.parse(normalized);
  if (uri.hasScheme) {
    return uri.toString();
  }
  return Uri.parse(endpoint).resolveUri(uri).toString();
}

String _attachmentFileName(MediaAttachment attachment) {
  if (attachment.localPath.trim().isNotEmpty) {
    final normalized = attachment.localPath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    final candidate = segments.isEmpty ? '' : segments.last.trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }

  final remoteUri = Uri.tryParse(attachment.remoteUrl);
  final remoteSegments = remoteUri?.pathSegments ?? const <String>[];
  if (remoteSegments.isNotEmpty && remoteSegments.last.trim().isNotEmpty) {
    return remoteSegments.last.trim();
  }
  return '${attachment.id.isEmpty ? 'attachment' : attachment.id}.bin';
}

String _mediaFileName(
  Map<String, dynamic> remoteRecord,
  MediaAttachment attachment,
) {
  final preferred = (remoteRecord['originalFileName'] ?? '').toString().trim();
  final baseName =
      preferred.isNotEmpty ? preferred : _attachmentFileName(attachment);
  final sanitized = baseName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return sanitized.isEmpty
      ? '${attachment.id.isEmpty ? 'attachment' : attachment.id}.bin'
      : sanitized;
}

class _V2SyncSnapshot {
  final List<V2ClientDto> clients;
  final List<V2InterventionDto> interventions;
  final List<V2FinancialDocumentDto> documents;

  const _V2SyncSnapshot({
    required this.clients,
    required this.interventions,
    required this.documents,
  });
}

_V2SyncSnapshot _snapshotFromPayload(Map<String, dynamic> payload) {
  final clients = ((payload['clients'] ?? []) as List)
      .map((item) => Client.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();

  return _V2SyncSnapshot(
    clients: clients.map(V2ClientDto.fromClient).toList(),
    interventions: [
      for (final client in clients)
        for (final intervention in client.interventions)
          V2InterventionDto.fromClient(client, intervention),
    ],
    documents: [
      for (final client in clients)
        for (final document in client.financialDocuments)
          V2FinancialDocumentDto.fromClient(client, document),
    ],
  );
}

Map<String, dynamic> _mergePulledPayload({
  Map<String, dynamic>? basePayload,
  required List<Map<String, dynamic>> clientRecords,
  required List<Map<String, dynamic>> interventionRecords,
  required List<Map<String, dynamic>> documentRecords,
  String? sinceIso,
}) {
  final mergedPayload = Map<String, dynamic>.from(basePayload ?? const {});
  final baseClients = ((mergedPayload['clients'] ?? const []) as List)
      .map((item) => Client.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
  final clientsById = <String, Client>{
    for (final client in baseClients) client.id: client
  };

  for (final dto in clientRecords
      .map(V2ClientDto.fromJson)
      .where((item) => _isNewerThan(item.updatedAtIso, sinceIso))) {
    final existing = clientsById[dto.client.id];
    clientsById[dto.client.id] = SyncMergeService.mergeClients(
      existing: existing == null ? const [] : [existing],
      incoming: [dto.client],
    ).single;
  }

  for (final dto in interventionRecords
      .map(V2InterventionDto.fromJson)
      .where((item) => _isNewerThan(item.updatedAtIso, sinceIso))) {
    final client = clientsById.putIfAbsent(
      dto.clientId,
      () => _placeholderClient(dto.clientId, dto.clientName),
    );
    client.interventions = SyncMergeService.mergeInterventions(
      existing: client.interventions,
      incoming: [dto.intervention],
    );
  }

  for (final dto in documentRecords
      .map(V2FinancialDocumentDto.fromJson)
      .where((item) => _isNewerThan(item.updatedAtIso, sinceIso))) {
    final client = clientsById.putIfAbsent(
      dto.clientId,
      () => _placeholderClient(dto.clientId, dto.clientName),
    );
    client.financialDocuments = SyncMergeService.mergeFinancialDocuments(
      existing: client.financialDocuments,
      incoming: [dto.document],
    );
  }

  final mergedClients = SyncMergeService.mergeClients(
    existing: const [],
    incoming: clientsById.values.toList(),
  );
  mergedPayload['clients'] =
      mergedClients.map((client) => client.toJson()).toList();
  return mergedPayload;
}

Client _placeholderClient(String clientId, String clientName) {
  return Client(
    id: clientId,
    name: clientName,
    phone: '',
    email: '',
    address: '',
    volume: 0,
    treatment: '',
    bassinType: '',
    revetement: '',
    filtration: '',
    equipements: '',
    visitFrequencyDays: 14,
    createdAtIso: '',
    updatedAtIso: '',
    version: 1,
    deletedAtIso: '',
    notes: '',
    analyses: [],
    interventions: [],
    financialDocuments: [],
  );
}

List<Map<String, dynamic>> _decodeDataList(Map<String, dynamic>? payload) {
  if (payload == null || payload['data'] is! List) {
    return const [];
  }
  return (payload['data'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

bool _isNewerThan(String updatedAtIso, String? sinceIso) {
  final normalizedSinceIso = sinceIso?.trim() ?? '';
  if (normalizedSinceIso.isEmpty) {
    return true;
  }

  final updatedAt = DateTime.tryParse(updatedAtIso);
  final sinceAt = DateTime.tryParse(normalizedSinceIso);
  if (updatedAt == null || sinceAt == null) {
    return true;
  }
  return updatedAt.isAfter(sinceAt);
}

String _resourceEndpoint(
  String endpoint,
  String resourcePath, {
  String? sinceIso,
}) {
  final baseUri = _normalizeV2BaseUri(endpoint);
  final queryParameters = <String, String>{
    ...baseUri.queryParameters,
    if (sinceIso != null && sinceIso.trim().isNotEmpty)
      'updated_after': sinceIso,
  };
  final resolvedUri = baseUri.replace(
    pathSegments: [
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...resourcePath.split('/').where((segment) => segment.isNotEmpty),
    ],
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
  return resolvedUri.toString();
}

Uri _normalizeV2BaseUri(String endpoint) {
  final uri = Uri.parse(endpoint.trim());
  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

  List<String> normalizedSegments;
  final v2Index = segments.indexOf('v2');
  if (v2Index >= 0) {
    normalizedSegments = segments.sublist(0, v2Index + 1);
  } else if (segments.isNotEmpty && segments.last == 'sync') {
    normalizedSegments = [...segments.take(segments.length - 1), 'v2'];
  } else {
    normalizedSegments = [...segments, 'v2'];
  }

  return uri.replace(
    pathSegments: normalizedSegments,
    queryParameters: null,
    fragment: null,
  );
}

void _applyHeaders(HttpClientRequest request, String? apiKey) {
  final trimmed = apiKey?.trim() ?? '';
  if (trimmed.isEmpty) return;
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $trimmed');
  request.headers.set('x-api-key', trimmed);
}

String _parseMessage(String raw, {required String fallback}) {
  final payload = _tryParseMap(raw);
  if (payload == null) return fallback;
  return payload['message']?.toString() ??
      payload['detail']?.toString() ??
      payload['error']?.toString() ??
      fallback;
}

Map<String, dynamic>? _tryParseMap(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  } catch (_) {
    return null;
  }
}
