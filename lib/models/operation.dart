// Модели операций. Соответствуют API /api/operations/.
//
// Одна операция — это:
//   * тип (токарка/фрезеровка/упаковка/...)
//   * строки «взял» (from), «положил» (to), «брак» (scrap)
//   * баланс: SUM(from) == SUM(to) + SUM(scrap)

class OperationTypeItem {
  final String value;
  final String label;
  OperationTypeItem({required this.value, required this.label});

  factory OperationTypeItem.fromJson(Map<String, dynamic> j) =>
      OperationTypeItem(
        value: (j['value'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

class ScrapReasonItem {
  final String value;
  final String label;
  ScrapReasonItem({required this.value, required this.label});

  factory ScrapReasonItem.fromJson(Map<String, dynamic> j) => ScrapReasonItem(
        value: (j['value'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

class OperationMeta {
  final List<OperationTypeItem> operationTypes;
  final List<ScrapReasonItem> scrapReasons;
  OperationMeta({
    required this.operationTypes,
    required this.scrapReasons,
  });

  factory OperationMeta.fromJson(Map<String, dynamic> j) => OperationMeta(
        operationTypes: ((j['operation_types'] ?? []) as List)
            .map((e) => OperationTypeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        scrapReasons: ((j['scrap_reasons'] ?? []) as List)
            .map((e) => ScrapReasonItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OperationLineItem {
  final int id;
  final String direction; // from / to / scrap
  final String directionDisplay;
  final int? containerId;
  final String? containerCode;
  final int productId;
  final String productArticle;
  final String productName;
  final String qty;
  final String scrapReason;
  final String scrapReasonDisplay;

  OperationLineItem({
    required this.id,
    required this.direction,
    required this.directionDisplay,
    this.containerId,
    this.containerCode,
    required this.productId,
    required this.productArticle,
    required this.productName,
    required this.qty,
    required this.scrapReason,
    required this.scrapReasonDisplay,
  });

  factory OperationLineItem.fromJson(Map<String, dynamic> j) =>
      OperationLineItem(
        id: j['id'] as int,
        direction: (j['direction'] ?? '').toString(),
        directionDisplay: (j['direction_display'] ?? '').toString(),
        containerId: j['container_id'] as int?,
        containerCode: j['container_code'] as String?,
        productId: j['product_id'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        qty: (j['qty'] ?? '0').toString(),
        scrapReason: (j['scrap_reason'] ?? '').toString(),
        scrapReasonDisplay: (j['scrap_reason_display'] ?? '').toString(),
      );

  bool get isFrom => direction == 'from';
  bool get isTo => direction == 'to';
  bool get isScrap => direction == 'scrap';
}

class OperationSummary {
  final String fromTotal;
  final String toTotal;
  final String scrapTotal;
  final bool balanced;
  OperationSummary({
    required this.fromTotal,
    required this.toTotal,
    required this.scrapTotal,
    required this.balanced,
  });

  factory OperationSummary.fromJson(Map<String, dynamic> j) => OperationSummary(
        fromTotal: (j['from_total'] ?? '0').toString(),
        toTotal: (j['to_total'] ?? '0').toString(),
        scrapTotal: (j['scrap_total'] ?? '0').toString(),
        balanced: j['balanced'] as bool? ?? false,
      );
}

class Operation {
  final int id;
  final String operationType;
  final String operationTypeDisplay;
  final DateTime? createdAt;
  final int? createdById;
  final String? createdByUsername;
  final int? orderId;
  final String comment;
  final List<OperationLineItem> lines;
  final OperationSummary summary;

  Operation({
    required this.id,
    required this.operationType,
    required this.operationTypeDisplay,
    this.createdAt,
    this.createdById,
    this.createdByUsername,
    this.orderId,
    required this.comment,
    required this.lines,
    required this.summary,
  });

  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
        id: j['id'] as int,
        operationType: (j['operation_type'] ?? '').toString(),
        operationTypeDisplay: (j['operation_type_display'] ?? '').toString(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
        createdById: j['created_by_id'] as int?,
        createdByUsername: j['created_by_username'] as String?,
        orderId: j['order_id'] as int?,
        comment: (j['comment'] ?? '').toString(),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => OperationLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: OperationSummary.fromJson(
            (j['summary'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      );
}

/// Строка истории тары (GET /api/containers/{id}/op-history/)
class ContainerHistoryRow {
  final int operationId;
  final String operationType;
  final String operationTypeDisplay;
  final DateTime? createdAt;
  final String? createdByUsername;
  final String direction;
  final String directionDisplay;
  final int productId;
  final String productArticle;
  final String productName;
  final String qty;
  final String scrapReason;
  final String scrapReasonDisplay;
  final String comment;

  ContainerHistoryRow({
    required this.operationId,
    required this.operationType,
    required this.operationTypeDisplay,
    this.createdAt,
    this.createdByUsername,
    required this.direction,
    required this.directionDisplay,
    required this.productId,
    required this.productArticle,
    required this.productName,
    required this.qty,
    required this.scrapReason,
    required this.scrapReasonDisplay,
    required this.comment,
  });

  factory ContainerHistoryRow.fromJson(Map<String, dynamic> j) =>
      ContainerHistoryRow(
        operationId: j['operation_id'] as int,
        operationType: (j['operation_type'] ?? '').toString(),
        operationTypeDisplay: (j['operation_type_display'] ?? '').toString(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
        createdByUsername: j['created_by_username'] as String?,
        direction: (j['direction'] ?? '').toString(),
        directionDisplay: (j['direction_display'] ?? '').toString(),
        productId: j['product_id'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        qty: (j['qty'] ?? '0').toString(),
        scrapReason: (j['scrap_reason'] ?? '').toString(),
        scrapReasonDisplay: (j['scrap_reason_display'] ?? '').toString(),
        comment: (j['comment'] ?? '').toString(),
      );
}
