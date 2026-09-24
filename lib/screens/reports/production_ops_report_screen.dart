import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/reports_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';

class ProductionOpsReportScreen extends StatefulWidget {
  const ProductionOpsReportScreen({super.key});
  @override
  State<ProductionOpsReportScreen> createState() =>
      _ProductionOpsReportScreenState();
}

class _ProductionOpsReportScreenState
    extends State<ProductionOpsReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _opType;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ReportsRepo(context.read<ApiClient>());
      final data = await repo.productionOps(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _search,
        operationType: _opType,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _load();
  }

  void _setPreset(String p) {
    final now = DateTime.now();
    DateTime from, to;
    switch (p) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        to = now;
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
      case 'quarter':
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        from = DateTime(now.year, q, 1);
        to = now;
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        to = now;
        break;
      default:
        from = DateTime(now.year, now.month, 1);
        to = now;
    }
    setState(() {
      _dateFrom = from;
      _dateTo = to;
    });
    _load();
  }

  Future<void> _pickCustomPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
    );
    if (range == null) return;
    setState(() {
      _dateFrom = range.start;
      _dateTo = range.end;
    });
    _load();
  }

  void _exportCsv() {
    final d = _data;
    if (d == null) return;
    final rows = <List<String>>[];
    rows.add(['ИТОГИ']);
    final t = d['totals'] as Map<String, dynamic>;
    rows.add(['Операций', 'Взято', 'Получено', 'Брак', '% брака']);
    rows.add([
      t['operations'].toString(),
      CsvExporter.numStr(t['from_total'].toString()),
      CsvExporter.numStr(t['to_total'].toString()),
      CsvExporter.numStr(t['scrap_total'].toString()),
      t['scrap_percent'].toString(),
    ]);
    rows.add([]);
    rows.add(['ПО ОПЕРАТОРАМ']);
    rows.add(['Оператор', 'Операций', 'Взято', 'Получено', 'Брак', '% брака']);
    for (final o in (d['by_operator'] as List)) {
      final m = o as Map<String, dynamic>;
      rows.add([
        m['operator'].toString(),
        m['operations'].toString(),
        CsvExporter.numStr(m['from_total'].toString()),
        CsvExporter.numStr(m['to_total'].toString()),
        CsvExporter.numStr(m['scrap_total'].toString()),
        m['scrap_percent'].toString(),
      ]);
    }
    rows.add([]);
    rows.add(['ПО АРТИКУЛАМ']);
    rows.add(['Артикул', 'Наименование', 'Взято', 'Получено', 'Брак']);
    for (final p in (d['by_product'] as List)) {
      final m = p as Map<String, dynamic>;
      rows.add([
        m['article'].toString(),
        m['name'].toString(),
        CsvExporter.numStr(m['from_qty'].toString()),
        CsvExporter.numStr(m['to_qty'].toString()),
        CsvExporter.numStr(m['scrap_qty'].toString()),
      ]);
    }
    CsvExporter.export(
      filename: 'production_ops_${CsvExporter.today()}.csv',
      headers: const ['Раздел'],
      rows: rows,
    );
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экспорт готов')));
  }

  @override
  Widget build(BuildContext context) {
    final t = _data?['totals'] as Map<String, dynamic>?;
    final title = t == null
        ? 'Производство'
        : 'Производство: ${t['operations']} операций';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'CSV',
              onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск по оператору, артикулу, таре',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => _load(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(true),
                child: Text('С: ${_fmtDisplay(_dateFrom)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(false),
                child: Text('По: ${_fmtDisplay(_dateTo)}'),
              ),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            for (final p in const [
              ('today', 'Сегодня'),
              ('week', 'Неделя'),
              ('month', 'Месяц'),
              ('quarter', 'Квартал'),
              ('year', 'Год'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(p.$2),
                  onPressed: () => _setPreset(p.$1),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.calendar_month, size: 16),
                label: const Text('Свой период'),
                onPressed: _pickCustomPeriod,
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    final d = _data;
    if (d == null) return const Center(child: Text('Нет данных'));
    final t = d['totals'] as Map<String, dynamic>;
    if ((t['operations'] as int) == 0) {
      return const Center(
          child: Text('За период операций нет',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView(children: [
      _buildTotals(t),
      _buildOperatorTable(d['by_operator'] as List),
      const SizedBox(height: 16),
      _buildProductTable(d['by_product'] as List),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildTotals(Map<String, dynamic> t) {
    final pct = double.tryParse(t['scrap_percent'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(spacing: 20, runSpacing: 8, children: [
        _stat('Операций', '${t['operations']}', Colors.blueGrey),
        _stat('Взято', _num(t['from_total']?.toString()), Colors.brown),
        _stat('Получено', _num(t['to_total']?.toString()), Colors.green),
        _stat('Брак', _num(t['scrap_total']?.toString()), Colors.orange),
        _stat('% брака', '${t['scrap_percent']}%',
            pct > 3 ? Colors.red : Colors.green),
      ]),
    );
  }

  Widget _buildOperatorTable(List ops) {
    if (ops.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text('По операторам',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 42,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 44,
          headingRowColor:
              MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Оператор')),
            DataColumn(numeric: true, label: _Th('Операций')),
            DataColumn(numeric: true, label: _Th('Взято')),
            DataColumn(numeric: true, label: _Th('Получено')),
            DataColumn(numeric: true, label: _Th('Брак')),
            DataColumn(numeric: true, label: _Th('% брака')),
          ],
          rows: ops.map((o) {
            final m = o as Map<String, dynamic>;
            final pct = double.tryParse(m['scrap_percent'].toString()) ?? 0;
            return DataRow(cells: [
              DataCell(Text(m['operator'].toString(),
                  style:
                      const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${m['operations']}')),
              DataCell(Text(_num(m['from_total']?.toString()))),
              DataCell(Text(_num(m['to_total']?.toString()),
                  style: TextStyle(color: Colors.green.shade800))),
              DataCell(Text(_num(m['scrap_total']?.toString()),
                  style: TextStyle(color: Colors.orange.shade800))),
              DataCell(Text('${m['scrap_percent']}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: pct > 3
                          ? Colors.red
                          : Colors.green.shade700))),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildProductTable(List items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text('По артикулам',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 42,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 44,
          headingRowColor:
              MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: _Th('Артикул')),
            DataColumn(label: _Th('Наименование')),
            DataColumn(numeric: true, label: _Th('Взято')),
            DataColumn(numeric: true, label: _Th('Получено')),
            DataColumn(numeric: true, label: _Th('Брак')),
          ],
          rows: items.map((p) {
            final m = p as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(m['article'].toString(),
                  style:
                      const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(m['name'].toString(),
                    overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(_num(m['from_qty']?.toString()))),
              DataCell(Text(_num(m['to_qty']?.toString()),
                  style: TextStyle(color: Colors.green.shade800))),
              DataCell(Text(_num(m['scrap_qty']?.toString()),
                  style: TextStyle(color: Colors.orange.shade800))),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _stat(String label, String value, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ],
      );

  String _num(String? s) {
    if (s == null) return '—';
    final n = double.tryParse(s) ?? 0;
    if (n == 0) return '—';
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
