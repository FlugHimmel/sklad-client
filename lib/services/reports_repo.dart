import 'api_client.dart';

class StockReportRow {
  final String warehouse;
  final int productId;
  final String article;
  final String name;
  final String productType;
  final String uom;
  final String quantity;
  final String inContainers;
  final String freeStock;
  final String minStock;
  final bool belowMin;

  StockReportRow({
    required this.warehouse, required this.productId, required this.article,
    required this.name, required this.productType, required this.uom,
    required this.quantity, required this.inContainers, required this.freeStock,
    required this.minStock, required this.belowMin,
  });

  factory StockReportRow.fromJson(Map<String, dynamic> j) => StockReportRow(
        warehouse: (j['warehouse'] ?? '').toString(),
        productId: j['product_id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        productType: (j['product_type'] ?? '').toString(),
        uom: (j['uom'] ?? 'pcs').toString(),
        quantity: (j['quantity'] ?? '0').toString(),
        inContainers: (j['in_containers'] ?? '0').toString(),
        freeStock: (j['free_stock'] ?? '0').toString(),
        minStock: (j['min_stock'] ?? '0').toString(),
        belowMin: j['below_min'] as bool? ?? false,
      );

  String get productTypeDisplay {
    switch (productType) {
      case 'raw': return 'Сырьё';
      case 'casting': return 'Литьё';
      case 'part': return 'Деталь';
      case 'finished': return 'Готовая';
      default: return productType;
    }
  }
}

class MonthlyProductRow {
  final int productId;
  final String article;
  final String name;
  final String productType;
  final String uom;
  final String balanceStart;
  final String received;
  final String produced;
  final String shipped;
  final String scrap;
  final String produceOut;
  final String prodScrap;
  final String balanceEnd;

  MonthlyProductRow({
    required this.productId, required this.article, required this.name,
    required this.productType, required this.uom, required this.balanceStart,
    required this.received, required this.produced, required this.shipped,
    required this.scrap, required this.produceOut, required this.prodScrap,
    required this.balanceEnd,
  });

  factory MonthlyProductRow.fromJson(Map<String, dynamic> j) => MonthlyProductRow(
        productId: j['product_id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        productType: (j['product_type'] ?? '').toString(),
        uom: (j['uom'] ?? 'pcs').toString(),
        balanceStart: (j['balance_start'] ?? '0').toString(),
        received: (j['received'] ?? '0').toString(),
        produced: (j['produced'] ?? '0').toString(),
        shipped: (j['shipped'] ?? '0').toString(),
        scrap: (j['scrap'] ?? '0').toString(),
        produceOut: (j['produce_out'] ?? '0').toString(),
        prodScrap: (j['prod_scrap'] ?? '0').toString(),
        balanceEnd: (j['balance_end'] ?? '0').toString(),
      );
}

class CastingChildRow {
  final int productId;
  final String article;
  final String name;
  final String balanceStart;
  final String produced;
  final String shipped;
  final String scrap;
  final String balanceEnd;

  CastingChildRow({
    required this.productId, required this.article, required this.name,
    required this.balanceStart, required this.produced, required this.shipped,
    required this.scrap, required this.balanceEnd,
  });

  factory CastingChildRow.fromJson(Map<String, dynamic> j) => CastingChildRow(
        productId: j['product_id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        balanceStart: (j['balance_start'] ?? '0').toString(),
        produced: (j['produced'] ?? '0').toString(),
        shipped: (j['shipped'] ?? '0').toString(),
        scrap: (j['scrap'] ?? '0').toString(),
        balanceEnd: (j['balance_end'] ?? '0').toString(),
      );
}

class CastingRow {
  final int productId;
  final String article;
  final String name;
  final String balanceStart;
  final String received;
  final String produceOut;
  final String balanceEnd;
  final String partsBalanceStart;
  final String partsProduced;
  final String partsShipped;
  final String partsScrap;
  final String partsBalanceEnd;
  final List<CastingChildRow> children;

  CastingRow({
    required this.productId, required this.article, required this.name,
    required this.balanceStart, required this.received, required this.produceOut,
    required this.balanceEnd, required this.partsBalanceStart,
    required this.partsProduced, required this.partsShipped,
    required this.partsScrap, required this.partsBalanceEnd,
    required this.children,
  });

  factory CastingRow.fromJson(Map<String, dynamic> j) => CastingRow(
        productId: j['product_id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        balanceStart: (j['balance_start'] ?? '0').toString(),
        received: (j['received'] ?? '0').toString(),
        produceOut: (j['produce_out'] ?? '0').toString(),
        balanceEnd: (j['balance_end'] ?? '0').toString(),
        partsBalanceStart: (j['parts_balance_start'] ?? '0').toString(),
        partsProduced: (j['parts_produced'] ?? '0').toString(),
        partsShipped: (j['parts_shipped'] ?? '0').toString(),
        partsScrap: (j['parts_scrap'] ?? '0').toString(),
        partsBalanceEnd: (j['parts_balance_end'] ?? '0').toString(),
        children: ((j['children'] ?? []) as List)
            .map((e) => CastingChildRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MonthlySummary {
  final int year;
  final int month;
  final String label;
  final List<MonthlyProductRow> byProduct;
  final List<CastingRow> castings;
  final Map<String, String> totals;

  MonthlySummary({
    required this.year, required this.month, required this.label,
    required this.byProduct, required this.castings, required this.totals,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> j) => MonthlySummary(
        year: j['year'] as int,
        month: j['month'] as int,
        label: (j['label'] ?? '').toString(),
        byProduct: ((j['by_product'] ?? []) as List)
            .map((e) => MonthlyProductRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        castings: ((j['castings'] ?? []) as List)
            .map((e) => CastingRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: ((j['totals'] ?? {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

class ReadyToShipContainer {
  final int containerId;
  final String containerCode;
  final String quantity;
  final String nettoKg;
  final DateTime? packedAt;

  ReadyToShipContainer({
    required this.containerId, required this.containerCode,
    required this.quantity, required this.nettoKg, this.packedAt,
  });

  factory ReadyToShipContainer.fromJson(Map<String, dynamic> j) =>
      ReadyToShipContainer(
        containerId: j['container_id'] as int,
        containerCode: (j['container_code'] ?? '').toString(),
        quantity: (j['quantity'] ?? '0').toString(),
        nettoKg: (j['netto_kg'] ?? '0').toString(),
        packedAt: j['packed_at'] != null
            ? DateTime.tryParse(j['packed_at'].toString()) : null,
      );
}

class ReadyToShipProductRow {
  final int productId;
  final String article;
  final String name;
  final String productType;
  final String uom;
  final String totalQty;
  final int places;
  final String nettoKg;
  final String bruttoKg;
  final List<ReadyToShipContainer> containers;

  ReadyToShipProductRow({
    required this.productId, required this.article, required this.name,
    required this.productType, required this.uom,
    required this.totalQty, required this.places,
    required this.nettoKg, required this.bruttoKg,
    required this.containers,
  });

  factory ReadyToShipProductRow.fromJson(Map<String, dynamic> j) =>
      ReadyToShipProductRow(
        productId: j['product_id'] as int,
        article: (j['article'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        productType: (j['product_type'] ?? '').toString(),
        uom: (j['uom'] ?? 'pcs').toString(),
        totalQty: (j['total_qty'] ?? '0').toString(),
        places: j['places'] as int? ?? 0,
        nettoKg: (j['netto_kg'] ?? '0').toString(),
        bruttoKg: (j['brutto_kg'] ?? '0').toString(),
        containers: ((j['containers'] ?? []) as List)
            .map((e) => ReadyToShipContainer.fromJson(
                e as Map<String, dynamic>))
            .toList(),
      );
}

class ReadyToShipTotals {
  final int places;
  final String qty;
  final String nettoKg;
  final String bruttoKg;

  ReadyToShipTotals({
    required this.places, required this.qty,
    required this.nettoKg, required this.bruttoKg,
  });

  factory ReadyToShipTotals.fromJson(Map<String, dynamic> j) =>
      ReadyToShipTotals(
        places: j['places'] as int? ?? 0,
        qty: (j['qty'] ?? '0').toString(),
        nettoKg: (j['netto_kg'] ?? '0').toString(),
        bruttoKg: (j['brutto_kg'] ?? '0').toString(),
      );
}

class ReadyToShipResult {
  final int count;
  final ReadyToShipTotals totals;
  final List<ReadyToShipProductRow> rows;

  ReadyToShipResult({
    required this.count, required this.totals, required this.rows,
  });
}

class ReportsRepo {
  final ApiClient _api;
  ReportsRepo(this._api);

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<StockReportRow>> stock({int? warehouseId}) async {
    final q = <String, String>{};
    if (warehouseId != null) q['warehouse'] = warehouseId.toString();
    final resp = await _api.get('/api/reports/stock/', query: q);
    final rows = ((resp as Map<String, dynamic>)['rows'] as List)
        .cast<Map<String, dynamic>>();
    return rows.map(StockReportRow.fromJson).toList();
  }

  Future<List<MonthlySummary>> monthlySummary({int months = 12}) async {
    final resp = await _api.get('/api/reports/monthly-summary/',
        query: {'months': months.toString()});
    final list = ((resp as Map<String, dynamic>)['months'] as List)
        .cast<Map<String, dynamic>>();
    return list.map(MonthlySummary.fromJson).toList();
  }

  /// Отчёт по производству (на операциях).
  Future<Map<String, dynamic>> productionOps({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? operationType,
    String? search,
  }) async {
    final q = <String, String>{};
    if (dateFrom != null) q['date_from'] = _fmtDate(dateFrom);
    if (dateTo != null) q['date_to'] = _fmtDate(dateTo);
    if (operationType != null && operationType.isNotEmpty) {
      q['operation_type'] = operationType;
    }
    if (search != null && search.isNotEmpty) q['search'] = search;
    final resp = await _api.get('/api/reports/production-ops/', query: q);
    return resp as Map<String, dynamic>;
  }

  /// Отчёт по браку (на операциях).
  Future<Map<String, dynamic>> scrapOps({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? reason,
    String? operator,
    String? search,
  }) async {
    final q = <String, String>{};
    if (dateFrom != null) q['date_from'] = _fmtDate(dateFrom);
    if (dateTo != null) q['date_to'] = _fmtDate(dateTo);
    if (reason != null && reason.isNotEmpty) q['reason'] = reason;
    if (operator != null && operator.isNotEmpty) q['operator'] = operator;
    if (search != null && search.isNotEmpty) q['search'] = search;
    final resp = await _api.get('/api/reports/scrap-ops/', query: q);
    return resp as Map<String, dynamic>;
  }

  /// Что готово к отгрузке (упакованные тары на MAIN).
  /// category: all | wheels | components
  Future<ReadyToShipResult> readyToShip({
    String? search,
    String? category,
  }) async {
    final q = <String, String>{};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (category != null && category.isNotEmpty && category != 'all') {
      q['category'] = category;
    }
    final resp = await _api.get('/api/reports/ready-to-ship/', query: q);
    final m = resp as Map<String, dynamic>;
    return ReadyToShipResult(
      count: (m['count'] as num?)?.toInt() ?? 0,
      totals: ReadyToShipTotals.fromJson(
          (m['totals'] ?? {}) as Map<String, dynamic>),
      rows: ((m['rows'] ?? []) as List)
          .map((e) => ReadyToShipProductRow.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}
