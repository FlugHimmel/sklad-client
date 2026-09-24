import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/orders_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'orders_paste_import_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<OrderLineFlat> _items = [];
  bool _loading = true;
  String? _error;
  String? _filterStatus;
  int? _selectedOrderId;
  String _datePreset = 'all';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _statuses = [
    ('new', 'Новый', Colors.grey),
    ('in_work', 'В работе', Colors.orange),
    ('ready', 'Готов', Colors.blue),
    ('shipped', 'Отгружен', Colors.green),
    ('closed', 'Закрыт', Colors.black54),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await OrdersRepo(context.read<ApiClient>()).listLines(
        search: _searchCtrl.text.trim(),
        status: _filterStatus,
        dateFrom: _fmtDate(_dateFrom),
        dateTo: _fmtDate(_dateTo),
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        if (_selectedOrderId != null &&
            !list.any((r) => r.orderId == _selectedOrderId)) {
          _selectedOrderId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void _setPreset(String p) {
    final now = DateTime.now();
    DateTime? f, t;
    switch (p) {
      case 'today':
        f = DateTime(now.year, now.month, now.day);
        t = f;
        break;
      case 'week':
        f = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        t = now;
        break;
      case 'month':
        f = DateTime(now.year, now.month, 1);
        t = now;
        break;
      case 'all':
        f = null;
        t = null;
        break;
    }
    setState(() {
      _datePreset = p;
      _dateFrom = f;
      _dateTo = t;
    });
    _load();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openOrder(int orderId) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
    _load();
  }

  Future<void> _createOrder() async {
    final created = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const OrderFormScreen()));
    if (created == true) _load();
  }

  Future<void> _openImport() async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const OrdersPasteImportScreen()));
    if (changed == true) _load();
  }

  /// Список заказов с их количеством строк — для чипов сверху.
  /// Сортировка: новые → в работе → готовые → отгруженные → закрытые,
  /// внутри группы — по номеру (убыв.).
  List<MapEntry<int, (String, int, String)>> get _orderGroups {
    final map = <int, (String, int, String)>{};
    for (final r in _items) {
      final cur = map[r.orderId];
      if (cur == null) {
        map[r.orderId] = (r.orderNumber, 1, r.orderStatus);
      } else {
        map[r.orderId] = (cur.$1, cur.$2 + 1, cur.$3);
      }
    }
    final list = map.entries.toList()
      ..sort((a, b) {
        final wA = _statusWeight(a.value.$3);
        final wB = _statusWeight(b.value.$3);
        if (wA != wB) return wA.compareTo(wB);
        // Внутри группы — по номеру (обратный порядок — свежие сверху)
        return b.value.$1.compareTo(a.value.$1);
      });
    return list;
  }

  /// Вес статуса для сортировки.
  int _statusWeight(String status) {
    switch (status) {
      case 'new':      return 1;  // новые — сверху
      case 'in_work':  return 2;  // в работе
      case 'ready':    return 3;  // готовые
      case 'shipped':  return 4;  // отгруженные
      case 'closed':   return 5;  // закрытые
      default:         return 9;
    }
  }

  /// Что показываем в таблице (после чипа заказа).
  List<OrderLineFlat> get _displayed {
    if (_selectedOrderId == null) return _items;
    return _items.where((r) => r.orderId == _selectedOrderId).toList();
  }

  void _exportCsv() {
    final rows = _displayed;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нечего экспортировать')));
      return;
    }
    CsvExporter.export(
      filename: 'orders_${CsvExporter.today()}.csv',
      headers: const [
        '№станка', 'п/п', 'Заказ', 'Литьё', 'МО', 'Наименование',
        'Кол-во', 'Срок', 'Готовность', 'Задел', 'Отгружено',
        'Мест', 'Вес', 'Статус', 'Литьё есть?',
      ],
      rows: rows.map((r) => [
        r.machine,
        '${r.sequence}',
        r.orderNumber,
        r.castingArticle ?? '',
        r.productArticle,
        r.productName,
        CsvExporter.numStr(r.quantityPlanned),
        _fmtDateOut(r.orderDueDate),
        _fmtDateOut(r.readyDate),
        CsvExporter.numStr(r.reserve),
        _fmtDateOut(r.shippedDate),
        r.places?.toString() ?? '',
        r.weightG == null ? '' : r.weightKg.toStringAsFixed(3),
        r.orderStatusDisplay,
        r.castingOk == null ? '—' : (r.castingOk! ? 'Да' : 'Нет'),
      ]).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${rows.length} строк')),
    );
  }

  String _fmtDateOut(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderCount = _items.map((e) => e.orderId).toSet().length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы ($orderCount / ${_items.length} строк)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_go),
            tooltip: 'Импорт из Excel (вставить)',
            onPressed: _openImport,
          ),
          IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Экспорт в Excel (CSV)',
              onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createOrder,
        icon: const Icon(Icons.add),
        label: const Text('Новый заказ'),
      ),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Поиск: заказ, артикул, наименование',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            FilterChip(
              label: const Text('Все статусы'),
              selected: _filterStatus == null,
              onSelected: (_) {
                setState(() => _filterStatus = null);
                _load();
              },
            ),
            ..._statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(s.$2),
                    selected: _filterStatus == s.$1,
                    onSelected: (v) {
                      setState(() => _filterStatus = v ? s.$1 : null);
                      _load();
                    },
                  ),
                )),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Период по сроку:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final p in const [
              ('today', 'Сегодня'),
              ('week', 'Неделя'),
              ('month', 'Месяц'),
              ('all', 'Всё время')
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.$2),
                  selected: _datePreset == p.$1,
                  onSelected: (_) => _setPreset(p.$1),
                ),
              ),
          ]),
        ),
        if (_items.isNotEmpty) _buildOrderChips(),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildOrderChips() {
    final groups = _orderGroups;
    return Container(
      height: 46,
      color: Colors.blueGrey.shade50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('Все (${_items.length})'),
              selected: _selectedOrderId == null,
              onSelected: (_) => setState(() => _selectedOrderId = null),
            ),
          ),
          ...groups.map((e) {
            final orderId = e.key;
            final (num, cnt, _) = e.value;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('$num ($cnt)'),
                selected: _selectedOrderId == orderId,
                onSelected: (_) => setState(() => _selectedOrderId = orderId),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    final rows = _displayed;
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Заказов нет', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _createOrder,
              icon: const Icon(Icons.add),
              label: const Text('Создать первый заказ'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openImport,
              icon: const Icon(Icons.content_paste_go),
              label: const Text('Импорт из Excel'),
            ),
          ],
        ),
      );
    }
    return _buildTable(rows);
  }

  Widget _buildTable(List<OrderLineFlat> rows) {
    double totalQty = 0, totalPlaces = 0, totalWeight = 0;
    for (final r in rows) {
      totalQty += double.tryParse(r.quantityPlanned) ?? 0;
      totalPlaces += (r.places ?? 0).toDouble();
      totalWeight += r.weightKg;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              horizontalMargin: 10,
              headingRowHeight: 44,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 44,
              headingRowColor:
                  MaterialStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: _Th('№станка')),
                DataColumn(numeric: true, label: _Th('п/п')),
                DataColumn(label: _Th('Заказ')),
                DataColumn(label: _Th('Литьё')),
                DataColumn(label: _Th('МО')),
                DataColumn(label: _Th('Наименование')),
                DataColumn(numeric: true, label: _Th('Кол-во')),
                DataColumn(numeric: true, label: _Th('Упаков.')),
                DataColumn(numeric: true, label: _Th('К отгр.')),
                DataColumn(label: _Th('Срок')),
                DataColumn(label: _Th('Готовность')),
                DataColumn(numeric: true, label: _Th('Задел')),
                DataColumn(label: _Th('Отгружено')),
                DataColumn(numeric: true, label: _Th('Мест')),
                DataColumn(numeric: true, label: _Th('Вес, кг')),
                DataColumn(label: _Th('Статус')),
                DataColumn(label: _Th('Литьё')),
                DataColumn(label: _Th('')),
              ],
              rows: _buildDataRows(rows),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blueGrey.shade50,
            child: Wrap(spacing: 20, runSpacing: 4, children: [
              Text('Строк: ${rows.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Итого кол-во: ${_fmtNum(totalQty)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Мест: ${_fmtNum(totalPlaces)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Вес: ${totalWeight.toStringAsFixed(3)} кг',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildDataRows(List<OrderLineFlat> rows) {
    final out = <DataRow>[];
    final seen = <int>{};
    for (final r in rows) {
      final isFirstOfOrder = !seen.contains(r.orderId);
      seen.add(r.orderId);
      out.add(_buildRow(r, isFirstOfOrder));
    }
    return out;
  }

  DataRow _buildRow(OrderLineFlat r, bool isFirstOfOrder) {
    Color? rowColor;
    final st = _statuses.firstWhere(
      (x) => x.$1 == r.orderStatus,
      orElse: () => ('', r.orderStatusDisplay, Colors.grey),
    );
    if (r.orderStatus == 'shipped') {
      rowColor = Colors.green.shade50;
    } else if (r.orderStatus == 'closed') {
      rowColor = Colors.grey.shade100;
    } else if (r.isCovered) {
      // Упаковано+отгружено >= план — можно закрывать
      rowColor = Colors.green.shade50;
    } else if (r.hasReadyToShip) {
      // Есть что отгружать прямо сейчас
      rowColor = Colors.green.shade50.withOpacity(0.5);
    }
    final reserveColor = r.reserveNum > 0
        ? Colors.green.shade700
        : (r.reserveNum < 0 ? Colors.red.shade700 : Colors.grey.shade700);

    return DataRow(
      color: rowColor == null ? null : MaterialStateProperty.all(rowColor),
      cells: [
        DataCell(Text(r.machine.isEmpty ? '—' : r.machine,
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.sequence == 0 ? '—' : '${r.sequence}',
            style: const TextStyle(fontSize: 12))),
        DataCell(
          isFirstOfOrder
              ? InkWell(
                  onTap: () => _openOrder(r.orderId),
                  child: Text(r.orderNumber,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                )
              : const SizedBox.shrink(),
        ),
        DataCell(Text(r.castingArticle ?? '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.productArticle,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(r.productName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        )),
        DataCell(Text(_fmtNum(r.plannedNum),
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        DataCell(r.packedNum > 0
            ? Text(_fmtNum(r.packedNum),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800))
            : const Text('—', style: TextStyle(fontSize: 13, color: Colors.grey))),
        DataCell(r.toShipNum > 0
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(_fmtNum(r.toShipNum),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900)),
              )
            : const Text('—', style: TextStyle(fontSize: 13, color: Colors.grey))),
        DataCell(Text(_fmtDateOut(r.orderDueDate),
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(_fmtDateOut(r.readyDate),
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.reserveNum == 0 ? '—' : _fmtSigned(r.reserveNum),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: reserveColor))),
        DataCell(Text(_fmtDateOut(r.shippedDate),
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.places == null ? '—' : '${r.places}',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.weightKg > 0 ? r.weightKg.toStringAsFixed(3) : '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(_statusChip(st.$2, st.$3)),
        DataCell(_castingIcon(r)),
        DataCell(IconButton(
          icon: const Icon(Icons.arrow_forward, size: 18),
          tooltip: 'Открыть заказ',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _openOrder(r.orderId),
        )),
      ],
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _castingIcon(OrderLineFlat r) {
    if (r.castingArticle == null) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }
    if (r.castingOk == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text('${r.castingStock ?? "?"}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cancel, size: 12, color: Colors.red.shade700),
        const SizedBox(width: 4),
        Text('−${r.castingShortage ?? "?"}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800)),
      ]),
    );
  }

  String _fmtNum(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }

  String _fmtSigned(double n) {
    final s =
        n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    return n > 0 ? '+$s' : s;
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
