class PublicShareLink {
  final String id;
  final String token;
  final String resourceType;
  final String resourceId;
  final String expiresAtIso;
  final String publicUrl;
  final String createdAtIso;

  const PublicShareLink({
    required this.id,
    required this.token,
    required this.resourceType,
    required this.resourceId,
    required this.expiresAtIso,
    required this.publicUrl,
    required this.createdAtIso,
  });

  factory PublicShareLink.fromJson(Map<String, dynamic> json) {
    return PublicShareLink(
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      resourceType: json['resourceType']?.toString() ??
          json['resource_type']?.toString() ??
          '',
      resourceId: json['resourceId']?.toString() ??
          json['resource_id']?.toString() ??
          '',
      expiresAtIso: json['expiresAtIso']?.toString() ??
          json['expires_at_iso']?.toString() ??
          '',
      publicUrl: json['publicUrl']?.toString() ?? '',
      createdAtIso: json['createdAtIso']?.toString() ??
          json['created_at_iso']?.toString() ??
          '',
    );
  }

  bool get hasExpiration => expiresAtIso.trim().isNotEmpty;
}
