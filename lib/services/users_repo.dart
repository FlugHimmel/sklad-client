import '../models/user.dart';
import 'api_client.dart';

class UsersRepo {
  final ApiClient _api;
  UsersRepo(this._api);

  Future<List<AppUser>> list({bool onlyActive = false}) async {
    final resp = await _api.get(
      '/api/auth/users/',
      query: onlyActive ? {'only_active': '1'} : null,
    );
    final list = resp is Map<String, dynamic>
        ? (resp['results'] as List? ?? const [])
        : (resp as List? ?? const []);
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> create({
    required String username,
    required String password,
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String role = 'user',
    bool isActive = true,
  }) async {
    final resp = await _api.post('/api/auth/users/', body: {
      'username': username,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
    });
    return AppUser.fromJson(resp as Map<String, dynamic>);
  }

  Future<AppUser> update(
    int id, {
    String? username,
    String? password,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    final resp = await _api.patch('/api/auth/users/$id/', body: body);
    return AppUser.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/auth/users/$id/');
  }
}
