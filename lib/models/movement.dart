class MovementRow {
  final int id;
  final String movementType;
  final String movementTypeDisplay;
  final String productArticle;
  final String productName;
  final String quantity;
  final String? containerCode;
  final String? orderNumber;
  final int? productionRunId;
  final String? warehouseFromName;
  final String? warehouseToName;
  final String? createdByUsername;
  final String comment;
  final DateTime? createdAt;

  MovementRow({
    required this.id,
    required this.movementType,
    required this.movementTypeDisplay,
    required this.productArticle,
    required this.productName,
    required this.quantity,
    this.containerCode,
    this.orderNumber,
    this.productionRunId,
    this.warehouseFromName,
    this.warehouseToName,
    this.createdByUsername,
    this.comment = '',
    this.createdAt,
  });

  factory MovementRow.fromJson(Map<String, dynamic> j) {
    DateTime? dt;
    final raw = j['created_at'];
    if (raw != null) {
      dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    }
    return MovementRow(
      id: j['id'] as int,
      movementType: (j['movement_type'] ?? '').toString(),
      movementTypeDisplay: (j['movement_type_display'] ?? '').toString(),
      productArticle: (j['product_article'] ?? '').toString(),
      productName: (j['product_name'] ?? '').toString(),
      quantity: (j['quantity'] ?? '0').toString(),
      containerCode: j['container_code'] as String?,
      orderNumber: j['order_number'] as String?,
      productionRunId: j['production_run_id'] as int?,
      warehouseFromName: j['warehouse_from_name'] as String?,
      warehouseToName: j['warehouse_to_name'] as String?,
      createdByUsername: j['created_by_username'] as String?,
      comment: (j['comment'] ?? '').toString(),
      createdAt: dt,
    );
  }

  bool get isIncoming =>
      const ['in', 'produce_in', 'adjust'].contains(movementType);
  bool get isOutgoing =>
      const ['out', 'produce_out', 'scrap'].contains(movementType);
  bool get isTransfer => movementType == 'transfer';
  bool get hasContainer => containerCode != null && containerCode!.isNotEmpty;
}
