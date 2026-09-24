import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/reports_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});
  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  List<StockReportRow> _rows = [];
  bool _loading = true;
  String? _error;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ReportsRepo(context.read<ApiClient>()).stock();
      if (!mounted) return;
      setState(() => _rows = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StockReportRow> get _filtered {
    var list = _rows;
    if (_typeFilter != 'all') {
      list = list.where((r) => r.productType == _typeFilter).toList();
    }
    if (_statusFilter == 'below') {
      list = list.where((r) => r.belowMin).toList();
    } else if (_statusFilter == 'ok') {
      list = list.where((r) => !r.belowMin).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.article.toLowerCase().contains(q) ||
          r.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _exportCsv() {
    final rows = _filtered;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нечего экспортировать')));
      return;
    }
    CsvExporter.export(
      filename: 'stock_${CsvExporter.today()}.csv',
      headers: const [
        'Артикул', 'Наименование', 'Тип', 'Склад',
        'На складе', 'В тарах', 'Задел', 'Минимум', 'Статус',
      ],
      rows: rows.map((r) => [
        r.article,
        r.name,
        r.productTypeDisplay,
        r.warehouse,
        CsvExporter.numStr(r.quantity),
        CsvExporter.numStr(r.inContainers),
        CsvExporter.numStr(r.freeStock),
        CsvExporter.numStr(r.minStock),
        r.belowMin ? 'Ниже минимума' : 'В норме',
      ]).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${rows.length} строк')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _rows.length;
    final low = _rows.where((r) => r.belowMin).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Остатки ($total)'),
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
            decoration: const InputDecoration(
              hintText: 'Поиск по артикулу или наименованию',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Тип:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final t in const [
              ('all', 'Все'), ('casting', 'Литьё'),
              ('part', 'Детали'), ('finished', 'Готовые')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(t.$2),
                  selected: _typeFilter == t.$1,
                  onSelected: (_) => setState(() => _typeFilter = t.$1))),
            const SizedBox(width: 16),
            const Text('Статус:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            for (final s in const [
              ('all', 'Все'), ('below', 'Ниже минимума'), ('ok', 'В норме')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.$2),
                  selected: _statusFilter == s.$1,
                  onSelected: (_) => setState(() => _statusFilter = s.$1))),
          ]),
        ),
        if (low > 0)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Icon(Icons.warning_amber, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 8),
              Text('Позиций ниже минимума: $low',
                  style: TextStyle(color: Colors.red.shade700,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Ошибка: $_error', textAlign: TextAlign.center),
      ));
    }
    final rows = _filtered;
    if (rows.isEmpty) {
      return const Center(child: Text('Остатков нет'));
    }

    const order = ['casting', 'part', 'finished', 'raw'];
    final groups = <String, List<StockReportRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.productType, () => []).add(r);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });

    final dataRows = <DataRow>[];
    for (final k in keys) {
      dataRows.add(DataRow(
        color: MaterialStateProperty.all(Colors.blueGrey.shade50),
        cells: [
          DataCell(Text(_typeLabel(k),
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 12, color: Colors.blueGrey))),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
        ],
      ));
      for (final r in groups[k]!) {
        dataRows.add(DataRow(
          color: r.belowMin
              ? MaterialStateProperty.all(Colors.red.shade50)
              : null,
          cells: [
            DataCell(Text(r.article,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            DataCell(ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(r.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)))),
            DataCell(_typeChip(r.productType)),
            DataCell(_num(r.quantity, bold: true)),
            DataCell(_num(r.inContainers, color: Colors.blue)),
            DataCell(_num(r.freeStock, color: Colors.green)),
            DataCell(_num(r.minStock, color: Colors.grey.shade700)),
            DataCell(r.belowMin
                ? _chip('Ниже минимума', Colors.red)
                : _chip('В норме', Colors.green)),
          ],
        ));
      }
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 42,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 40,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Артикул')),
            DataColumn(label: _Th('Наименование')),
            DataColumn(label: _Th('Тип')),
            DataColumn(numeric: true, label: _Th('На складе')),
            DataColumn(numeric: true, label: _Th('В тарах')),
            DataColumn(numeric: true, label: _Th('Задел')),
            DataColumn(numeric: true, label: _Th('Мин.')),
            DataColumn(label: _Th('Статус')),
          ],
          rows: dataRows,
        ),
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'raw': return 'СЫРЬЁ';
      case 'casting': return 'ЛИТЬЁ';
      case 'part': return 'ДЕТАЛИ';
      case 'finished': return 'ГОТОВАЯ ПРОДУКЦИЯ';
      default: return t.toUpperCase();
    }
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color,
          fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _typeChip(String type) {
    String label; Color color;
    switch (type) {
      case 'raw': label = 'Сырьё'; color = Colors.brown; break;
      case 'casting': label = 'Литьё'; color = Colors.blueGrey; break;
      case 'part': label = 'Деталь'; color = Colors.indigo; break;
      case 'finished': label = 'Готовая'; color = Colors.green; break;
      default: label = type; color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color,
          fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _num(String s, {Color? color, bool bold = false}) {
    final n = double.tryParse(s) ?? 0;
    final text = n == 0
        ? '—'
        : (n == n.roundToDouble()
            ? n.toStringAsFixed(0)
            : n.toStringAsFixed(3));
    return Text(text, style: TextStyle(
        fontSize: 13, color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal));
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
