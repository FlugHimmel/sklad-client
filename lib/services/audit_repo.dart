import '../models/audit.dart';
import 'api_client.dart';

class AuditRepo {
  final ApiClient _api;
  AuditRepo(this._api);

  Future<List<AuditLog>> list({
    String? search,
    String? model,
    String? action,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int pageSize = 500,
  }) async {
    final q = <String, String>{'page_size': pageSize.toString()};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (model != null && model.isNotEmpty) q['model'] = model;
    if (action != null && action.isNotEmpty) q['action'] = action;
    if (userId != null) q['user'] = userId.toString();
    if (dateFrom != null) q['date_from'] = dateFrom;
    if (dateTo != null) q['date_to'] = dateTo;
    final resp = await _api.get('/api/audit/logs/', query: q);
    final map = resp as Map<String, dynamic>;
    return (map['results'] as List)
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> models() async {
    final resp = await _api.get('/api/audit/logs/models/');
    return (resp as List).cast<Map<String, dynamic>>();
  }
}
