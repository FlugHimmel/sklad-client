import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../models/operation.dart';
import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/operations_repo.dart';
import '../../services/products_repo.dart';
import '../scanner/scanner_screen.dart';

// ---------------------------------------------------------------------------
// Строки-черновики
// ---------------------------------------------------------------------------
class _FromDraft {
  StockContainer? container;
  int? productId;
  String? productArticle;
  String? productName;
  String? productType;
  List<int> moIds = [];
  final TextEditingController qty = TextEditingController();
  _FromDraft();
  void dispose() => qty.dispose();

  double get availableQty {
    if (container == null) return 0;
    double sum = 0;
    for (final l in container!.lines) {
      if (productId == null || l.product == productId) {
        sum += double.tryParse(l.quantity) ?? 0;
      }
    }
    return sum;
  }
}

class _ToDraft {
  StockContainer? container;
  int? productId;
  String? productArticle;
  String? productName;
  final TextEditingController qty = TextEditingController();
  _ToDraft();
  void dispose() => qty.dispose();
}

class _ScrapDraft {
  final Map<String, TextEditingController> qtyByReason = {};
  _ScrapDraft(List<ScrapReasonItem> reasons) {
    for (final r in reasons) {
      qtyByReason[r.value] = TextEditingController();
    }
  }
  void dispose() {
    for (final c in qtyByReason.values) {
      c.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Форма
// ---------------------------------------------------------------------------
class OperationFormScreen extends StatefulWidget {
  final StockContainer? sourceContainer;
  const OperationFormScreen({super.key, this.sourceContainer});

  @override
  State<OperationFormScreen> createState() => _OperationFormScreenState();
}

class _OperationFormScreenState extends State<OperationFormScreen> {
  final _comment = TextEditingController();

  String? _type;
  OperationMeta? _meta;

  final List<_FromDraft> _from = [];
  final List<_ToDraft> _to = [];
  _ScrapDraft? _scrap;

  StockContainer? _returnContainer;

  final Map<int, Product> _productsById = {};

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
    for (final d in _from) {
      d.dispose();
    }
    for (final d in _to) {
      d.dispose();
    }
    _scrap?.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<ApiClient>();
      final metaRepo = OperationsRepo(api);
      final prodRepo = ProductsRepo(api);

      final results = await Future.wait([
        metaRepo.meta(),
        prodRepo.listByType('casting'),
        prodRepo.listByType('part'),
      ]);

      final meta = results[0] as OperationMeta;
      final castings = results[1] as List<Product>;
      final parts = results[2] as List<Product>;

      _productsById.clear();
      for (final p in castings) {
        _productsById[p.id] = p;
      }
      for (final p in parts) {
        _productsById[p.id] = p;
      }

      _meta = meta;
      _scrap = _ScrapDraft(meta.scrapReasons);
      _type = meta.operationTypes.isNotEmpty
          ? meta.operationTypes.first.value
          : 'other';

      if (widget.sourceContainer != null) {
        _addFromFromContainer(widget.sourceContainer!);
      } else {
        _from.add(_FromDraft());
      }
      _to.add(_ToDraft());
      _listenBalance();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _listenBalance() {
    for (final d in _from) {
      d.qty.addListener(_rebuild);
    }
    for (final d in _to) {
      d.qty.addListener(_rebuild);
    }
    for (final c in _scrap?.qtyByReason.values ?? <TextEditingController>[]) {
      c.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _addFromFromContainer(StockContainer c) {
    final d = _FromDraft();
    d.container = c;
    if (c.lines.isNotEmpty) {
      final l = c.lines.first;
      d.productId = l.product;
      d.productArticle = l.productArticle;
      d.productName = l.productName;
      d.productType = l.productType;
      if (l.productType == 'casting' && l.product != null) {
        final src = _productsById[l.product!];
        d.moIds = src?.moIds ?? [];
      }
      if (c.lines.length == 1) {
        d.qty.text = _fmtDouble(double.tryParse(l.quantity) ?? 0);
      }
    }
    _from.add(d);
    _listenBalance();
  }

  void _addFromBlank() {
    setState(() {
      _from.add(_FromDraft());
      _listenBalance();
    });
  }

  void _addTo() {
    setState(() {
      final d = _ToDraft();
      final opts = _partOptionsForTo();
      if (opts.isNotEmpty && opts.first.value != null) {
        d.productId = opts.first.value;
        final p = _productsById[d.productId!];
        d.productArticle = p?.article;
        d.productName = p?.name;
      }
      _to.add(d);
      _listenBalance();
    });
  }

  void _removeFrom(int i) {
    setState(() {
      _from[i].dispose();
      _from.removeAt(i);
      _returnContainer = null;
    });
  }

  void _removeTo(int i) {
    setState(() {
      _to[i].dispose();
      _to.removeAt(i);
    });
  }

  Future<void> _scanContainer({_FromDraft? from, _ToDraft? to}) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final api = context.read<ApiClient>();
      final j =
          await api.get('/api/containers/by-code/', query: {'code': code});
      final c = StockContainer.fromJson(j as Map<String, dynamic>);
      setState(() {
        if (from != null) {
          _applyContainerToFrom(from, c);
        } else if (to != null) {
          to.container = c;
        }
      });
    } catch (e) {
      _snack('Не удалось открыть тару: $e');
    }
  }

  void _applyContainerToFrom(_FromDraft d, StockContainer c) {
    d.container = c;
    if (c.lines.isEmpty) return;
    final l = c.lines.first;
    d.productId = l.product;
    d.productArticle = l.productArticle;
    d.productName = l.productName;
    d.productType = l.productType;
    d.moIds = [];
    if (l.productType == 'casting' && l.product != null) {
      final src = _productsById[l.product!];
      d.moIds = src?.moIds ?? [];
    }
    if (c.lines.length == 1) {
      d.qty.text = _fmtDouble(double.tryParse(l.quantity) ?? 0);
    }
  }

  Future<void> _pickContainerForFrom(_FromDraft d) async {
    final c = await _pickContainerDialog();
    if (c == null) return;
    setState(() => _applyContainerToFrom(d, c));
  }

  Future<void> _pickContainerForTo(_ToDraft d) async {
    final c = await _pickContainerDialog();
    if (c == null) return;
    setState(() => d.container = c);
  }

  Future<void> _pickReturnContainer() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Куда вернуть остаток?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'scan'),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner),
                SizedBox(width: 12),
                Text('Сканировать тару'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'list'),
            child: const Row(
              children: [
                Icon(Icons.list),
                SizedBox(width: 12),
                Text('Выбрать из списка'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: const Row(
              children: [
                Icon(Icons.undo),
                SizedBox(width: 12),
                Text('Сбросить (в последний источник)'),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'scan') {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );
      if (code == null || code.isEmpty || !mounted) return;
      try {
        final api = context.read<ApiClient>();
        final j =
            await api.get('/api/containers/by-code/', query: {'code': code});
        final c = StockContainer.fromJson(j as Map<String, dynamic>);
        setState(() => _returnContainer = c);
      } catch (e) {
        _snack('Не удалось открыть тару: $e');
      }
    } else if (choice == 'list') {
      final c = await _pickContainerDialog();
      if (c != null) setState(() => _returnContainer = c);
    } else if (choice == 'reset') {
      setState(() => _returnContainer = null);
    }
  }

  Future<StockContainer?> _pickContainerDialog() async {
    try {
      final api = context.read<ApiClient>();
      final resp = await api.get('/api/containers/');
      final List raw;
      if (resp is Map && resp['results'] != null) {
        raw = resp['results'] as List;
      } else if (resp is List) {
        raw = resp;
      } else {
        raw = const [];
      }
      final list = raw
          .map((e) => StockContainer.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return null;
      return showDialog<StockContainer>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Выбери тару'),
          children: [
            SizedBox(
              width: 520,
              height: 460,
              child: ListView(
                children: list.map((c) {
                  final sub = c.lines.isEmpty
                      ? 'пустая'
                      : c.lines
                          .map((l) =>
                              '${l.productArticle ?? ''} ${l.quantity} шт')
                          .join(', ');
                  return ListTile(
                    dense: true,
                    title: Text(c.code),
                    subtitle: Text(sub, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, c),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _snack('Ошибка загрузки тар: $e');
      return null;
    }
  }

  double _d(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  double get _sumFrom => _from.fold(0.0, (acc, d) => acc + _d(d.qty.text));
  double get _sumTo => _to.fold(0.0, (acc, d) => acc + _d(d.qty.text));
  double get _sumScrap {
    if (_scrap == null) return 0;
    return _scrap!.qtyByReason.values
        .fold(0.0, (acc, c) => acc + _d(c.text));
  }

  double get _returnQty {
    final v = _sumFrom - _sumTo - _sumScrap;
    return v > 0.001 ? v : 0;
  }

  StockContainer? get _effectiveReturnContainer {
    if (_returnContainer != null) return _returnContainer;
    for (int i = _from.length - 1; i >= 0; i--) {
      if (_from[i].container != null) return _from[i].container;
    }
    return null;
  }

  bool get _fromExceeds {
    for (final d in _from) {
      if (d.container == null) continue;
      if (_d(d.qty.text) > d.availableQty + 0.0001) return true;
    }
    return false;
  }

  /// Возвращает Set индексов _to, которые дублируют другую строку (та же тара + артикул)
  Set<int> get _duplicateToIndices {
    final seen = <String, int>{};
    final dups = <int>{};
    for (int i = 0; i < _to.length; i++) {
      final d = _to[i];
      if (d.container == null || d.productId == null) continue;
      final key = '${d.container!.id}:${d.productId}';
      if (seen.containsKey(key)) {
        dups.add(i);
        dups.add(seen[key]!);
      } else {
        seen[key] = i;
      }
    }
    return dups;
  }

  bool get _hasDuplicateTo => _duplicateToIndices.isNotEmpty;

  bool get _balanced {
    if (_from.isEmpty || _to.isEmpty) return false;
    if (_fromExceeds) return false;
    if (_hasDuplicateTo) return false;
    final diff = _sumFrom - _sumTo - _sumScrap;
    if (diff > 0.001) {
      return _effectiveReturnContainer != null;
    }
    if (diff < -0.001) return false;
    return true;
  }

  String _fmt(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(3);
  }

  String _fmtDouble(double n) => _fmt(n);

  List<DropdownMenuItem<int?>> _partOptionsForTo() {
    _FromDraft? src;
    for (final f in _from) {
      if (f.productId != null) {
        src = f;
        break;
      }
    }
    if (src == null) {
      return const [
        DropdownMenuItem(
            value: null, child: Text('— сначала выбери источник —')),
      ];
    }
    final res = <DropdownMenuItem<int?>>[];
    final seen = <int>{};

    for (final mid in src.moIds) {
      final p = _productsById[mid];
      if (p == null || seen.contains(p.id)) continue;
      seen.add(p.id);
      res.add(DropdownMenuItem(
        value: p.id,
        child: Text(
          '${p.article} · ${p.name}',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    final srcProduct = _productsById[src.productId!];
    if (srcProduct != null && !seen.contains(srcProduct.id)) {
      res.add(DropdownMenuItem(
        value: srcProduct.id,
        child: Text(
          '${srcProduct.article} · ${srcProduct.name} (тот же)',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    if (res.isEmpty) {
      res.add(const DropdownMenuItem(
        value: null,
        child: Text('Нет доступных деталей'),
      ));
    }
    return res;
  }

  Future<void> _save() async {
    if (_hasDuplicateTo) {
      _snack('В блоке «Получил» одна тара указана дважды. Убери дубликат.');
      return;
    }
    if (!_balanced) {
      _snack('Баланс не сходится или превышено количество в таре');
      return;
    }
    final fromList = <Map<String, dynamic>>[];
    for (final d in _from) {
      if (d.container == null || d.productId == null || _d(d.qty.text) <= 0) {
        _snack('Заполни все строки «Взял»');
        return;
      }
      fromList.add({
        'container_id': d.container!.id,
        'product_id': d.productId,
        'qty': d.qty.text.trim(),
      });
    }
    final toList = <Map<String, dynamic>>[];
    for (final d in _to) {
      if (d.container == null || d.productId == null || _d(d.qty.text) <= 0) {
        _snack('Заполни все строки «Получил»');
        return;
      }
      toList.add({
        'container_id': d.container!.id,
        'product_id': d.productId,
        'qty': d.qty.text.trim(),
      });
    }

    if (_returnQty > 0.001) {
      final rc = _effectiveReturnContainer!;
      toList.add({
        'container_id': rc.id,
        'product_id': _from.first.productId,
        'qty': _fmt(_returnQty),
      });
    }

    final scrapList = <Map<String, dynamic>>[];
    for (final entry in _scrap!.qtyByReason.entries) {
      final v = _d(entry.value.text);
      if (v <= 0) continue;
      scrapList.add({
        'product_id': _from.first.productId,
        'qty': entry.value.text.trim(),
        'reason': entry.key,
      });
    }

    setState(() => _saving = true);
    try {
      final repo = OperationsRepo(context.read<ApiClient>());
      await repo.create(
        operationType: _type!,
        from: fromList,
        to: toList,
        scrap: scrapList,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;

      // Если операция — упаковка, предлагаем напечатать упаковочные листы
      if (_type == 'packing') {
        final toIds = _to
            .where((d) => d.container != null && d.productId != null)
            .map((d) => d.container!.id)
            .toList();
        if (toIds.isNotEmpty && mounted) {
          await _askPrintPacking(toIds);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Ошибка: $e');
    }
  }

  /// После операции упаковки — предложить напечатать упаковочные листы.
  Future<void> _askPrintPacking(List<int> toIds) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Упаковано ✓'),
        content: Text(
          'Тары готовы к отгрузке.\n'
          'Напечатать упаковочные листы (A4, ${toIds.length} шт)?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Пропустить'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Напечатать'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      final bytes = await context
          .read<ApiClient>()
          .postBytes('/api/containers/bulk-packing-pdf/', body: {'ids': toIds});
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-bulk.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая операция'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton(
              onPressed: (_balanced && !_saving) ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ЗАПИСАТЬ'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _typeSelector(),
                      const SizedBox(height: 12),
                      _fromBlock(),
                      const SizedBox(height: 12),
                      _toBlock(),
                      const SizedBox(height: 12),
                      _returnBlock(),
                      const SizedBox(height: 12),
                      _scrapBlock(),
                      const SizedBox(height: 12),
                      _commentBlock(),
                      const SizedBox(height: 12),
                      _balance(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _typeSelector() {
    return DropdownButtonFormField<String>(
      value: _type,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Тип операции',
        border: OutlineInputBorder(),
      ),
      items: _meta!.operationTypes
          .map((t) =>
              DropdownMenuItem(value: t.value, child: Text(t.label)))
          .toList(),
      onChanged: (v) => setState(() => _type = v),
    );
  }

  Widget _fromBlock() {
    return _section(
      title: 'Взял',
      color: Colors.orange,
      onAdd: _addFromBlank,
      addLabel: '+ Источник',
      children: _from.asMap().entries.map((e) {
        final i = e.key;
        final d = e.value;
        final avail = d.availableQty;
        final entered = _d(d.qty.text);
        final exceeds = entered > avail + 0.0001;
        return _rowCard(
          onRemove: _from.length > 1 ? () => _removeFrom(i) : null,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scanContainer(from: d),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(
                      d.container?.code ?? 'Скан / выбрать тару',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _pickContainerForFrom(d),
                  icon: const Icon(Icons.list),
                  tooltip: 'Из списка',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (d.productArticle != null)
              Text(
                '${d.productArticle} · ${d.productName ?? ""}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            if (d.container != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'В таре: ${_fmt(avail)} шт',
                  style: TextStyle(
                    fontSize: 12,
                    color: exceeds ? Colors.red : Colors.black54,
                    fontWeight:
                        exceeds ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: d.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Взял, шт',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: exceeds ? 'Больше, чем есть в таре' : null,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _toBlock() {
    final opts = _partOptionsForTo();
    final dups = _duplicateToIndices;
    return _section(
      title: 'Получил',
      color: Colors.green,
      onAdd: _addTo,
      addLabel: '+ Приёмник',
      children: [
        ..._to.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final isDup = dups.contains(i);
          return _rowCard(
            onRemove: _to.length > 1 ? () => _removeTo(i) : null,
            isError: isDup,
            children: [
              DropdownButtonFormField<int?>(
                value: d.productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Что сделал',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: opts,
                onChanged: (v) {
                  setState(() {
                    d.productId = v;
                    final p = v != null ? _productsById[v] : null;
                    d.productArticle = p?.article;
                    d.productName = p?.name;
                  });
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanContainer(to: d),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(
                        d.container?.code ?? 'Скан / выбрать тару',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _pickContainerForTo(d),
                    icon: const Icon(Icons.list),
                    tooltip: 'Из списка',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: d.qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Получил, шт',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: isDup
                      ? 'Эта тара уже указана выше — сложи количества'
                      : null,
                ),
              ),
            ],
          );
        }),
        if (dups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Одна тара указана дважды. Если нужно положить в одну — '
                      'сложи количества и оставь одну строку. '
                      'Если в разные — выбери разные тары.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _returnBlock() {
    if (_returnQty <= 0.001) return const SizedBox.shrink();
    final rc = _effectiveReturnContainer;
    final defaulted = _returnContainer == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade300, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.undo, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Вернётся в тару: ${_fmt(_returnQty)} шт',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  rc?.code ?? '—',
                  style: const TextStyle(fontSize: 14),
                ),
                if (defaulted)
                  const Text(
                    '(по умолчанию — последний источник)',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickReturnContainer,
            child: const Text('изменить'),
          ),
        ],
      ),
    );
  }

  Widget _scrapBlock() {
    if (_scrap == null) return const SizedBox.shrink();
    return _section(
      title: 'Брак',
      color: Colors.red,
      children: _meta!.scrapReasons
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(r.label)),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _scrap!.qtyByReason[r.value],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _commentBlock() {
    return _section(
      title: 'Комментарий',
      color: Colors.blueGrey,
      children: [
        TextField(
          controller: _comment,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Необязательно',
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _balance() {
    final ok = _balanced;
    final diff = _sumFrom - _sumTo - _sumScrap;
    final message = ok
        ? 'Баланс сходится'
        : _hasDuplicateTo
            ? 'Одна тара в «Получил» указана дважды'
            : _fromExceeds
                ? 'Взял больше, чем есть в таре'
                : diff < -0.001
                    ? 'Положил больше, чем взял: ${_fmt(-diff)}'
                    : 'Заполни «Взял» и «Получил»';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: ok ? Colors.green : Colors.red,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Взято: ${_fmt(_sumFrom)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            'Получено: ${_fmt(_sumTo)}   Брак: ${_fmt(_sumScrap)}   '
            'Возврат: ${_fmt(_returnQty)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Divider(),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ok ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Color color,
    required List<Widget> children,
    VoidCallback? onAdd,
    String? addLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 4),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(addLabel ?? 'Добавить'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _rowCard({
    required List<Widget> children,
    VoidCallback? onRemove,
    bool isError = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red : Colors.grey.shade300,
          width: isError ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onRemove != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Убрать',
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
