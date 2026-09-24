import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/inventory_repo.dart';

class InventoryDetailScreen extends StatefulWidget {
  final int inventoryId;
  const InventoryDetailScreen({super.key, required this.inventoryId});
  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  Inventory? _inv;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  final Map<int, TextEditingController> _ctrls = {};

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  InventoryRepo get _repo => InventoryRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final inv = await _repo.get(widget.inventoryId);
      for (final c in _ctrls.values) { c.dispose(); }
      _ctrls.clear();
      for (final ln in inv.lines) {
        _ctrls[ln.id] = TextEditingController(text: _fmtNum(ln.quantityFact));
      }
      if (!mounted) return;
      setState(() => _inv = inv);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtNum(String s) {
    final n = double.tryParse(s) ?? 0;
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(3);
  }

  Future<void> _saveLine(InventoryLine ln) async {
    final ctrl = _ctrls[ln.id];
    if (ctrl == null) return;
    final val = ctrl.text.trim().replaceAll(',', '.');
    try {
      await _repo.setLine(widget.inventoryId, ln.id, quantityFact: val);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  Future<void> _saveAll() async {
    setState(() => _busy = true);
    try {
      for (final ln in _inv!.lines) {
        await _saveLine(ln);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final inv = _inv!;
    final diffCount = inv.lines.where((l) {
      final ctrl = _ctrls[l.id];
      if (ctrl == null) return false;
      final fact = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0;
      final theory = double.tryParse(l.quantityTheory) ?? 0;
      return (fact - theory).abs() > 0.0001;
    }).length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Применить инвентаризацию?'),
        content: Text(
          'По складу «${inv.warehouseName}» будет создано движений: $diffCount.\n'
          'Остатки обновятся по факту. Отменить потом нельзя.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      for (final ln in inv.lines) {
        await _saveLine(ln);
      }
      final resp = await _repo.apply(widget.inventoryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Применено. Строк изменено: ${resp['lines_adjusted']}')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить инвентаризацию?'),
        content: const Text('Изменения не будут применены. Остатки не поменяются.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Нет')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancel(widget.inventoryId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_inv == null ? 'Инвентаризация' : 'Инвентаризация #${_inv!.id}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          if (_inv != null && _inv!.isEditable)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Сохранить все строки',
              onPressed: _busy ? null : _saveAll,
            ),
        ],
      ),
      bottomNavigationBar: _inv == null || !_inv!.isEditable
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Отменить'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _apply,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('ПРИМЕНИТЬ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green.shade700,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    final inv = _inv!;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.blueGrey.shade50,
        child: Wrap(spacing: 16, runSpacing: 4, children: [
          Text('Склад: ${inv.warehouseName}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Статус: ${inv.statusDisplay}'),
          Text('Позиций: ${inv.lines.length}'),
          Text('Расхождений: ${inv.diffCount}',
              style: TextStyle(
                  color: inv.diffCount > 0
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14, horizontalMargin: 12,
              headingRowHeight: 42, dataRowMinHeight: 38, dataRowMaxHeight: 48,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: _Th('Артикул')),
                DataColumn(label: _Th('Наименование')),
                DataColumn(numeric: true, label: _Th('По учёту')),
                DataColumn(numeric: true, label: _Th('Факт')),
                DataColumn(numeric: true, label: _Th('Расхождение')),
              ],
              rows: inv.lines.map((ln) {
                final ctrl = _ctrls[ln.id];
                final fact = double.tryParse(
                    (ctrl?.text ?? '').replaceAll(',', '.')) ?? 0;
                final theory = double.tryParse(ln.quantityTheory) ?? 0;
                final diff = fact - theory;
                final rowColor = diff.abs() < 0.0001
                    ? null
                    : (diff > 0 ? Colors.green.shade50 : Colors.red.shade50);
                return DataRow(
                  color: rowColor == null
                      ? null
                      : MaterialStateProperty.all(rowColor),
                  cells: [
                    DataCell(Text(ln.productArticle,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(ln.productName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)))),
                    DataCell(Text(_fmtNum(ln.quantityTheory))),
                    DataCell(SizedBox(
                      width: 110,
                      child: TextField(
                        controller: ctrl,
                        enabled: inv.isEditable && !_busy,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,\-]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _saveLine(ln),
                      ),
                    )),
                    DataCell(Text(
                      diff.abs() < 0.0001
                          ? '—'
                          : (diff > 0
                              ? '+${_fmtNum(diff.toString())}'
                              : _fmtNum(diff.toString())),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: diff.abs() < 0.0001
                            ? Colors.grey
                            : (diff > 0
                                ? Colors.green.shade800
                                : Colors.red.shade800),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
