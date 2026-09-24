class StockContainerLine {
  final int id;
  final int? product;
  final String? productArticle;
  final String? productName;
  final String? productType;
  final String quantity;

  StockContainerLine({
    required this.id, this.product, this.productArticle, this.productName,
    this.productType, required this.quantity,
  });

  factory StockContainerLine.fromJson(Map<String, dynamic> j) =>
      StockContainerLine(
        id: j['id'] as int,
        product: j['product'] as int?,
        productArticle: j['product_article'] as String?,
        productName: j['product_name'] as String?,
        productType: j['product_type'] as String?,
        quantity: (j['quantity'] ?? '0').toString(),
      );
}

class StockContainer {
  final int id;
  final String code;
  final int? product;
  final String? productArticle;
  final String? productName;
  final String? productType;
  final String quantity;
  final String status;
  final String statusDisplay;
  final int? warehouse;
  final String? warehouseName;
  final int? order;
  final String? orderNumber;
  final String note;
  final List<StockContainerLine> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? labelPrintedAt;
  final DateTime? packedAt;
  final DateTime? shippedAt;
  final List<StockContainerEvent> events;

  StockContainer({
    required this.id, required this.code, this.product, this.productArticle,
    this.productName, this.productType, required this.quantity,
    required this.status, required this.statusDisplay, this.warehouse,
    this.warehouseName, this.order, this.orderNumber, required this.note,
    this.lines = const [], this.createdAt, this.updatedAt,
    this.labelPrintedAt, this.packedAt, this.shippedAt, this.events = const [],
  });

  factory StockContainer.fromJson(Map<String, dynamic> j) => StockContainer(
        id: j['id'] as int,
        code: (j['code'] ?? '').toString(),
        product: j['product'] as int?,
        productArticle: j['product_article'] as String?,
        productName: j['product_name'] as String?,
        productType: j['product_type'] as String?,
        quantity: (j['quantity'] ?? '0').toString(),
        status: (j['status'] ?? 'warehouse').toString(),
        statusDisplay: (j['status_display'] ?? '').toString(),
        warehouse: j['warehouse'] as int?,
        warehouseName: j['warehouse_name'] as String?,
        order: j['order'] as int?,
        orderNumber: j['order_number'] as String?,
        note: (j['note'] ?? '').toString(),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => StockContainerLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString()) : null,
        labelPrintedAt: j['label_printed_at'] != null
            ? DateTime.tryParse(j['label_printed_at'].toString()) : null,
        packedAt: j['packed_at'] != null
            ? DateTime.tryParse(j['packed_at'].toString()) : null,
        shippedAt: j['shipped_at'] != null
            ? DateTime.tryParse(j['shipped_at'].toString()) : null,
        events: j['events'] != null
            ? (j['events'] as List)
                .map((e) => StockContainerEvent.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );

  bool get isOnWarehouse => status == 'warehouse';
  bool get isInProduction => status == 'in_production';
  bool get isShipped => status == 'shipped' || shippedAt != null;
  bool get isLabelPrinted => labelPrintedAt != null;
  bool get isPacked => packedAt != null && shippedAt == null;
}

class StockContainerEvent {
  final int id;
  final String eventType;
  final String eventTypeDisplay;
  final int? product;
  final String? productArticle;
  final String quantity;
  final int? order;
  final String? orderNumber;
  final String comment;
  final DateTime? createdAt;
  final String? createdByUsername;

  StockContainerEvent({
    required this.id, required this.eventType, required this.eventTypeDisplay,
    this.product, this.productArticle, required this.quantity,
    this.order, this.orderNumber, required this.comment,
    this.createdAt, this.createdByUsername,
  });

  factory StockContainerEvent.fromJson(Map<String, dynamic> j) =>
      StockContainerEvent(
        id: j['id'] as int,
        eventType: (j['event_type'] ?? '').toString(),
        eventTypeDisplay: (j['event_type_display'] ?? '').toString(),
        product: j['product'] as int?,
        productArticle: j['product_article'] as String?,
        quantity: (j['quantity'] ?? '0').toString(),
        order: j['order'] as int?,
        orderNumber: j['order_number'] as String?,
        comment: (j['comment'] ?? '').toString(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) : null,
        createdByUsername: j['created_by_username'] as String?,
      );
}
