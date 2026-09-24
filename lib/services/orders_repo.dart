import 'api_client.dart';

class PackedContainer {
  final int containerId;
  final String containerCode;
  final String quantity;
  final DateTime? packedAt;

  PackedContainer({
    required this.containerId, required this.containerCode,
    required this.quantity, this.packedAt,
  });

  factory PackedContainer.fromJson(Map<String, dynamic> j) => PackedContainer(
    containerId: j['container_id'] as int,
    containerCode: (j['container_code'] ?? '').toString(),
    quantity: (j['quantity'] ?? '0').toString(),
    packedAt: j['packed_at'] != null
        ? DateTime.tryParse(j['packed_at'].toString()) : null,
  );
}

class OrderLineFulfillment {
  final int lineId;
  final int productId;
  final String productArticle;
  final String productName;
  final String quantityPlanned;
  final String quantityDone;
  final String quantityShipped;
  final String quantityPacked;
  final int packedPlaces;
  final String packedWeightKg;
  final List<PackedContainer> packedContainers;
  final String toShipNow;
  final String shortToPlan;
  final String remaining;
  final String stockFinished;
  final String? castingArticle;
  final String? castingName;
  final String? castingNeeded;
  final String? castingStock;
  final String? castingShortage;

  OrderLineFulfillment({
    required this.lineId, required this.productId, required this.productArticle,
    required this.productName, required this.quantityPlanned, required this.quantityDone,
    required this.quantityShipped,
    this.quantityPacked = '0',
    this.packedPlaces = 0,
    this.packedWeightKg = '0',
    this.packedContainers = const [],
    this.toShipNow = '0', this.shortToPlan = '0',
    required this.remaining, required this.stockFinished,
    this.castingArticle, this.castingName, this.castingNeeded,
    this.castingStock, this.castingShortage,
  });

  factory OrderLineFulfillment.fromJson(Map<String, dynamic> j) => OrderLineFulfillment(
        lineId: j['line_id'] as int,
        productId: j['product_id'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        quantityPlanned: (j['quantity_planned'] ?? '0').toString(),
        quantityDone: (j['quantity_done'] ?? '0').toString(),
        quantityShipped: (j['quantity_shipped'] ?? '0').toString(),
        quantityPacked: (j['quantity_packed'] ?? '0').toString(),
        packedPlaces: (j['packed_places'] as num?)?.toInt() ?? 0,
        packedWeightKg: (j['packed_weight_kg'] ?? '0').toString(),
        packedContainers: ((j['packed_containers'] ?? []) as List)
            .map((e) => PackedContainer.fromJson(e as Map<String, dynamic>))
            .toList(),
        toShipNow: (j['to_ship_now'] ?? '0').toString(),
        shortToPlan: (j['short_to_plan'] ?? '0').toString(),
        remaining: (j['remaining'] ?? '0').toString(),
        stockFinished: (j['stock_finished'] ?? '0').toString(),
        castingArticle: j['casting_article'] as String?,
        castingName: j['casting_name'] as String?,
        castingNeeded: j['casting_needed']?.toString(),
        castingStock: j['casting_stock']?.toString(),
        castingShortage: j['casting_shortage']?.toString(),
      );

  double get shortageNum => double.tryParse(castingShortage ?? '0') ?? 0;
  double get plannedNum => double.tryParse(quantityPlanned) ?? 0;
  double get shippedNum => double.tryParse(quantityShipped) ?? 0;
  double get packedNum => double.tryParse(quantityPacked) ?? 0;
  double get toShipNum => double.tryParse(toShipNow) ?? 0;
  double get shortNum => double.tryParse(shortToPlan) ?? 0;

  /// Строка полностью покрыта отгрузкой+упаковкой
  bool get isCovered => shippedNum + packedNum >= plannedNum;

  /// Есть что отгружать прямо сейчас
  bool get hasReadyToShip => toShipNum > 0;
}

class OrderLine {
  final int id;
  final int product;
  final String productArticle;
  final String productName;
  final int? casting;
  final String? castingArticle;
  final String name;
  final String quantityPlanned;
  final String quantityDone;
  final String quantityShipped;
  final String comment;
  final int sequence;
  final String machine;
  final String? readyDate;
  final String? shippedDate;
  final int? places;
  final String? weightG;

  OrderLine({
    required this.id, required this.product, required this.productArticle,
    required this.productName, this.casting, this.castingArticle,
    required this.name, required this.quantityPlanned, required this.quantityDone,
    required this.quantityShipped, required this.comment,
    this.sequence = 0, this.machine = '', this.readyDate, this.shippedDate,
    this.places, this.weightG,
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: j['id'] as int,
        product: j['product'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        casting: j['casting'] as int?,
        castingArticle: j['casting_article'] as String?,
        name: (j['name'] ?? '').toString(),
        quantityPlanned: (j['quantity_planned'] ?? '0').toString(),
        quantityDone: (j['quantity_done'] ?? '0').toString(),
        quantityShipped: (j['quantity_shipped'] ?? '0').toString(),
        comment: (j['comment'] ?? '').toString(),
        sequence: j['sequence'] as int? ?? 0,
        machine: (j['machine'] ?? '').toString(),
        readyDate: j['ready_date'] as String?,
        shippedDate: j['shipped_date'] as String?,
        places: j['places'] as int?,
        weightG: j['weight_g']?.toString(),
      );
}

class OrderLineFlat {
  final int lineId;
  final int orderId;
  final String orderNumber;
  final String orderStatus;
  final String orderStatusDisplay;
  final String? orderDueDate;
  final String orderCustomer;
  final int sequence;
  final String machine;
  final int productId;
  final String productArticle;
  final String productName;
  final String? castingArticle;
  final String? castingName;
  final String name;
  final String quantityPlanned;
  final String quantityDone;
  final String quantityShipped;
  final String reserve;
  final String readyTotal;
  final String? readyDate;
  final String? shippedDate;
  final int? places;
  final String? weightG;
  final String? castingNeeded;
  final String? castingStock;
  final String? castingShortage;
  final bool? castingOk;
  final String quantityPacked;
  final String toShipNow;
  final String shortToPlan;

  OrderLineFlat({
    required this.lineId, required this.orderId, required this.orderNumber,
    required this.orderStatus, required this.orderStatusDisplay, this.orderDueDate,
    required this.orderCustomer,
    required this.sequence, required this.machine,
    required this.productId, required this.productArticle, required this.productName,
    this.castingArticle, this.castingName,
    required this.name,
    required this.quantityPlanned, required this.quantityDone,
    required this.quantityShipped,
    this.quantityPacked = '0', this.toShipNow = '0', this.shortToPlan = '0',
    required this.reserve, required this.readyTotal,
    this.readyDate, this.shippedDate, this.places, this.weightG,
    this.castingNeeded, this.castingStock, this.castingShortage, this.castingOk,
  });

  factory OrderLineFlat.fromJson(Map<String, dynamic> j) => OrderLineFlat(
        lineId: j['line_id'] as int,
        orderId: j['order_id'] as int,
        orderNumber: (j['order_number'] ?? '').toString(),
        orderStatus: (j['order_status'] ?? '').toString(),
        orderStatusDisplay: (j['order_status_display'] ?? '').toString(),
        orderDueDate: j['order_due_date'] as String?,
        orderCustomer: (j['order_customer'] ?? '').toString(),
        sequence: j['sequence'] as int? ?? 0,
        machine: (j['machine'] ?? '').toString(),
        productId: j['product_id'] as int,
        productArticle: (j['product_article'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        castingArticle: j['casting_article'] as String?,
        castingName: j['casting_name'] as String?,
        name: (j['name'] ?? '').toString(),
        quantityPlanned: (j['quantity_planned'] ?? '0').toString(),
        quantityDone: (j['quantity_done'] ?? '0').toString(),
        quantityShipped: (j['quantity_shipped'] ?? '0').toString(),
        reserve: (j['reserve'] ?? '0').toString(),
        readyTotal: (j['ready_total'] ?? '0').toString(),
        readyDate: j['ready_date'] as String?,
        shippedDate: j['shipped_date'] as String?,
        places: j['places'] as int?,
        weightG: j['weight_g']?.toString(),
        castingNeeded: j['casting_needed']?.toString(),
        castingStock: j['casting_stock']?.toString(),
        castingShortage: j['casting_shortage']?.toString(),
        castingOk: j['casting_ok'] as bool?,
        quantityPacked: (j['quantity_packed'] ?? '0').toString(),
        toShipNow: (j['to_ship_now'] ?? '0').toString(),
        shortToPlan: (j['short_to_plan'] ?? '0').toString(),
      );

  double get reserveNum => double.tryParse(reserve) ?? 0;
  double get plannedNum => double.tryParse(quantityPlanned) ?? 0;
  double get packedNum => double.tryParse(quantityPacked) ?? 0;
  double get toShipNum => double.tryParse(toShipNow) ?? 0;
  double get shippedNum => double.tryParse(quantityShipped) ?? 0;
  bool get isCovered => shippedNum + packedNum >= plannedNum;
  bool get hasReadyToShip => toShipNum > 0;
  double get weightKg {
    final w = double.tryParse(weightG ?? '0') ?? 0;
    return w / 1000.0;
  }
}

class Order {
  final int id;
  final String number;
  final String kind;
  final String kindDisplay;
  final String customer;
  final String status;
  final String statusDisplay;
  final String? dueDate;
  final String? comment;
  final DateTime? createdAt;
  final int linesCount;
  final List<OrderLine> lines;

  Order({
    required this.id, required this.number, required this.kind,
    required this.kindDisplay, required this.customer, required this.status,
    required this.statusDisplay, this.dueDate, this.comment,
    this.createdAt, required this.linesCount, this.lines = const [],
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        number: (j['number'] ?? '').toString(),
        kind: (j['kind'] ?? 'production').toString(),
        kindDisplay: (j['kind_display'] ?? '').toString(),
        customer: (j['customer'] ?? '').toString(),
        status: (j['status'] ?? 'new').toString(),
        statusDisplay: (j['status_display'] ?? '').toString(),
        dueDate: j['due_date'] as String?,
        comment: j['comment'] as String?,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
        linesCount: j['lines_count'] as int? ?? ((j['lines'] as List?)?.length ?? 0),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrdersRepo {
  final ApiClient _api;
  OrdersRepo(this._api);

  Future<List<Order>> list({String? search, String? status}) async {
    final q = <String, String>{'page': '1'};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (status != null && status.isNotEmpty) q['status'] = status;
    final resp = await _api.get('/api/orders/', query: q);
    final map = resp as Map<String, dynamic>;
    return (map['results'] as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> get(int id) async {
    final resp = await _api.get('/api/orders/$id/');
    return Order.fromJson(resp as Map<String, dynamic>);
  }

  Future<Order> create({
    required String number,
    required String kind,
    String customer = '',
    String? dueDate,
    String comment = '',
    required List<Map<String, dynamic>> lines,
  }) async {
    final resp = await _api.post('/api/orders/', body: {
      'number': number,
      'kind': kind,
      'customer': customer,
      'due_date': dueDate,
      'comment': comment,
      'lines': lines,
    });
    return Order.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/orders/$id/');
  }

  Future<void> setStatus(int id, String status, {String comment = ''}) async {
    await _api.post('/api/orders/$id/set-status/',
        body: {'status': status, 'comment': comment});
  }

  Future<OrderLine> addLine(int orderId, {
    required int productId,
    required String qtyPlanned,
    String name = '',
    String? castingArticle,
    String? machine,
    String? readyDate,
    String? shippedDate,
    int? places,
    String? weightG,
  }) async {
    final body = <String, dynamic>{
      'product': productId,
      'quantity_planned': qtyPlanned,
      'name': name,
    };
    if (machine != null) body['machine'] = machine;
    if (readyDate != null) body['ready_date'] = readyDate;
    if (shippedDate != null) body['shipped_date'] = shippedDate;
    if (places != null) body['places'] = places;
    if (weightG != null) body['weight_g'] = weightG;

    final resp = await _api.post('/api/orders/$orderId/add-line/', body: body);
    return OrderLine.fromJson(resp as Map<String, dynamic>);
  }

  Future<OrderLine> updateLine(int orderId, int lineId, {
    int? productId,
    String? qtyPlanned,
    String? name,
  }) async {
    final body = <String, dynamic>{};
    if (productId != null) body['product_id'] = productId;
    if (qtyPlanned != null) body['quantity_planned'] = qtyPlanned;
    if (name != null) body['name'] = name;
    final resp = await _api.post('/api/orders/$orderId/lines/$lineId/update/', body: body);
    return OrderLine.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> deleteLine(int orderId, int lineId) async {
    await _api.delete('/api/orders/$orderId/lines/$lineId/delete/');
  }

  Future<List<OrderLineFulfillment>> fulfillment(int id) async {
    final resp = await _api.get('/api/orders/$id/fulfillment/');
    final lines = ((resp as Map<String, dynamic>)['lines'] as List)
        .cast<Map<String, dynamic>>();
    return lines.map(OrderLineFulfillment.fromJson).toList();
  }

  /// Плоский список строк всех заказов (для сводной таблицы).
  Future<List<OrderLineFlat>> listLines({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final q = <String, String>{};
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (dateFrom != null) q['date_from'] = dateFrom;
    if (dateTo != null) q['date_to'] = dateTo;
    final resp = await _api.get('/api/orders/lines/', query: q);
    final rows = ((resp as Map<String, dynamic>)['rows'] as List)
        .cast<Map<String, dynamic>>();
    return rows.map(OrderLineFlat.fromJson).toList();
  }
}
