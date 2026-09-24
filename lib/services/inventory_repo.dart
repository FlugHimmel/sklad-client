import 'api_client.dart';

class InventoryLine {
  final int id;
  final int inventory;
  final int product;
  final String productArticle;
  final String productName;
  final String quantityTheory;
  final String quantityFact;
  final String difference;
  final String comment;

  InventoryLine({
    required this.id, required this.inventory,
    required this.product, required this.productArticle, required this.productName,
    required this.quantityTheory, required this.quantityFact,
    required this.difference, required this.comment,
  });

  factory InventoryLine.fromJson(Map<String, dynamic> j) => InventoryLine(
        id: j['id'] as int,
        inventory: j['inventory'] as int,
        product: j['product'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        quantityTheory: (j['quantity_theory'] ?? '0').toString(),
        quantityFact: (j['quantity_fact'] ?? '0').toString(),
        difference: (j['difference'] ?? '0').toString(),
        comment: (j['comment'] ?? '').toString(),
      );

  double get diffNum => double.tryParse(difference) ?? 0;
}

class Inventory {
  final int id;
  final int warehouse;
  final String warehouseName;
  final String status;
  final String statusDisplay;
  final String? startedAt;
  final String? completedAt;
  final String comment;
  final String? createdByUsername;
  final List<InventoryLine> lines;

  Inventory({
    required this.id, required this.warehouse, required this.warehouseName,
    required this.status, required this.statusDisplay,
    this.startedAt, this.completedAt, required this.comment,
    this.createdByUsername, this.lines = const [],
  });

  factory Inventory.fromJson(Map<String, dynamic> j) => Inventory(
        id: j['id'] as int,
        warehouse: j['warehouse'] as int,
        warehouseName: (j['warehouse_name'] ?? '').toString(),
        status: (j['status'] ?? 'draft').toString(),
        statusDisplay: (j['status_display'] ?? '').toString(),
        startedAt: j['started_at'] as String?,
        completedAt: j['completed_at'] as String?,
        comment: (j['comment'] ?? '').toString(),
        createdByUsername: j['created_by_username'] as String?,
        lines: ((j['lines'] ?? []) as List)
            .map((e) => InventoryLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEditable => status == 'draft' || status == 'in_progress';
  int get diffCount => lines.where((l) => l.diffNum != 0).length;
}

class InventoryRepo {
  final ApiClient _api;
  InventoryRepo(this._api);

  Future<List<Inventory>> list() async {
    final resp = await _api.get('/api/inventories/');
    final map = resp as Map<String, dynamic>;
    return (map['results'] as List)
        .map((e) => Inventory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Inventory> get(int id) async {
    final resp = await _api.get('/api/inventories/$id/');
    return Inventory.fromJson(resp as Map<String, dynamic>);
  }

  Future<Inventory> create({
    required int warehouseId,
    String comment = '',
  }) async {
    final resp = await _api.post('/api/inventories/', body: {
      'warehouse': warehouseId,
      'comment': comment,
    });
    return Inventory.fromJson(resp as Map<String, dynamic>);
  }

  Future<InventoryLine> setLine(int inventoryId, int lineId, {
    required String quantityFact,
    String? comment,
  }) async {
    final body = <String, dynamic>{'quantity_fact': quantityFact};
    if (comment != null) body['comment'] = comment;
    final resp = await _api.post(
      '/api/inventories/$inventoryId/lines/$lineId/set', body: body);
    return InventoryLine.fromJson(resp as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> apply(int id) async {
    final resp = await _api.post('/api/inventories/$id/apply/');
    return resp as Map<String, dynamic>;
  }

  Future<void> cancel(int id) async {
    await _api.post('/api/inventories/$id/cancel/');
  }
}
