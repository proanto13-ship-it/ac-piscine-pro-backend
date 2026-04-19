class MediaAttachment {
  static const String pending = 'pending';
  static const String uploading = 'uploading';
  static const String uploaded = 'uploaded';
  static const String failed = 'failed';

  final String id;
  final String localPath;
  final String remoteUrl;
  final String mimeType;
  final String uploadStatus;
  final String createdAtIso;
  final String updatedAtIso;
  final int version;
  final String deletedAtIso;

  const MediaAttachment({
    required this.id,
    required this.localPath,
    required this.remoteUrl,
    required this.mimeType,
    required this.uploadStatus,
    required this.createdAtIso,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  })  : updatedAtIso = updatedAtIso ?? createdAtIso,
        version = version ?? 1,
        deletedAtIso = deletedAtIso ?? '';

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    final localPath = json['localPath']?.toString() ?? '';
    final remoteUrl = json['remoteUrl']?.toString() ?? '';
    final createdAtIso = json['createdAtIso']?.toString() ?? '';
    return MediaAttachment(
      id: json['id']?.toString() ?? '',
      localPath: localPath,
      remoteUrl: remoteUrl,
      mimeType: json['mimeType']?.toString() ?? '',
      uploadStatus: _normalizeUploadStatus(
        json['uploadStatus']?.toString(),
        localPath: localPath,
        remoteUrl: remoteUrl,
      ),
      createdAtIso: createdAtIso,
      updatedAtIso: json['updatedAtIso']?.toString() ??
          json['updatedAt']?.toString() ??
          createdAtIso,
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ?? 1,
      deletedAtIso: json['deletedAtIso']?.toString() ??
          json['deletedAt']?.toString() ??
          '',
    );
  }

  factory MediaAttachment.fromLegacyPhotoPath(
    String localPath, {
    String? createdAtIso,
  }) {
    final normalizedCreatedAtIso =
        createdAtIso?.isNotEmpty == true ? createdAtIso! : '';
    return MediaAttachment(
      id: '${normalizedCreatedAtIso.isEmpty ? 'legacy' : normalizedCreatedAtIso}::$localPath',
      localPath: localPath,
      remoteUrl: '',
      mimeType: _guessMimeType(localPath),
      uploadStatus: pending,
      createdAtIso: normalizedCreatedAtIso,
      updatedAtIso: normalizedCreatedAtIso,
      version: 1,
      deletedAtIso: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'mimeType': mimeType,
        'uploadStatus': uploadStatus,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
        'updatedAt': updatedAtIso,
        'version': version,
        'deletedAtIso': deletedAtIso,
        'deletedAt': deletedAtIso,
      };

  MediaAttachment copyWith({
    String? id,
    String? localPath,
    String? remoteUrl,
    String? mimeType,
    String? uploadStatus,
    String? createdAtIso,
    String? updatedAtIso,
    int? version,
    String? deletedAtIso,
  }) {
    return MediaAttachment(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      mimeType: mimeType ?? this.mimeType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      version: version ?? this.version,
      deletedAtIso: deletedAtIso ?? this.deletedAtIso,
    );
  }

  bool get hasLocalPath => localPath.isNotEmpty;
  bool get hasRemoteUrl => remoteUrl.isNotEmpty;
  bool get needsUpload => hasLocalPath && !hasRemoteUrl;
  bool get isDeleted => deletedAtIso.trim().isNotEmpty;

  static String _normalizeUploadStatus(
    String? rawStatus, {
    required String localPath,
    required String remoteUrl,
  }) {
    final normalized = (rawStatus ?? '').trim().toLowerCase();
    switch (normalized) {
      case pending:
      case uploading:
      case uploaded:
      case failed:
        return normalized;
      case 'local':
        return remoteUrl.isNotEmpty ? uploaded : pending;
      default:
        if (remoteUrl.isNotEmpty) {
          return uploaded;
        }
        if (localPath.isNotEmpty) {
          return pending;
        }
        return failed;
    }
  }

  static String _guessMimeType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerPath.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
