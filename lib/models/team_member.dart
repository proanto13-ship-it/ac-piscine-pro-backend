class TeamMember {
  final String id;
  final String invitationId;
  final String name;
  final String phone;
  final String email;
  final String role;
  final bool active;
  final String status;
  final String source;

  const TeamMember({
    required this.id,
    this.invitationId = '',
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.active,
    this.status = 'active',
    this.source = 'local',
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ??
        ((json['active'] ?? true) == true ? 'active' : 'inactive');
    return TeamMember(
      id: json['id']?.toString() ?? '',
      invitationId: json['invitationId']?.toString() ??
          json['invitation_id']?.toString() ??
          '',
      name: json['name']?.toString() ??
          json['fullName']?.toString() ??
          json['full_name']?.toString() ??
          '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Technicien',
      active:
          json['active'] is bool ? json['active'] as bool : status == 'active',
      status: status,
      source: json['source']?.toString() ?? 'local',
    );
  }

  factory TeamMember.fromV2User(Map<String, dynamic> json) {
    final normalizedRole = json['role']?.toString().trim().toLowerCase() ?? '';
    return TeamMember(
      id: json['id']?.toString() ?? '',
      name: json['full_name']?.toString() ??
          json['fullName']?.toString() ??
          json['name']?.toString() ??
          '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: _displayRole(normalizedRole),
      active: true,
      status: 'active',
      source: 'backend',
    );
  }

  factory TeamMember.fromV2Invitation(Map<String, dynamic> json) {
    final normalizedRole = json['role']?.toString().trim().toLowerCase() ?? '';
    final invitationId = json['id']?.toString() ?? '';
    return TeamMember(
      id: 'invite_$invitationId',
      invitationId: invitationId,
      name: json['fullName']?.toString() ??
          json['full_name']?.toString() ??
          json['name']?.toString() ??
          '',
      phone: '',
      email: json['email']?.toString() ?? '',
      role: _displayRole(normalizedRole),
      active: false,
      status: json['status']?.toString() ?? 'pending',
      source: 'backend_invitation',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invitationId': invitationId,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'active': active,
        'status': status,
        'source': source,
      };

  bool get isPending => status == 'pending' || status == 'invited';

  static String _displayRole(String normalizedRole) {
    switch (normalizedRole) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'technician':
      default:
        return 'Technician';
    }
  }
}
