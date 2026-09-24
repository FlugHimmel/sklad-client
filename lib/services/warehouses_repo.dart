import 'api_client.dart';

class Warehouse {
  final int id;
  final String name;
  final String code;
  Warehouse({required this.id, required this.name, required this.code});

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
      );
}

class WarehousesRepo {
  final ApiClient _api;
  WarehousesRepo(this._api);

  Future<List<Warehouse>> list() async {
    final resp = await _api.get('/api/warehouses/');
    final list = resp is Map<String, dynamic>
        ? (resp['results'] as List? ?? const [])
        : (resp as List? ?? const []);
    return list
        .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
