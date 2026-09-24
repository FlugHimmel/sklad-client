import 'api_client.dart';

class TransferResult {
  final List<Map<String, dynamic>> moved;
  final List<String> notFound;
  final List<Map<String, dynamic>> errors;
  final String fromName;
  final String toName;

  TransferResult({
    required this.moved, required this.notFound, required this.errors,
    required this.fromName, required this.toName,
  });

  factory TransferResult.fromJson(Map<String, dynamic> j) => TransferResult(
        moved: ((j['moved'] ?? []) as List).cast<Map<String, dynamic>>(),
        notFound: ((j['not_found'] ?? []) as List).map((e) => e.toString()).toList(),
        errors: ((j['errors'] ?? []) as List).cast<Map<String, dynamic>>(),
        fromName: ((j['from_warehouse'] ?? {}) as Map)['name']?.toString() ?? '',
        toName: ((j['to_warehouse'] ?? {}) as Map)['name']?.toString() ?? '',
      );
}

class ShipScanResult {
  final List<Map<String, dynamic>> shipped;
  final List<String> notFound;
  final List<Map<String, dynamic>> errors;
  final List<Map<String, dynamic>> skipped;
  final int totalShipped;

  ShipScanResult({
    required this.shipped,
    required this.notFound,
    required this.errors,
    required this.skipped,
    required this.totalShipped,
  });

  factory ShipScanResult.fromJson(Map<String, dynamic> j) => ShipScanResult(
        shipped: ((j['shipped'] ?? []) as List).cast<Map<String, dynamic>>(),
        notFound: ((j['not_found'] ?? []) as List)
            .map((e) => e.toString())
            .toList(),
        errors: ((j['errors'] ?? []) as List).cast<Map<String, dynamic>>(),
        skipped: ((j['skipped'] ?? []) as List).cast<Map<String, dynamic>>(),
        totalShipped: (j['total_shipped'] as int?) ?? 0,
      );
}

class ShipmentNoteResult {
  final int id;
  final String number;
  final String noteDate;
  final String totalQty;
  final String totalWeightKg;
  final int linesCount;

  ShipmentNoteResult({
    required this.id,
    required this.number,
    required this.noteDate,
    required this.totalQty,
    required this.totalWeightKg,
    required this.linesCount,
  });

  factory ShipmentNoteResult.fromJson(Map<String, dynamic> j) =>
      ShipmentNoteResult(
        id: (j['id'] as num).toInt(),
        number: (j['number'] ?? '').toString(),
        noteDate: (j['note_date'] ?? '').toString(),
        totalQty: (j['total_qty'] ?? '0').toString(),
        totalWeightKg: (j['total_weight_kg'] ?? '0').toString(),
        linesCount: (j['lines_count'] as num?)?.toInt() ?? 0,
      );
}

class ShipmentNoteListItem {
  final int id;
  final String number;
  final String noteDate;
  final String totalQty;
  final String totalWeightKg;
  final int linesCount;
  final String createdAt;
  final String? createdBy;

  ShipmentNoteListItem({
    required this.id,
    required this.number,
    required this.noteDate,
    required this.totalQty,
    required this.totalWeightKg,
    required this.linesCount,
    required this.createdAt,
    this.createdBy,
  });

  factory ShipmentNoteListItem.fromJson(Map<String, dynamic> j) =>
      ShipmentNoteListItem(
        id: (j['id'] as num).toInt(),
        number: (j['number'] ?? '').toString(),
        noteDate: (j['note_date'] ?? '').toString(),
        totalQty: (j['total_qty'] ?? '0').toString(),
        totalWeightKg: (j['total_weight_kg'] ?? '0').toString(),
        linesCount: (j['lines_count'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] ?? '').toString(),
        createdBy: j['created_by_username']?.toString(),
      );
}

class ShipmentNotesPage {
  final int count;
  final int page;
  final int pageSize;
  final List<ShipmentNoteListItem> items;

  ShipmentNotesPage({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.items,
  });
}

class ShipmentNoteLine {
  final int id;
  final String code;
  final String productArticle;
  final String productName;
  final String uom;
  final String quantity;
  final String weightKg;
  final int sequence;

  ShipmentNoteLine({
    required this.id,
    required this.code,
    required this.productArticle,
    required this.productName,
    required this.uom,
    required this.quantity,
    required this.weightKg,
    required this.sequence,
  });

  factory ShipmentNoteLine.fromJson(Map<String, dynamic> j) =>
      ShipmentNoteLine(
        id: (j['id'] as num).toInt(),
        code: (j['code'] ?? '').toString(),
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        uom: (j['uom'] ?? 'шт').toString(),
        quantity: (j['quantity'] ?? '0').toString(),
        weightKg: (j['weight_kg'] ?? '0').toString(),
        sequence: (j['sequence'] as num?)?.toInt() ?? 0,
      );
}

class ShipmentNoteDetail {
  final int id;
  final String number;
  final String noteDate;
  final String fromName;
  final String fromAddress;
  final String toName;
  final String toAddress;
  final String totalQty;
  final String totalWeightKg;
  final String comment;
  final String createdAt;
  final String? createdBy;
  final List<ShipmentNoteLine> lines;

  ShipmentNoteDetail({
    required this.id,
    required this.number,
    required this.noteDate,
    required this.fromName,
    required this.fromAddress,
    required this.toName,
    required this.toAddress,
    required this.totalQty,
    required this.totalWeightKg,
    required this.comment,
    required this.createdAt,
    this.createdBy,
    required this.lines,
  });

  factory ShipmentNoteDetail.fromJson(Map<String, dynamic> j) =>
      ShipmentNoteDetail(
        id: (j['id'] as num).toInt(),
        number: (j['number'] ?? '').toString(),
        noteDate: (j['note_date'] ?? '').toString(),
        fromName: (j['from_name'] ?? '').toString(),
        fromAddress: (j['from_address'] ?? '').toString(),
        toName: (j['to_name'] ?? '').toString(),
        toAddress: (j['to_address'] ?? '').toString(),
        totalQty: (j['total_qty'] ?? '0').toString(),
        totalWeightKg: (j['total_weight_kg'] ?? '0').toString(),
        comment: (j['comment'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        createdBy: j['created_by_username']?.toString(),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => ShipmentNoteLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ShipmentRepo {
  final ApiClient _api;
  ShipmentRepo(this._api);

  Future<TransferResult> bulkTransfer({
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
    return TransferResult.fromJson(resp as Map<String, dynamic>);
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

  Future<ShipScanResult> bulkShipDelete({
    required List<String> codes,
    String comment = '',
  }) async {
    final resp = await _api.post('/api/containers/bulk-ship-delete/', body: {
      'codes': codes,
      'comment': comment,
    });
    return ShipScanResult.fromJson(resp as Map<String, dynamic>);
  }

  /// Создаёт накладную на отгрузку (автономер ЗАВ-YYYY-NNNN).
  Future<ShipmentNoteResult> createNote({
    required List<String> codes,
    String comment = '',
  }) async {
    final resp = await _api.post('/api/shipment-notes/create/', body: {
      'codes': codes,
      'comment': comment,
    });
    return ShipmentNoteResult.fromJson(resp as Map<String, dynamic>);
  }

  /// Формирует накладную за сегодня из всех тар на Завод, не попавших в другие.
  Future<ShipmentNoteResult> createNoteForToday({String comment = ''}) async {
    final resp = await _api.post(
      '/api/shipment-notes/create-for-today/',
      body: {'comment': comment},
    );
    return ShipmentNoteResult.fromJson(resp as Map<String, dynamic>);
  }

  /// PDF накладной по её ID.
  Future<List<int>> notePdf(int noteId) {
    return _api.getBytes('/api/shipment-notes/$noteId/pdf/');
  }

  /// Упрощённый упаковочный лист на тару (A4).
  Future<List<int>> simplePackingPdf(int containerId) {
    return _api.getBytes('/api/containers/$containerId/simple-packing-pdf/');
  }

  /// Страница истории накладных.
  Future<ShipmentNotesPage> listNotes({
    int page = 1,
    int pageSize = 50,
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final q = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (search.isNotEmpty) q['search'] = search;
    if (dateFrom.isNotEmpty) q['date_from'] = dateFrom;
    if (dateTo.isNotEmpty) q['date_to'] = dateTo;
    final resp = await _api.get('/api/shipment-notes/', query: q);
    final m = resp as Map<String, dynamic>;
    return ShipmentNotesPage(
      count: (m['count'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? 1,
      pageSize: (m['page_size'] as num?)?.toInt() ?? pageSize,
      items: ((m['items'] ?? []) as List)
          .map((e) => ShipmentNoteListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Детали накладной с содержимым.
  Future<ShipmentNoteDetail> noteDetail(int id) async {
    final resp = await _api.get('/api/shipment-notes/$id/');
    return ShipmentNoteDetail.fromJson(resp as Map<String, dynamic>);
  }
}
