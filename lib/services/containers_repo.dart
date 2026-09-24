import '../models/container.dart';
import 'api_client.dart';

class ContainersPage {
  final List<StockContainer> items;
  final int total;
  final String? next;
  ContainersPage({required this.items, required this.total, this.next});
}

class ContainersRepo {
  final ApiClient _api;
  ContainersRepo(this._api);

  Future<ContainersPage> list({
    String? search,
    String? status,
    bool? packed,
    int page = 1,
    int pageSize = 1000,  // грузим сразу много тар, чтобы помещались все
  }) async {
    final q = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (packed != null) q['packed'] = packed ? '1' : '0';

    final resp = await _api.get('/api/containers/', query: q);
    final map = resp as Map<String, dynamic>;
    final results = (map['results'] as List)
        .map((e) => StockContainer.fromJson(e as Map<String, dynamic>))
        .toList();
    return ContainersPage(
      items: results,
      total: map['count'] as int? ?? results.length,
      next: map['next'] as String?,
    );
  }

  Future<StockContainer> get(int id) async {
    final resp = await _api.get('/api/containers/$id/');
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  Future<StockContainer> byCode(String code) async {
    final resp = await _api.get(
      '/api/containers/by-code/',
      query: {'code': code},
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  Future<StockContainer> create({
    required int productId,
    required String quantity,
    required int warehouseId,
    String note = '',
  }) async {
    final resp = await _api.post('/api/containers/', body: {
      'product': productId,
      'quantity': quantity,
      'warehouse': warehouseId,
      'note': note,
    });
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Создание тары с несколькими артикулами сразу (новая тара).
  Future<StockContainer> multiCreate({
    required int warehouseId,
    required List<Map<String, dynamic>> lines,
    String note = '',
  }) async {
    final resp = await _api.post('/api/containers/multi-create/', body: {
      'warehouse_id': warehouseId,
      'note': note,
      'lines': lines,
    });
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Наполнение существующей пустой тары (ревизия).
  /// [lines] — [{'product_id': N, 'quantity': 'X'}, ...]
  Future<StockContainer> fill(
    int containerId, {
    required List<Map<String, dynamic>> lines,
    int? warehouseId,
    bool packed = false,
    String note = '',
  }) async {
    final body = <String, dynamic>{
      'lines': lines,
      'note': note,
      'packed': packed,
    };
    if (warehouseId != null) body['warehouse_id'] = warehouseId;
    final resp = await _api.post(
      '/api/containers/$containerId/fill/',
      body: body,
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Поменять состояние тары (упакована / не упакована).
  Future<StockContainer> setPacked(int containerId, {required bool packed}) async {
    final resp = await _api.post(
      '/api/containers/$containerId/set-packed/',
      body: {'packed': packed},
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Массово поменять состояние тар.
  Future<Map<String, dynamic>> bulkSetPacked({
    required List<int> ids,
    required bool packed,
  }) async {
    final resp = await _api.post('/api/containers/bulk-set-packed/', body: {
      'ids': ids,
      'packed': packed,
    });
    return resp as Map<String, dynamic>;
  }

  /// Список пустых тар (болванок ШК).
  Future<List<StockContainer>> listEmpty({String? search}) async {
    final q = <String, String>{};
    if (search != null && search.isNotEmpty) q['search'] = search;
    final resp = await _api.get('/api/containers/empty/', query: q);
    final map = resp as Map<String, dynamic>;
    return (map['items'] as List)
        .map((e) => StockContainer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Массовое создание пустых тар (болванок).
  Future<List<Map<String, dynamic>>> bulkCreateEmpty({
    required int count,
    required int warehouseId,
    String note = '',
  }) async {
    final resp = await _api.post('/api/containers/bulk-create-empty/', body: {
      'count': count,
      'warehouse_id': warehouseId,
      'note': note,
    });
    final map = resp as Map<String, dynamic>;
    return (map['created'] as List).cast<Map<String, dynamic>>();
  }

  Future<StockContainer> issue(int id, {String comment = ''}) async {
    final resp = await _api.post(
      '/api/containers/$id/issue/',
      body: {'comment': comment},
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> returnFromProduction(
    int id, {
    required int productId,
    required String quantity,
    String comment = '',
  }) async {
    final resp = await _api.post(
      '/api/containers/$id/return/',
      body: {
        'product_id': productId,
        'quantity': quantity,
        'comment': comment,
      },
    );
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ship(
    int id, {
    int? orderId,
    String comment = '',
  }) async {
    final resp = await _api.post(
      '/api/containers/$id/ship/',
      body: {
        if (orderId != null) 'order_id': orderId,
        'comment': comment,
      },
    );
    return resp as Map<String, dynamic>;
  }

  Future<StockContainer> move(
    int id, {
    required int warehouseId,
    String comment = '',
  }) async {
    final resp = await _api.post(
      '/api/containers/$id/move/',
      body: {
        'warehouse_id': warehouseId,
        'comment': comment,
      },
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> bulkMove({
    required List<String> codes,
    required int warehouseId,
    String comment = '',
  }) async {
    final resp = await _api.post('/api/containers/bulk-move/', body: {
      'codes': codes,
      'warehouse_id': warehouseId,
      'comment': comment,
    });
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkTransfer({
    required List<String> codes,
    required int fromWarehouseId,
    required int toWarehouseId,
    String comment = '',
  }) async {
    final resp = await _api.post('/api/containers/bulk-transfer/', body: {
      'codes': codes,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'comment': comment,
    });
    return resp as Map<String, dynamic>;
  }

  Future<List<int>> transferNotePdf({
    required List<String> codes,
    required int fromWarehouseId,
    required int toWarehouseId,
  }) async {
    return _api.postBytes('/api/containers/transfer-note-pdf/', body: {
      'codes': codes,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
    });
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/containers/$id/');
  }

  Future<List<int>> labelPdf(int id) {
    return _api.getBytes('/api/containers/$id/label-pdf/');
  }

  Future<List<int>> bulkLabelsPdf(List<int> ids) {
    return _api.postBytes('/api/containers/bulk-labels-pdf/',
        body: {'ids': ids});
  }

  /// Один PDF с упаковочными листами для нескольких тар.
  Future<List<int>> bulkPackingPdf(List<int> ids) {
    return _api.postBytes('/api/containers/bulk-packing-pdf/',
        body: {'ids': ids});
  }

  /// Устанавливает новое количество строки тары. 0 — удаляет строку.
  Future<StockContainer> setLineQuantity(
    int containerId,
    int lineId,
    String quantity, {
    String comment = '',
  }) async {
    final resp = await _api.post(
      '/api/containers/$containerId/lines/$lineId/set/',
      body: {'quantity': quantity, 'comment': comment},
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Добавляет артикул в тару. Если строка уже есть — увеличивает.
  Future<StockContainer> addLine(
    int containerId,
    int productId,
    String quantity, {
    String comment = '',
  }) async {
    final resp = await _api.post(
      '/api/containers/$containerId/lines/add/',
      body: {
        'product_id': productId,
        'quantity': quantity,
        'comment': comment,
      },
    );
    return StockContainer.fromJson(resp as Map<String, dynamic>);
  }

  /// Перекладывает артикулы из этой тары в другую.
  /// [lines] — [{'product_id': N, 'quantity': 'X'}, ...]
  Future<Map<String, dynamic>> transferTo(
    int containerId, {
    required String toCode,
    required List<Map<String, dynamic>> lines,
    String comment = '',
  }) async {
    return await _api.post(
      '/api/containers/$containerId/transfer-to/',
      body: {
        'to_code': toCode,
        'lines': lines,
        'comment': comment,
      },
    ) as Map<String, dynamic>;
  }
}
