class AppUser {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final bool isSuperuser;

  AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.email = '',
    this.phone = '',
    required this.role,
    this.isActive = true,
    this.isSuperuser = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) {
    return AppUser(
      id: j['id'] as int,
      username: (j['username'] ?? '').toString(),
      firstName: (j['first_name'] ?? '').toString(),
      lastName: (j['last_name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      role: (j['role'] ?? 'user').toString(),
      isActive: j['is_active'] as bool? ?? true,
      isSuperuser: j['is_superuser'] as bool? ?? false,
    );
  }

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  String get roleDisplay {
    switch (role) {
      case 'admin':
        return 'Администратор';
      default:
        return 'Пользователь';
    }
  }

  bool get isAdmin => role == 'admin' || isSuperuser;
}
