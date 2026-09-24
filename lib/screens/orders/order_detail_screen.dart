import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/orders_repo.dart';
import '../../services/products_repo.dart';
import '../../widgets/product_search_field.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  List<OrderLineFulfillment> _lines = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  OrdersRepo get _repo => OrdersRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await _repo.get(widget.orderId);
      final lines = await _repo.fulfillment(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
        _lines = lines;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String newStatus) async {
    setState(() => _busy = true);
    try {
      await _repo.setStatus(widget.orderId, newStatus);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOrder() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Удалить заказ?'),
              content: const Text('Заказ и все его позиции будут удалены безвозвратно.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить')),
              ],
            ));
    if (ok != true) return;
    try {
      await _repo.delete(widget.orderId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addLine() async {
    final parts = await ProductsRepo(context.read<ApiClient>()).listByType('part');
    if (!mounted) return;
    final newLine = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _LineDialog(parts: parts));
    if (newLine == null) return;
    try {
      await _repo.addLine(widget.orderId,
          productId: newLine['product_id'] as int,
          qtyPlanned: newLine['quantity'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editLine(OrderLine line) async {
    final parts = await ProductsRepo(context.read<ApiClient>()).listByType('part');
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _LineDialog(parts: parts, initial: line));
    if (result == null) return;
    try {
      await _repo.updateLine(widget.orderId, line.id,
          productId: result['product_id'] as int,
          qtyPlanned: result['quantity'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteLine(OrderLine line) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              content: Text('Удалить позицию ${line.productArticle}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить')),
              ],
            ));
    if (ok != true) return;
    try {
      await _repo.deleteLine(widget.orderId, line.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order != null ? 'Заказ №${_order!.number}' : 'Заказ'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _deleteOrder),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final o = _order!;
    return Stack(children: [
      ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Chip(label: Text(o.statusDisplay)),
                        const SizedBox(width: 8),
                        Chip(label: Text(o.kindDisplay)),
                      ]),
                      const SizedBox(height: 8),
                      if (o.customer.isNotEmpty)
                        Text('Заказчик: ${o.customer}'),
                      if (o.dueDate != null) Text('Срок: ${o.dueDate}'),
                      if ((o.comment ?? '').isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(o.comment!)),
                    ]))),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
              child: Text('Позиции',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: const Text('Позиция')),
        ]),
        const SizedBox(height: 8),
        if (o.lines.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Нет позиций')))
        else
          ...o.lines.map((l) {
            final ff = _lines.firstWhere(
              (x) => x.lineId == l.id,
              orElse: () => _emptyFf(l),
            );
            return _buildPositionCard(l, ff);
          }),
        const SizedBox(height: 24),
        const Text('Сменить статус',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ('new', 'Новый'),
          ('in_work', 'В работе'),
          ('ready', 'Готов'),
          ('shipped', 'Отгружен'),
          ('closed', 'Закрыт'),
        ]
            .map((s) => OutlinedButton(
                  onPressed: o.status == s.$1 || _busy
                      ? null
                      : () => _setStatus(s.$1),
                  child: Text(s.$2),
                ))
            .toList()),
        const SizedBox(height: 24),
      ]),
      if (_busy)
        Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator())),
    ]);
  }

  OrderLineFulfillment _emptyFf(OrderLine l) => OrderLineFulfillment(
        lineId: l.id,
        productId: l.product,
        productArticle: l.productArticle,
        productName: l.productName,
        quantityPlanned: l.quantityPlanned,
        quantityDone: l.quantityDone,
        quantityShipped: l.quantityShipped,
        remaining: '0',
        stockFinished: '0',
      );

  // ─── КАРТОЧКА ПОЗИЦИИ С ТАБЛИЦЕЙ ─────────────────────────────────
  Widget _buildPositionCard(OrderLine l, OrderLineFulfillment ff) {
    final isCovered = ff.isCovered;         // отгружено + упаковано >= план
    final hasReady = ff.hasReadyToShip;      // есть что отгружать сейчас

    // Цвет левой полоски
    Color barColor;
    if (isCovered) {
      barColor = Colors.green.shade700;
    } else if (hasReady) {
      barColor = Colors.green.shade400;
    } else {
      barColor = Colors.orange.shade400;
    }

    // Статус
    String statusText;
    Color statusBg;
    Color statusFg;
    if (ff.shippedNum >= ff.plannedNum && ff.plannedNum > 0) {
      statusText = 'Отгружено полностью';
      statusBg = Colors.blue.shade100;
      statusFg = Colors.blue.shade900;
    } else if (isCovered) {
      statusText = '✓ Готово к отгрузке';
      statusBg = Colors.green.shade100;
      statusFg = Colors.green.shade900;
    } else if (hasReady) {
      statusText = 'Частично готово (${_fmt(ff.toShipNum)})';
      statusBg = Colors.lightGreen.shade100;
      statusFg = Colors.green.shade800;
    } else {
      statusText = 'В работе';
      statusBg = Colors.orange.shade100;
      statusFg = Colors.orange.shade900;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: barColor, width: 5),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок позиции
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.productArticle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.name.isNotEmpty ? l.name : l.productName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusFg),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editLine(l);
                    if (v == 'delete') _deleteLine(l);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ]),
              const SizedBox(height: 10),

              // ТАБЛИЦА показателей
              _buildMetricsTable(l, ff),

              // Список упакованных тар (если есть)
              if (ff.packedContainers.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildPackedContainers(ff.packedContainers),
              ],

              // Литьё
              if (ff.castingArticle != null) ...[
                const SizedBox(height: 8),
                _buildCastingRow(ff),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── ТАБЛИЦА ПОКАЗАТЕЛЕЙ ─────────────────────────────────────────
  Widget _buildMetricsTable(OrderLine l, OrderLineFulfillment ff) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        border: TableBorder.all(
          color: Colors.grey.shade300,
          width: 0.5,
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(0.8),
          5: FlexColumnWidth(1.2),
        },
        children: [
          // Шапка
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: [
              _th('План'),
              _th('Отгр.'),
              _th('Упак.'),
              _th('Остаток'),
              _th('Мест'),
              _th('Вес, кг'),
            ],
          ),
          // Данные
          TableRow(
            children: [
              _td(_fmt(ff.plannedNum), bold: true),
              _td(_fmt(ff.shippedNum),
                  color: ff.shippedNum > 0 ? Colors.indigo : null),
              _td(_fmt(ff.packedNum),
                  color: ff.packedNum > 0 ? Colors.green.shade800 : null,
                  bold: ff.packedNum > 0),
              _td(_fmt(ff.shortNum),
                  color: ff.shortNum > 0 ? Colors.red.shade700 : null),
              _td(ff.packedPlaces > 0 ? '${ff.packedPlaces}' : '—',
                  color: ff.packedPlaces > 0 ? Colors.teal.shade800 : null,
                  bold: ff.packedPlaces > 0),
              _td(ff.packedWeightKg != '0' && ff.packedWeightKg != '0.000'
                      ? ff.packedWeightKg
                      : '—',
                  color: ff.packedWeightKg != '0.000'
                      ? Colors.teal.shade800 : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
      );

  Widget _td(String t, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      );

  // ─── СПИСОК УПАКОВАННЫХ ТАР ──────────────────────────────────────
  Widget _buildPackedContainers(List<PackedContainer> containers) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.inventory_2,
                size: 14, color: Colors.green.shade800),
            const SizedBox(width: 4),
            Text('Упаковано в ${containers.length} тар:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900)),
          ]),
          const SizedBox(height: 4),
          ...containers.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.qr_code,
                      size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.containerCode,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace',
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${c.quantity} шт',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (c.packedAt != null)
                    Text(_fmtDate(c.packedAt!),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade700)),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildCastingRow(OrderLineFulfillment ff) {
    final isShort = ff.shortageNum > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isShort ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Icon(Icons.precision_manufacturing,
            size: 12,
            color: isShort ? Colors.red.shade700 : Colors.grey.shade700),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Литьё ${ff.castingArticle}: нужно ${ff.castingNeeded ?? "—"}, '
            'на складе ${ff.castingStock ?? "—"}',
            style: TextStyle(
                fontSize: 11,
                color: isShort ? Colors.red.shade800 : Colors.grey.shade700),
          ),
        ),
        if (isShort)
          Text('дефицит ${ff.castingShortage}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800)),
      ]),
    );
  }

  String _fmt(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(3);
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

// ─── ДИАЛОГ РЕДАКТИРОВАНИЯ ПОЗИЦИИ ──────────────────────────────────
class _LineDialog extends StatefulWidget {
  final List<Product> parts;
  final OrderLine? initial;
  const _LineDialog({required this.parts, this.initial});
  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  final _qtyCtrl = TextEditingController();
  int? _productId;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _productId = widget.initial!.product;
      _qtyCtrl.text = widget.initial!.quantityPlanned;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initial == null ? 'Добавить позицию' : 'Изменить позицию'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ProductSearchField(
          products: widget.parts,
          value: _productId,
          label: 'Деталь',
          onChanged: (v) => setState(() => _productId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qtyCtrl,
          decoration: const InputDecoration(
              labelText: 'Количество',
              border: OutlineInputBorder(),
              suffixText: 'шт'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          ],
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () {
              if (_productId == null) return;
              final q = _qtyCtrl.text.trim().replaceAll(',', '.');
              if (q.isEmpty) return;
              Navigator.pop(context, {'product_id': _productId, 'quantity': q});
            },
            child: const Text('OK')),
      ],
    );
  }
}
