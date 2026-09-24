import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/reports_repo.dart';
import '../../utils/csv_export.dart';

class ReadyToShipReportScreen extends StatefulWidget {
  const ReadyToShipReportScreen({super.key});
  @override
  State<ReadyToShipReportScreen> createState() =>
      _ReadyToShipReportScreenState();
}

class _ReadyToShipReportScreenState extends State<ReadyToShipReportScreen> {
  ReadyToShipResult? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  String _category = 'all'; // all | wheels | components
  final Set<int> _expanded = {};

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
      final res = await ReportsRepo(context.read<ApiClient>())
          .readyToShip(search: _search, category: _category);
      if (!mounted) return;
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtNum(String s, {int decimals = 0}) {
    final n = double.tryParse(s) ?? 0;
    if (decimals == 0) {
      if (n == n.roundToDouble()) return n.toInt().toString();
      return n.toStringAsFixed(2);
    }
    return n.toStringAsFixed(decimals);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}';
  }

  Widget _catChip(String label, String value, {Color? color}) {
    final selected = _category == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color?.withOpacity(0.25),
      checkmarkColor: color,
      onSelected: (_) {
        setState(() => _category = value);
        _load();
      },
    );
  }

  void _exportCsv() {
    final d = _data;
    if (d == null || d.rows.isEmpty) return;
    CsvExporter.export(
      filename: 'ready_to_ship_${CsvExporter.today()}.csv',
      headers: const [
        'Артикул', 'Наименование', 'Мест', 'Кол-во',
        'Вес нетто, кг', 'Вес брутто, кг',
      ],
      rows: [
        ...d.rows.map((r) => [
          r.article,
          r.name,
          '${r.places}',
          CsvExporter.numStr(r.totalQty),
          CsvExporter.numStr(r.nettoKg),
          CsvExporter.numStr(r.bruttoKg),
        ]),
        [], // пустая
        [
          'ИТОГО', '', '${d.totals.places}',
          CsvExporter.numStr(d.totals.qty),
          CsvExporter.numStr(d.totals.nettoKg),
          CsvExporter.numStr(d.totals.bruttoKg),
        ],
      ],
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${d.rows.length} строк')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text('Готово к отгрузке (${d?.count ?? 0})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Экспорт CSV',
            onPressed: (d != null && d.rows.isNotEmpty) ? _exportCsv : null,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск: артикул, наименование, тара',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => _load(),
          ),
        ),
        // Категория
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            _catChip('Все', 'all'),
            const SizedBox(width: 6),
            _catChip('Рабочие колёса', 'wheels', color: Colors.indigo),
            const SizedBox(width: 6),
            _catChip('Компоненты', 'components', color: Colors.teal),
          ]),
        ),
        if (d != null && d.rows.isNotEmpty) _buildTotalsBar(d.totals),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildTotalsBar(ReadyToShipTotals t) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(spacing: 20, runSpacing: 4, children: [
        _stat('Мест', '${t.places}', Colors.green.shade800),
        _stat('Кол-во', _fmtNum(t.qty), Colors.blueGrey.shade800),
        _stat('Нетто', '${_fmtNum(t.nettoKg, decimals: 1)} кг',
            Colors.blue.shade800),
        _stat('Брутто', '${_fmtNum(t.bruttoKg, decimals: 1)} кг',
            Colors.deepOrange.shade800),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: ',
          style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w600)),
      Text(value,
          style: TextStyle(color: color, fontSize: 15,
              fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    final d = _data;
    if (d == null || d.rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Пока ничего не упаковано',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Сделай операцию «Упаковка»,\n'
              'чтобы тары попали сюда',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: d.rows.length,
      itemBuilder: (_, i) => _buildProductRow(d.rows[i]),
    );
  }

  Widget _buildProductRow(ReadyToShipProductRow r) {
    final isExpanded = _expanded.contains(r.productId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expanded.remove(r.productId);
            } else {
              _expanded.add(r.productId);
            }
          }),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Строка 1: артикул + наименование
                Row(children: [
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.article,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold,
                                fontFamily: 'monospace')),
                        Text(r.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // Строка 2: метрики таблицей
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Table(
                    border: TableBorder.all(
                        color: Colors.grey.shade300, width: 0.5),
                    columnWidths: const {
                      0: FlexColumnWidth(0.9),
                      1: FlexColumnWidth(1.1),
                      2: FlexColumnWidth(1.1),
                      3: FlexColumnWidth(1.2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100),
                        children: [
                          _th('Мест'),
                          _th('Кол-во, шт'),
                          _th('Нетто, кг'),
                          _th('Брутто, кг'),
                        ],
                      ),
                      TableRow(children: [
                        _td('${r.places}', bold: true,
                            color: Colors.teal.shade800),
                        _td(_fmtNum(r.totalQty)),
                        _td(_fmtNum(r.nettoKg, decimals: 1),
                            color: Colors.blue.shade800),
                        _td(_fmtNum(r.bruttoKg, decimals: 1), bold: true,
                            color: Colors.deepOrange.shade800),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Раскрытие: список тар
        if (isExpanded)
          Container(
            width: double.infinity,
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Тары:',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...r.containers.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Icon(Icons.qr_code, size: 12,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(c.containerCode,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text('${_fmtNum(c.quantity)} шт',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Text('${_fmtNum(c.nettoKg, decimals: 1)} кг',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700)),
                        const SizedBox(width: 8),
                        Text(_fmtDate(c.packedAt),
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700)),
                      ]),
                    )),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _td(String t, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            )),
      );
}
