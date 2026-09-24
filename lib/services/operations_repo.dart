import '../models/operation.dart';
import 'api_client.dart';

class OperationsPage {
  final List<Operation> rows;
  final int count;
  OperationsPage({required this.rows, required this.count});
}

class OperationsRepo {
  final ApiClient api;
  OperationsRepo(this.api);

  Future<OperationMeta> meta() async {
    final j = await api.get('/api/operations/meta/');
    return OperationMeta.fromJson(j as Map<String, dynamic>);
  }

  Future<OperationsPage> list({String? type, int limit = 100}) async {
    final q = <String, String>{'limit': '$limit'};
    if (type != null && type.isNotEmpty) q['operation_type'] = type;
    final j = await api.get('/api/operations/', query: q);
    final m = j as Map<String, dynamic>;
    return OperationsPage(
      rows: ((m['rows'] ?? []) as List)
          .map((e) => Operation.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (m['count'] ?? 0) as int,
    );
  }

  Future<Operation> get(int id) async {
    final j = await api.get('/api/operations/$id/');
    return Operation.fromJson(j as Map<String, dynamic>);
  }

  /// Создать операцию.
  /// from  = [{"container_id": N, "product_id": P, "qty": "50"}]
  /// to    = [{"container_id": N, "product_id": P, "qty": "48"}]
  /// scrap = [{"product_id": P, "qty": "2", "reason": "setup"}]
  Future<Operation> create({
    required String operationType,
    required List<Map<String, dynamic>> from,
    required List<Map<String, dynamic>> to,
    required List<Map<String, dynamic>> scrap,
    String comment = '',
  }) async {
    final j = await api.post('/api/operations/', body: {
      'operation_type': operationType,
      'from': from,
      'to': to,
      'scrap': scrap,
      'comment': comment,
    });
    return Operation.fromJson(j as Map<String, dynamic>);
  }

  Future<void> rollback(int id) async {
    await api.post('/api/operations/$id/rollback/');
  }

  Future<List<ContainerHistoryRow>> containerHistory(int containerId) async {
    final j = await api.get('/api/containers/$containerId/op-history/');
    final m = j as Map<String, dynamic>;
    return ((m['rows'] ?? []) as List)
        .map((e) => ContainerHistoryRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
