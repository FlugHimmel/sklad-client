import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/reports_repo.dart';
import '../../utils/csv_export.dart';
import '../../widgets/stale_banner.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({super.key});
  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  List<MonthlySummary> _months = [];
  bool _loading = true;
  String? _error;
  int _selectedIdx = 0;
  String _search = '';
  bool _showChildren = false;

  final _headerCtrl = ScrollController();
  final _bodyHCtrl = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _bodyHCtrl.addListener(_syncHeader);
    _load();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _bodyHCtrl.dispose();
    super.dispose();
  }

  void _syncHeader() {
    if (_syncing) return;
    if (!_headerCtrl.hasClients || !_bodyHCtrl.hasClients) return;
    if (_headerCtrl.offset == _bodyHCtrl.offset) return;
    _syncing = true;
    _headerCtrl.jumpTo(_bodyHCtrl.offset);
    _syncing = false;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ReportsRepo(context.read<ApiClient>())
          .monthlySummary(months: 12);
      if (!mounted) return;
      final reversed = list.reversed.toList();
      setState(() {
        _months = reversed;
        if (_selectedIdx >= _months.length) _selectedIdx = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MonthlySummary? get _current =>
      _months.isEmpty ? null : _months[_selectedIdx];

  List<CastingRow> _filteredCastings(MonthlySummary m) {
    var list = m.castings;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.article.toLowerCase().contains(q) ||
          r.name.toLowerCase().contains(q) ||
          r.children.any((c) =>
              c.article.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q))).toList();
    }
    return list;
  }

  void _exportCsv() {
    final m = _current;
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных')));
      return;
    }
    final rows = _filteredCastings(m);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нечего экспортировать')));
      return;
    }
    CsvExporter.export(
      filename: 'summary_${m.year}_${m.month.toString().padLeft(2, '0')}.csv',
      headers: const [
        'Артикул', 'Наименование',
        'Литьё, шт (сейчас)', 'Деталей, шт (сейчас)',
        'В МО за месяц', 'Сделано за месяц',
        'Отгружено за месяц', 'Брак за месяц',
      ],
      rows: rows.map((r) => [
        r.article,
        r.name,
        CsvExporter.numStr(r.balanceEnd),
        CsvExporter.numStr(r.partsBalanceEnd),
        CsvExporter.numStr(r.produceOut),
        CsvExporter.numStr(r.partsProduced),
        CsvExporter.numStr(r.partsShipped),
        CsvExporter.numStr(r.partsScrap),
      ]).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Экспортировано: ${rows.length} строк за ${m.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сводная таблица'),
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
        _buildMonthChips(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            FilterChip(
              label: const Text('Показать расшифровку по деталям'),
              selected: _showChildren,
              onSelected: (v) => setState(() => _showChildren = v),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildMonthChips() {
    if (_months.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _months.length,
        itemBuilder: (_, i) {
          final m = _months[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(m.label),
              selected: _selectedIdx == i,
              onSelected: (_) => setState(() => _selectedIdx = i),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    final m = _current;
    if (m == null) return const Center(child: Text('Нет данных'));
    final rows = _filteredCastings(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMonthHeader(m),
        Expanded(child: _buildTable(rows)),
      ],
    );
  }

  Widget _buildMonthHeader(MonthlySummary m) {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${m.label} — обороты за месяц',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Wrap(spacing: 18, runSpacing: 2, children: [
            _stat('Сделано деталей', m.totals['produced'] ?? '0', Colors.green),
            _stat('В работу (в МО)', m.totals['produce_out'] ?? '0', Colors.brown),
            _stat('Отгружено', m.totals['shipped'] ?? '0', Colors.indigo),
            _stat('Брак', m.totals['scrap'] ?? '0', Colors.orange),
          ]),
        ],
      ),
    );
  }

  // ─── ТАБЛИЦА ────────────────────────────────────────────────
  static const double _cwArticle = 100;
  static const double _cwName = 220;
  static const double _cwNum = 95;
  static const double _cwLast = 110;

  // 5 колонок: артикул, наименование, литьё сейчас, деталей сейчас, в МО, сделано, отгр, брак = 2 + 6
  double get _totalWidth =>
      _cwArticle + _cwName + _cwNum * 6 + _cwLast + 40;

  Widget _buildTable(List<CastingRow> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Нет данных за этот месяц',
            style: TextStyle(color: Colors.grey))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.grey.shade200,
          child: SingleChildScrollView(
            controller: _headerCtrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: _buildHeaderRow(),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Colors.black26),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              controller: _bodyHCtrl,
              scrollDirection: Axis.horizontal,
              child: _buildBodyRows(rows),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      width: _totalWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _th('Артикул', _cwArticle),
          _th('Наименование', _cwName),
          _thNum('Литьё\nсейчас', _cwNum),
          _thNum('Деталей\nсейчас', _cwLast),
          _thNum('В МО', _cwNum),
          _thNum('Сделано', _cwNum),
          _thNum('Отгружено', _cwNum),
          _thNum('Брак', _cwNum),
        ],
      ),
    );
  }

  Widget _buildBodyRows(List<CastingRow> rows) {
    final children = <Widget>[];
    final searching = _search.isNotEmpty;
    for (final r in rows) {
      children.add(_buildDataRow(r));
      // SEARCH-CHILDREN: при активном поиске раскрываем детей,
      // иначе непонятно, почему отливка попала в результат
      // (матч может быть по артикулу ребёнка).
      if ((_showChildren || searching) && r.children.isNotEmpty) {
        for (final ch in r.children) {
          children.add(_buildChildRow(ch));
        }
      }
    }
    return Container(
      width: _totalWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildDataRow(CastingRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _td(r.article, _cwArticle, bold: true),
          _td(r.name, _cwName, ellipsis: true),
          _tdNum(r.balanceEnd, _cwNum, bold: true, color: Colors.black87),
          _tdNum(r.partsBalanceEnd, _cwLast, bold: true, color: Colors.black87),
          _tdNum(r.produceOut, _cwNum, color: Colors.brown),
          _tdNum(r.partsProduced, _cwNum, color: Colors.green, bold: true),
          _tdNum(r.partsShipped, _cwNum, color: Colors.indigo),
          _tdNum(r.partsScrap, _cwNum, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildChildRow(CastingChildRow ch) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              width: _cwArticle - 16,
              child: Text('↳ ${ch.article}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ),
          ),
          _td(ch.name, _cwName, ellipsis: true, small: true),
          const SizedBox(width: _cwNum,
              child: Text('—', textAlign: TextAlign.center)),
          _tdNum(ch.balanceEnd, _cwLast, small: true),
          const SizedBox(width: _cwNum,
              child: Text('—', textAlign: TextAlign.center)),
          _tdNum(ch.produced, _cwNum, color: Colors.green, small: true),
          _tdNum(ch.shipped, _cwNum, color: Colors.indigo, small: true),
          _tdNum(ch.scrap, _cwNum, color: Colors.orange, small: true),
        ],
      ),
    );
  }

  Widget _th(String text, double w) => SizedBox(
        width: w,
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _thNum(String text, double w) => SizedBox(
        width: w,
        child: Text(text,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _td(String text, double w,
          {bool bold = false, bool ellipsis = false, bool small = false}) =>
      SizedBox(
        width: w,
        child: Text(text,
            overflow: ellipsis ? TextOverflow.ellipsis : null,
            style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      );

  Widget _tdNum(String s, double w,
      {Color? color, bool bold = false, bool small = false}) {
    final n = double.tryParse(s) ?? 0;
    final text = n == 0
        ? '—'
        : (n == n.roundToDouble()
            ? n.toStringAsFixed(0)
            : n.toStringAsFixed(2));
    return SizedBox(
      width: w,
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(
              fontSize: small ? 12 : 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _stat(String label, String value, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: color, fontSize: 12)),
        Text(value,
            style: TextStyle(color: color,
                fontWeight: FontWeight.bold, fontSize: 12)),
      ]);
}
