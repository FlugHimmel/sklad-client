import '../models/movement.dart';
import 'api_client.dart';

class MovementsResult {
  final List<MovementRow> rows;
  final int count;
  final String incomingTotal;
  final String outgoingTotal;
  MovementsResult({
    required this.rows,
    required this.count,
    required this.incomingTotal,
    required this.outgoingTotal,
  });
}

class MovementsRepo {
  final ApiClient _api;
  MovementsRepo(this._api);

  Future<MovementsResult> list({
    String? search,
    String? tab,
    String? dateFrom,
    String? dateTo,
    bool? hasContainer,
  }) async {
    final q = <String, String>{};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (tab != null && tab.isNotEmpty) q['tab'] = tab;
    if (dateFrom != null) q['date_from'] = dateFrom;
    if (dateTo != null) q['date_to'] = dateTo;
    if (hasContainer == true) q['has_container'] = '1';
    if (hasContainer == false) q['has_container'] = '0';

    final resp = await _api.get('/api/reports/movements/', query: q);
    final map = resp as Map<String, dynamic>;
    final rows = ((map['rows'] ?? []) as List)
        .map((e) => MovementRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return MovementsResult(
      rows: rows,
      count: map['count'] as int? ?? rows.length,
      incomingTotal: (map['incoming_total'] ?? '0').toString(),
      outgoingTotal: (map['outgoing_total'] ?? '0').toString(),
    );
  }

  /// Ручной приход / расход без тары.
  Future<void> manual({
    required String direction, // 'in' | 'out'
    required int productId,
    required int warehouseId,
    required String quantity,
    String comment = '',
  }) async {
    await _api.post('/api/movements/manual/', body: {
      'direction': direction,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'comment': comment,
    });
  }
}
