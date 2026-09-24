import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../../services/products_repo.dart';
import '../../services/warehouses_repo.dart';
import '../../widgets/product_search_field.dart';
import '../scanner/scanner_screen.dart';

// ---------------------------------------------------------------------------
// Черновик строки содержимого
// ---------------------------------------------------------------------------
class _LineDraft {
  int? productId;
  String? productArticle;
  String? productName;
  final TextEditingController qty = TextEditingController();
  _LineDraft();
  void dispose() => qty.dispose();
}

class _SessionEntry {
  final String code;
  final String summary;
  final String warehouse;
  final DateTime at;
  _SessionEntry({
    required this.code,
    required this.summary,
    required this.warehouse,
    required this.at,
  });
}

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------
class ContainerRevisionScreen extends StatefulWidget {
  const ContainerRevisionScreen({super.key});

  @override
  State<ContainerRevisionScreen> createState() =>
      _ContainerRevisionScreenState();
}

class _ContainerRevisionScreenState extends State<ContainerRevisionScreen> {
  StockContainer? _container;

  final Map<int, Product> _productsById = {};
  List<Product> _allProducts = [];

  List<Warehouse> _warehouses = [];
  int? _warehouseId;

  final List<_LineDraft> _lines = [];
  final List<_SessionEntry> _session = [];

  /// Упакована ли тара (готова к отгрузке).
  bool _packedField = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<ApiClient>();
      final prodRepo = ProductsRepo(api);
      final whRepo = WarehousesRepo(api);

      // ВАЖНО: последовательные await, без Future.wait —
      // на web в минифицированном JS Future.wait теряет generics.
      final castings = await prodRepo.listByType('casting');
      final parts = await prodRepo.listByType('part');
      final warehouses = await whRepo.list();

      final map = <int, Product>{};
      final all = <Product>[...castings, ...parts];
      for (final p in all) {
        map[p.id] = p;
      }
      all.sort((a, b) => a.article.compareTo(b.article));

      int? mainId;
      for (final w in warehouses) {
        if (w.code == 'MAIN') {
          mainId = w.id;
          break;
        }
      }
      mainId ??= warehouses.isNotEmpty ? warehouses.first.id : null;

      if (!mounted) return;
      setState(() {
        _productsById
          ..clear()
          ..addAll(map);
        _allProducts = all;
        _warehouses = warehouses;
        _warehouseId = mainId;
        _lines.add(_LineDraft());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Скан тары
  // -------------------------------------------------------------------------
  Future<void> _scanContainer() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    await _loadContainerByCode(code);
  }

  Future<void> _loadContainerByCode(String code) async {
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final c = await repo.byCode(code);
      if (!mounted) return;
      setState(() => _container = c);
      if (c.lines.isNotEmpty) {
        _snack('Тара ${c.code} уже не пустая. Возьми другую.');
      }
    } catch (e) {
      _snack('Тара не найдена: $code');
    }
  }

  // -------------------------------------------------------------------------
  // Строки
  // -------------------------------------------------------------------------
  void _addLine() {
    setState(() => _lines.add(_LineDraft()));
  }

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
      if (_lines.isEmpty) _lines.add(_LineDraft());
    });
  }

  double _d(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  int get _filledLineCount {
    return _lines
        .where((l) => l.productId != null && _d(l.qty.text) > 0)
        .length;
  }

  bool get _canSave {
    if (_container == null) return false;
    if (_container!.lines.isNotEmpty) return false;
    if (_warehouseId == null) return false;
    return _filledLineCount > 0;
  }

  String get _totalQty {
    final total = _lines.fold<double>(0, (a, l) => a + _d(l.qty.text));
    if (total == total.roundToDouble()) return total.toInt().toString();
    return total.toStringAsFixed(3);
  }

  // -------------------------------------------------------------------------
  // Сохранение
  // -------------------------------------------------------------------------
  Future<void> _save() async {
    if (!_canSave) return;

    final payloadLines = <Map<String, dynamic>>[];
    for (final l in _lines) {
      if (l.productId == null || _d(l.qty.text) <= 0) continue;
      payloadLines.add({
        'product_id': l.productId,
        'quantity': l.qty.text.trim(),
      });
    }
    if (payloadLines.isEmpty) {
      _snack('Нет ни одной заполненной строки');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final result = await repo.fill(
        _container!.id,
        lines: payloadLines,
        warehouseId: _warehouseId,
        packed: _packedField,
      );

      final summaryParts = <String>[];
      for (final l in _lines) {
        if (l.productId == null || _d(l.qty.text) <= 0) continue;
        summaryParts.add('${l.productArticle} × ${l.qty.text.trim()}');
      }
      final whName = _warehouses
          .firstWhere((w) => w.id == _warehouseId,
              orElse: () => _warehouses.first)
          .name;

      if (!mounted) return;
      setState(() {
        _session.insert(
          0,
          _SessionEntry(
            code: result.code,
            summary: summaryParts.join(', '),
            warehouse: whName,
            at: DateTime.now(),
          ),
        );
        _container = null;
        for (final l in _lines) {
          l.dispose();
        }
        _lines
          ..clear()
          ..add(_LineDraft());
        _packedField = false;
        _saving = false;
      });
      _snack('Тара ${result.code} заполнена ✓');
      _scanContainer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Ошибка: $e');
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ревизия: наполнить тару'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Что это?',
            onPressed: _showInfo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _scanBlock(),
                      const SizedBox(height: 12),
                      _warehouseBlock(),
                      const SizedBox(height: 8),
                      _packedSwitch(),
                      const SizedBox(height: 12),
                      _linesBlock(),
                      const SizedBox(height: 12),
                      _summaryBlock(),
                      const SizedBox(height: 100),
                      if (_session.isNotEmpty) _sessionBlock(),
                    ],
                  ),
                ),
      bottomNavigationBar: _saveBar(),
    );
  }

  Widget _scanBlock() {
    final c = _container;
    final isNotEmpty = c != null && c.lines.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNotEmpty
            ? Colors.red.shade50
            : (c == null ? Colors.orange.shade50 : Colors.green.shade50),
        border: Border.all(
          color: isNotEmpty
              ? Colors.red
              : (c == null ? Colors.orange : Colors.green),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isNotEmpty ? Icons.error : Icons.qr_code_scanner,
                color: isNotEmpty
                    ? Colors.red
                    : (c == null ? Colors.orange.shade800 : Colors.green),
              ),
              const SizedBox(width: 8),
              const Text('Тара',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (c == null)
                Text('не выбрана',
                    style: TextStyle(color: Colors.orange.shade800))
              else
                Text(c.code,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '⚠ Тара уже не пустая — возьми другую',
                style: TextStyle(
                    color: Colors.red.shade800, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _scanContainer,
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text('СКАНИРОВАТЬ ШК ТАРЫ',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warehouseBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonFormField<int>(
        initialValue: _warehouseId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Склад, где стоит тара',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _warehouses
            .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
            .toList(),
        onChanged: (v) => setState(() => _warehouseId = v),
      ),
    );
  }

  Widget _packedSwitch() {
    // Если склад RESERVE — упаковка не применима
    final whId = _warehouseId;
    final wh = _warehouses.firstWhere(
      (w) => w.id == whId,
      orElse: () => Warehouse(id: -1, name: '—', code: '—'),
    );
    final isMain = wh.code == 'MAIN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMain ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
          color: isMain ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: _packedField && isMain,
        onChanged: isMain
            ? (v) => setState(() => _packedField = v ?? false)
            : null,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          isMain
              ? 'Упакована — готова к отгрузке'
              : 'Упаковка только на основном складе',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isMain ? Colors.green.shade900 : Colors.grey.shade700,
          ),
        ),
        subtitle: Text(
          isMain
              ? 'Если тара уже замотана и готова — поставь галочку'
              : 'Выбери «Основной склад» чтобы включить',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _linesBlock() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          left: const BorderSide(color: Colors.blue, width: 4),
          top: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Что лежит в таре',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Артикул'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._lines.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            return _lineCard(d, i);
          }),
        ],
      ),
    );
  }

  Widget _lineCard(_LineDraft d, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ProductSearchField(
                  products: _allProducts,
                  value: d.productId,
                  label: 'Артикул',
                  hintText: 'Начни вводить артикул или название',
                  dense: true,
                  onChanged: (v) {
                    setState(() {
                      d.productId = v;
                      final p = v != null ? _productsById[v] : null;
                      d.productArticle = p?.article;
                      d.productName = p?.name;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              if (_lines.length > 1)
                IconButton(
                  onPressed: () => _removeLine(i),
                  icon: const Icon(Icons.close),
                  tooltip: 'Убрать',
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: d.qty,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Количество',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'шт',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _canSave ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
          color: _canSave ? Colors.green : Colors.grey.shade400,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Артикулов: $_filledLineCount   ·   Всего: $_totalQty шт',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (!_canSave)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _container == null
                    ? 'Сканируй ШК тары'
                    : (_container!.lines.isNotEmpty
                        ? 'Тара не пустая'
                        : 'Заполни хотя бы одну строку'),
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sessionBlock() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Заполнено в этой сессии: ${_session.length}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ..._session.take(20).map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${s.code} · ${s.summary} · ${s.warehouse}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: (_canSave && !_saving) ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(
              _saving ? 'СОХРАНЯЮ...' : 'СОХРАНИТЬ И СЛЕДУЮЩАЯ',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Что такое ревизия?'),
        content: const SingleChildScrollView(
          child: Text(
            'Быстрый занос того, что физически стоит в цеху.\n\n'
            '1. Сканируешь ШК на болванке\n'
            '2. Вводишь что в ней лежит (можно несколько артикулов)\n'
            '3. Указываешь склад (основной / задел)\n'
            '4. Сохранить — и сразу скан следующей\n\n'
            'Внизу видно сколько уже занёс за сессию.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
