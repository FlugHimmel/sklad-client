import '../models/product.dart';
import 'api_client.dart';

class ProductPage {
  final List<Product> items;
  final int total;
  final String? next;

  ProductPage({required this.items, required this.total, this.next});
}

class ProductsRepo {
  final ApiClient _api;
  ProductsRepo(this._api);

  Future<ProductPage> list({
    String? search,
    String? productType,
    bool? isActive,
    int page = 1,
  }) async {
    final q = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (productType != null && productType.isNotEmpty) {
      q['product_type'] = productType;
    }
    if (isActive == true) q['is_active'] = '1';

    final resp = await _api.get('/api/products/', query: q);
    final map = resp as Map<String, dynamic>;
    final results = (map['results'] as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProductPage(
      items: results,
      total: map['count'] as int? ?? results.length,
      next: map['next'] as String?,
    );
  }

  Future<Product> get(int id) async {
    final resp = await _api.get('/api/products/$id/');
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  Future<Product> create(Map<String, dynamic> data) async {
    final resp = await _api.post('/api/products/', body: data);
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  Future<Product> update(int id, Map<String, dynamic> data) async {
    final resp = await _api.put('/api/products/$id/', body: data);
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  Future<Product> deactivate(int id) async {
    final resp = await _api.patch('/api/products/$id/', body: {'is_active': false});
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  Future<Product> activate(int id) async {
    final resp = await _api.patch('/api/products/$id/', body: {'is_active': true});
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/products/$id/');
  }

  Future<List<Product>> listByType(String productType) async {
    final all = <Product>[];
    int page = 1;
    while (true) {
      final p = await list(productType: productType, page: page);
      all.addAll(p.items);
      if (p.next == null) break;
      page++;
      if (page > 50) break;
    }
    return all;
  }

  /// Найти продукт по любому артикулу (главному или дублю).
  /// Возвращает главный продукт.
  Future<Product> resolve(String article) async {
    final resp = await _api.get('/api/products/resolve/',
        query: {'article': article});
    final m = resp as Map<String, dynamic>;
    return Product.fromJson(m['product'] as Map<String, dynamic>);
  }

  /// Привязать этот продукт как дубль к главному (по id или артикулу).
  Future<Product> linkAlias(int productId,
      {int? mainId, String? mainArticle}) async {
    final body = <String, dynamic>{};
    if (mainId != null) body['main_id'] = mainId;
    if (mainArticle != null && mainArticle.isNotEmpty) {
      body['main_article'] = mainArticle;
    }
    final resp = await _api.post(
        '/api/products/$productId/link-alias/', body: body);
    return Product.fromJson(resp as Map<String, dynamic>);
  }

  /// Отвязать продукт от главного (снова самостоятельный).
  Future<Product> unlinkAlias(int productId) async {
    final resp = await _api.post(
        '/api/products/$productId/unlink-alias/');
    return Product.fromJson(resp as Map<String, dynamic>);
  }
}
