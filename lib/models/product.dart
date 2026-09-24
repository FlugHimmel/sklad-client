class ProductAlias {
  final int id;
  final String article;
  final String name;
  final bool isActive;

  ProductAlias({
    required this.id,
    required this.article,
    required this.name,
    required this.isActive,
  });

  factory ProductAlias.fromJson(Map<String, dynamic> j) => ProductAlias(
        id: j['id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class Product {
  final int id;
  final String article;
  final String name;
  final String productType;
  final int? category;
  final String uom;
  final String weightG;
  final String minStock;
  final bool isActive;
  final int? mo1;
  final int? mo2;
  final int? mo3;
  final int? mo4;
  final int? mo5;
  final int? mo6;
  final int? mo7;
  final int? mo8;

  // Дубли артикулов
  final int? aliasOf;
  final String? aliasOfArticle;
  final String? aliasOfName;
  final List<ProductAlias> aliases;
  final int aliasesCount;

  Product({
    required this.id,
    required this.article,
    required this.name,
    required this.productType,
    this.category,
    required this.uom,
    required this.weightG,
    required this.minStock,
    required this.isActive,
    this.mo1,
    this.mo2,
    this.mo3,
    this.mo4,
    this.mo5,
    this.mo6,
    this.mo7,
    this.mo8,
    this.aliasOf,
    this.aliasOfArticle,
    this.aliasOfName,
    this.aliases = const [],
    this.aliasesCount = 0,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    return Product(
      id: j['id'] as int,
      article: (j['article'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      productType: (j['product_type'] ?? 'raw').toString(),
      category: j['category'] as int?,
      uom: (j['uom'] ?? 'pcs').toString(),
      weightG: (j['weight_g'] ?? '0').toString(),
      minStock: (j['min_stock'] ?? '0').toString(),
      isActive: j['is_active'] as bool? ?? true,
      mo1: j['mo1'] as int?,
      mo2: j['mo2'] as int?,
      mo3: j['mo3'] as int?,
      mo4: j['mo4'] as int?,
      mo5: j['mo5'] as int?,
      mo6: j['mo6'] as int?,
      mo7: j['mo7'] as int?,
      mo8: j['mo8'] as int?,
      aliasOf: j['alias_of'] as int?,
      aliasOfArticle: j['alias_of_article'] as String?,
      aliasOfName: j['alias_of_name'] as String?,
      aliases: ((j['aliases'] ?? []) as List)
          .map((e) => ProductAlias.fromJson(e as Map<String, dynamic>))
          .toList(),
      aliasesCount: (j['aliases_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'article': article,
        'name': name,
        'product_type': productType,
        'category': category,
        'uom': uom,
        'weight_g': weightG,
        'min_stock': minStock,
        'is_active': isActive,
        'mo1': mo1,
        'mo2': mo2,
        'mo3': mo3,
        'mo4': mo4,
        'mo5': mo5,
        'mo6': mo6,
        'mo7': mo7,
        'mo8': mo8,
      };

  /// Является ли этот продукт дублем (не главный).
  bool get isAlias => aliasOf != null;

  /// Список всех Mo-слотов по порядку.
  List<int?> get moSlots => [mo1, mo2, mo3, mo4, mo5, mo6, mo7, mo8];

  /// Непустые Mo-слоты.
  List<int> get moIds => moSlots.whereType<int>().toList();

  String get productTypeDisplay {
    switch (productType) {
      case 'raw':
        return 'Сырьё';
      case 'casting':
        return 'Литьё (заготовка)';
      case 'part':
        return 'Готовая деталь';
      case 'finished':
        return 'Готовая продукция';
      default:
        return productType;
    }
  }

  String get uomDisplay => uom == 'kg' ? 'кг' : 'шт';

  /// Вес в кг для отображения (weight_g — в граммах на сервере)
  String get weightKg {
    final w = double.tryParse(weightG) ?? 0;
    return (w / 1000).toStringAsFixed(3);
  }
}

/// Типы, доступные в UI. Убрали «Сырьё» и «Готовую продукцию» —
/// у нас реально работают только 2 типа: Литьё и Деталь.
/// Старые значения raw / finished остаются в БД, но в интерфейсе
/// их не показываем и не создаём.
const kProductTypes = [
  ('casting', 'Литьё (заготовка)'),
  ('part', 'Готовая деталь'),
];

/// Полный список типов (для отображения на старых записях).
const kProductTypesAll = [
  ('raw', 'Сырьё'),
  ('casting', 'Литьё (заготовка)'),
  ('part', 'Готовая деталь'),
  ('finished', 'Готовая продукция'),
];

/// Понятное название типа по коду (для отображения на старых записях).
String productTypeDisplay(String code) {
  for (final t in kProductTypesAll) {
    if (t.$1 == code) return t.$2;
  }
  return code;
}

const kUomOptions = [
  ('pcs', 'шт'),
  ('kg', 'кг'),
];
