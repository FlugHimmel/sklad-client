import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../../services/products_repo.dart';
import '../../services/warehouses_repo.dart';
import '../scanner/scanner_screen.dart';

class ContainerDetailScreen extends StatefulWidget {
  final int containerId;
  const ContainerDetailScreen({super.key, required this.containerId});

  @override
  State<ContainerDetailScreen> createState() => _ContainerDetailScreenState();
}

class _ContainerDetailScreenState extends State<ContainerDetailScreen> {
  StockContainer? _container;
  bool _loading = true;
  String? _error;
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ContainersRepo get _repo => ContainersRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await _repo.get(widget.containerId);
      if (!mounted) return;
      setState(() => _container = c);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _dirty = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }



  Future<void> _ship() async {
    final c = _container!;
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отгрузка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Отгрузить тару ${c.code} — ${c.quantity} шт?'),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отгрузить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final resp = await _repo.ship(c.id, comment: commentCtrl.text.trim());
      _dirty = true;
      await _load();
      if (!mounted) return;
      if (resp['can_print_packing_list'] == true) {
        final print = await _confirm(
          'Печатать упаковочный лист?',
          yesLabel: 'Печатать',
          noLabel: 'Позже',
        );
        if (print == true) {
          await _printPackingList();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move() async {
    final warehouses = await WarehousesRepo(context.read<ApiClient>()).list();
    if (!mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Переместить на склад'),
        children: warehouses
            .map((w) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, w.id),
                  child: Text(w.name),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    await _run(() async => _repo.move(_container!.id, warehouseId: selected));
  }

  Future<void> _delete() async {
    if (_container == null) return;
    final c = _container!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить тару?'),
        content: Text(
          'Тара ${c.code} будет удалена.\n\n'
          'Все движения и события, связанные с ней, потеряют ссылку. '
          'Используйте только для ошибочно созданных тар.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(c.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: $e')),
      );
    }
  }

  Future<void> _printLabel() async {
    if (_container == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await _repo.labelPdf(_container!.id);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'label-${_container!.code}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка печати: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPackingList() async {
    if (_container == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await context
          .read<ApiClient>()
          .getBytes('/api/containers/${_container!.id}/packing-list-pdf/');
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-${_container!.code}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка печати: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String text,
      {String yesLabel = 'Да', String noLabel = 'Отмена'}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(noLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(yesLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _editLine(StockContainerLine line) async {
    final ctrl = TextEditingController(text: line.quantity);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${line.productArticle ?? ''} — ${line.productName ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сейчас в таре: ${line.quantity}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Новое количество',
                  border: OutlineInputBorder(),
                  helperText: 'Введи 0 — артикул уберётся из тары',
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final qty = result.trim().replaceAll(',', '.');
    if (qty.isEmpty) return;
    await _run(() async {
      await _repo.setLineQuantity(_container!.id, line.id, qty);
    });
  }

  Future<void> _removeLine(StockContainerLine line) async {
    final ok = await _confirm(
      'Убрать «${line.productArticle} — ${line.productName}» из тары?\n'
      '${line.quantity} шт уйдёт со склада.',
      yesLabel: 'Убрать',
    );
    if (ok != true) return;
    await _run(() async {
      await _repo.setLineQuantity(_container!.id, line.id, '0');
    });
  }

  Future<void> _transferLine(StockContainerLine line) async {
    final toCode = await _pickTransferTarget();
    if (toCode == null || toCode.isEmpty) return;

    final qtyCtrl = TextEditingController(text: line.quantity);
    final qty = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Переложить ${line.productArticle ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Сейчас в таре: ${line.quantity}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Куда: $toCode',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Сколько переложить',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, qtyCtrl.text),
            child: const Text('Переложить'),
          ),
        ],
      ),
    );
    if (qty == null) return;
    final q = qty.trim().replaceAll(',', '.');
    if (q.isEmpty) return;

    await _run(() async {
      await _repo.transferTo(
        _container!.id,
        toCode: toCode,
        lines: [
          {'product_id': line.product, 'quantity': q}
        ],
      );
    });
  }

  Future<String?> _pickTransferTarget() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Куда переложить'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Отсканируй или введи код тары-приёмника:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'TARA-XXXXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              onSubmitted: (v) => Navigator.pop(dialogCtx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Отмена'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final code = await Navigator.push<String>(
                dialogCtx,
                MaterialPageRoute(builder: (_) => const ScannerScreen()),
              );
              if (code != null && code.isNotEmpty && dialogCtx.mounted) {
                Navigator.pop(dialogCtx, code);
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Сканировать'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(dialogCtx, v);
            },
            child: const Text('ОК'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _addLine() async {
    final productsRepo = ProductsRepo(context.read<ApiClient>());
    final all = <Product>[];
    for (final t in ['casting', 'part']) {
      try {
        final list = await productsRepo.listByType(t);
        all.addAll(list);
      } catch (_) {}
    }
    if (!mounted) return;
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить артикулы')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddLineDialog(products: all),
    );
    if (result == null) return;
    await _run(() async {
      await _repo.addLine(
        _container!.id,
        result['product_id'] as int,
        result['quantity'] as String,
      );
    });
  }

  Widget _buildLinesSection(StockContainer c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Содержимое тары',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (c.isOnWarehouse || c.status == 'empty')
                  TextButton.icon(
                    onPressed: _busy ? null : _addLine,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (c.lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Тара пустая',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              _buildLinesTable(c),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesTable(StockContainer c) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.4),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const [
            _Th('Артикул'),
            _Th('Название'),
            _Th('Кол-во', align: TextAlign.right),
            _Th(''),
          ],
        ),
        ...c.lines.map(
          (l) => TableRow(
            children: [
              _Td(Text(l.productArticle ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              _Td(Text(l.productName ?? '—')),
              _Td(Text(l.quantity,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15))),
              _Td(Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Изменить количество',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _editLine(l),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    tooltip: 'Переложить в другую тару',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _transferLine(l),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Убрать из тары',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _removeLine(l),
                  ),
                ],
              )),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_container?.code ?? 'Тара'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Печать этикетки',
              onPressed: _container == null || _busy ? null : _printLabel,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Удалить тару',
              onPressed: _container == null || _busy ? null : _delete,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    final c = _container!;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.code,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Chip(label: Text(c.statusDisplay)),
                    const SizedBox(height: 8),
                    Text('${c.productArticle ?? "—"} · ${c.productName ?? ""}'),
                    Text('Всего: ${c.quantity}'),
                    if (c.warehouseName != null)
                      Text('Склад: ${c.warehouseName}'),
                    if (c.orderNumber != null) Text('Заказ: ${c.orderNumber}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLinesSection(c),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.isOnWarehouse) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _ship,
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Отгрузить'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _move,
                    icon: const Icon(Icons.move_down),
                    label: const Text('Переместить'),
                  ),
                ],

              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('История',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            if (c.events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Нет событий',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...c.events.map(
                (e) => ListTile(
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(e.eventTypeDisplay),
                  subtitle: Text(
                    '${e.productArticle ?? "—"} · ${e.quantity}\n'
                    '${e.comment.isNotEmpty ? "${e.comment}\n" : ""}'
                    '${e.createdAt?.toLocal().toString().substring(0, 19) ?? ""}'
                    '${e.createdByUsername != null ? " · ${e.createdByUsername}" : ""}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// =====================================================================
// Вспомогательные виджеты
// =====================================================================

class _Th extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _Th(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  final Widget child;
  const _Td(this.child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    );
  }
}

class _AddLineDialog extends StatefulWidget {
  final List<Product> products;
  const _AddLineDialog({required this.products});

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _qtyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Product? _selected;
  late List<Product> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.products.take(30).toList();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.products.take(30).toList();
      } else {
        _filtered = widget.products
            .where((p) =>
                p.article.toLowerCase().contains(query) ||
                p.name.toLowerCase().contains(query))
            .take(50)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить артикул в тару'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск по артикулу или названию',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Ничего не найдено'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final sel = _selected?.id == p.id;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor: Colors.blue.shade50,
                          title: Text('${p.article} — ${p.name}'),
                          onTap: () => setState(() => _selected = p),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Количество *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (_selected == null) return;
            final q = _qtyCtrl.text.trim().replaceAll(',', '.');
            if (q.isEmpty) return;
            Navigator.pop(context, {
              'product_id': _selected!.id,
              'quantity': q,
            });
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
