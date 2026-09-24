import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movement.dart';
import '../../services/api_client.dart';
import '../../services/movements_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<MovementRow> _rows = [];
  int _total = 0;
  String _incomingTotal = '0';
  String _outgoingTotal = '0';
  bool _loading = true;
  String? _error;

  bool? _hasContainer;
  String _datePreset = 'week';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      _load();
    });
    _setPreset('week', reload: false);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _currentTab {
    switch (_tabCtrl.index) {
      case 1:
        return 'incoming';
      case 2:
        return 'outgoing';
      case 3:
        return 'transfer';
      default:
        return null;
    }
  }

  void _setPreset(String preset, {bool reload = true}) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;
    switch (preset) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        to = from;
        break;
      case 'week':
        from = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        to = now;
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        to = now;
        break;
      case 'all':
        from = null;
        to = null;
        break;
    }
    setState(() {
      _datePreset = preset;
      _dateFrom = from;
      _dateTo = to;
    });
    if (reload) _load();
  }

  String? _fmt(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await MovementsRepo(context.read<ApiClient>()).list(
        search: _searchCtrl.text.trim(),
        tab: _currentTab,
        dateFrom: _fmt(_dateFrom),
        dateTo: _fmt(_dateTo),
        hasContainer: _hasContainer,
      );
      if (!mounted) return;
      setState(() {
        _rows = r.rows;
        _total = r.count;
        _incomingTotal = r.incomingTotal;
        _outgoingTotal = r.outgoingTotal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _exportCsv() {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нечего экспортировать')));
      return;
    }
    CsvExporter.export(
      filename: 'movements_${CsvExporter.today()}.csv',
      headers: const [
        'Дата', 'Тип', 'Артикул', 'Наименование', 'Кол-во',
        'Откуда', 'Куда', 'Тара (ШК)', 'Заказ', 'Кто', 'Комментарий',
      ],
      rows: _rows.map((r) => [
        CsvExporter.dateTimeStr(r.createdAt),
        r.movementTypeDisplay,
        r.productArticle,
        r.productName,
        CsvExporter.numStr(r.quantity),
        r.warehouseFromName ?? '',
        r.warehouseToName ?? '',
        r.containerCode ?? '',
        r.orderNumber ?? '',
        r.createdByUsername ?? '',
        r.comment,
      ]).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${_rows.length} строк')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Движения ($_total)'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Всё'),
            Tab(text: 'Приходы'),
            Tab(text: 'Расходы'),
            Tab(text: 'Перемещения'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Экспорт в Excel (CSV)',
            onPressed: _exportCsv,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: const InputDecoration(
              hintText: 'Поиск: артикул, тара, комментарий',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Период:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final p in const [
              ('today', 'Сегодня'), ('week', 'Неделя'),
              ('month', 'Месяц'), ('all', 'Всё время')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.$2),
                  selected: _datePreset == p.$1,
                  onSelected: (_) => _setPreset(p.$1))),
            const SizedBox(width: 16),
            const Text('ШК:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final s in const [
              (null, 'Все'), (true, 'С ШК'), (false, 'Без ШК')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.$2),
                  selected: _hasContainer == s.$1,
                  onSelected: (_) {
                    setState(() => _hasContainer = s.$1);
                    _load();
                  })),
          ]),
        ),
        _buildTotalsBar(),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildTotalsBar() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(spacing: 20, runSpacing: 4, children: [
        _stat('Приходы (всего)', _incomingTotal, Colors.green),
        _stat('Расходы (всего)', _outgoingTotal, Colors.orange),
        _stat('Записей', '$_total', Colors.grey),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) {
    final n = double.tryParse(value) ?? 0;
    final txt = n == 0
        ? '0'
        : (n == n.roundToDouble()
            ? n.toStringAsFixed(0)
            : n.toStringAsFixed(2));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ',
          style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w600)),
      Text(txt, style: TextStyle(color: color,
          fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_rows.isEmpty) {
      return const Center(child: Text('Движений за период нет',
          style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 44,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 48,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Дата')),
            DataColumn(label: _Th('Тип')),
            DataColumn(label: _Th('Артикул')),
            DataColumn(label: _Th('Наименование')),
            DataColumn(numeric: true, label: _Th('Кол-во')),
            DataColumn(label: _Th('Откуда')),
            DataColumn(label: _Th('Куда')),
            DataColumn(label: _Th('Тара (ШК)')),
            DataColumn(label: _Th('Заказ')),
            DataColumn(label: _Th('Кто')),
            DataColumn(label: _Th('Комментарий')),
          ],
          rows: _rows.map(_buildRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(MovementRow r) {
    final dt = r.createdAt?.toLocal();
    final dateStr = dt == null
        ? '—'
        : '${dt.day.toString().padLeft(2, '0')}.'
            '${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';

    Color rowColor = Colors.transparent;
    Color typeColor = Colors.grey;
    if (r.isIncoming) {
      rowColor = Colors.green.shade50.withOpacity(0.5);
      typeColor = Colors.green;
    } else if (r.isOutgoing) {
      rowColor = Colors.orange.shade50.withOpacity(0.5);
      typeColor = Colors.orange;
    } else if (r.isTransfer) {
      rowColor = Colors.indigo.shade50.withOpacity(0.5);
      typeColor = Colors.indigo;
    }

    final qtyNum = double.tryParse(r.quantity) ?? 0;
    final qtyText = qtyNum == qtyNum.roundToDouble()
        ? qtyNum.toStringAsFixed(0)
        : qtyNum.toStringAsFixed(2);

    return DataRow(
      color: MaterialStateProperty.all(rowColor),
      cells: [
        DataCell(Text(dateStr, style: const TextStyle(fontSize: 13))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(r.movementTypeDisplay,
              style: TextStyle(color: typeColor,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        )),
        DataCell(Text(r.productArticle,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(r.productName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)))),
        DataCell(Text(qtyText,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13))),
        DataCell(Text(r.warehouseFromName ?? '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.warehouseToName ?? '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(r.hasContainer
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code, size: 12,
                      color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(r.containerCode!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: Colors.blue)),
                ]),
              )
            : const Text('—',
                style: TextStyle(color: Colors.grey, fontSize: 13))),
        DataCell(Text(r.orderNumber ?? '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(r.createdByUsername ?? '—',
            style: const TextStyle(fontSize: 12))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(r.comment,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)))),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
