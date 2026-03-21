enum UserRole { client, lawyer, admin }

UserRole userRoleFromString(String? value) {
  final v = (value ?? '').toLowerCase();
  return switch (v) {
    'client' => UserRole.client,
    'lawyer' => UserRole.lawyer,
    'admin' => UserRole.admin,
    _ => UserRole.client,
  };
}

String userRoleToString(UserRole role) => switch (role) {
      UserRole.client => 'client',
      UserRole.lawyer => 'lawyer',
      UserRole.admin => 'admin',
    };

class User {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final UserRole role;
  final bool? verified;

  const User({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.role,
    this.verified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final verifiedRaw = json['verified'] ??
        json['isVerified'] ??
        json['verified_status'] ??
        json['verifiedStatus'] ??
        profile['verified'] ??
        profile['isVerified'] ??
        profile['verified_status'] ??
        profile['verifiedStatus'];

    final verified = verifiedRaw == null
        ? null
        : verifiedRaw == true ||
            verifiedRaw.toString().toLowerCase() == 'approved' ||
            verifiedRaw.toString().toLowerCase() == 'verified' ||
            verifiedRaw.toString().toLowerCase() == 'true';

    return User(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      fullName: (json['full_name'] ??
              json['fullName'] ??
              profile['full_name'] ??
              profile['fullName'] ??
              '')
          .toString(),
      role: userRoleFromString(json['role']?.toString()),
      verified: verified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'full_name': fullName,
      'role': userRoleToString(role),
      'verified': verified,
    };
  }
}
