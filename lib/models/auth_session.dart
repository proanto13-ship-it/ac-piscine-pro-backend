class AuthSession {
  final String endpoint;
  final String token;
  final String userId;
  final String organizationId;
  final String email;
  final String fullName;
  final String role;

  const AuthSession({
    required this.endpoint,
    required this.token,
    required this.userId,
    required this.organizationId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      endpoint: json['endpoint']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'token': token,
        'userId': userId,
        'organizationId': organizationId,
        'email': email,
        'fullName': fullName,
        'role': role,
      };

  AuthSession copyWith({
    String? endpoint,
    String? token,
    String? userId,
    String? organizationId,
    String? email,
    String? fullName,
    String? role,
  }) {
    return AuthSession(
      endpoint: endpoint ?? this.endpoint,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      organizationId: organizationId ?? this.organizationId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
    );
  }

  bool get isValid =>
      endpoint.trim().isNotEmpty &&
      token.trim().isNotEmpty &&
      userId.trim().isNotEmpty &&
      organizationId.trim().isNotEmpty &&
      email.trim().isNotEmpty;
}
