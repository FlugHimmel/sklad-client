import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/containers_repo.dart';
import '../../services/products_repo.dart';
import '../../services/warehouses_repo.dart';
import '../../widgets/product_search_field.dart';

class _LineRow {
  int? productId;
  final TextEditingController qtyCtrl = TextEditingController();
  void dispose() => qtyCtrl.dispose();
}

class ContainerCreateScreen extends StatefulWidget {
  const ContainerCreateScreen({super.key});

  @override
  State<ContainerCreateScreen> createState() => _ContainerCreateScreenState();
}

class _ContainerCreateScreenState extends State<ContainerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final List<_LineRow> _lines = [_LineRow()];

  int? _warehouseId;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool _isFoundry = false;

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final r in _lines) r.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final auth = context.read<AuthService>();
      final role = (auth.user?['role'] ?? 'user').toString();
      final isFoundry = role == 'foundry';

      final api = context.read<ApiClient>();
      final productsRepo = ProductsRepo(api);
      final warehousesRepo = WarehousesRepo(api);

      final results = await Future.wait([
        isFoundry
            ? productsRepo.listByType('casting')
            : productsRepo.listByType('casting').then((c) async {
                final p = await productsRepo.listByType('part');
                return [...c, ...p];
              }),
        warehousesRepo.list(),
      ]);
      if (!mounted) return;

      final products = results[0] as List<Product>;
      final warehouses = results[1] as List<Warehouse>;

      int? whId;
      if (isFoundry) {
        final zlk = warehouses.where((w) => w.code == 'ZLK').toList();
        if (zlk.isNotEmpty) whId = zlk.first.id;
      }
      whId ??= warehouses.isNotEmpty ? warehouses.first.id : null;

      setState(() {
        _isFoundry = isFoundry;
        _products = products;
        _warehouses = warehouses;
        _warehouseId = whId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addLine() {
    setState(() => _lines.add(_LineRow()));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  int get _totalQty {
    int total = 0;
    for (final r in _lines) {
      final n = int.tryParse(r.qtyCtrl.text.trim()) ?? 0;
      total += n;
    }
    return total;
  }

  Future<void> _save({bool andAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final payload = <Map<String, dynamic>>[];
    for (final r in _lines) {
      if (r.productId == null) continue;
      final q = r.qtyCtrl.text.trim().replaceAll(',', '.');
      if (q.isEmpty) continue;
      payload.add({'product_id': r.productId, 'quantity': q});
    }
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните хотя бы одну строку')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final c = await repo.multiCreate(
        warehouseId: _warehouseId!,
        lines: payload,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;

      if (andAnother) {
        setState(() {
          for (final r in _lines) r.dispose();
          _lines.clear();
          _lines.add(_LineRow());
          _noteCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Тара ${c.code} создана. Готово к следующей.'),
            duration: const Duration(seconds: 3),
          ),
        );
        if (_isFoundry) await _askDocs(c.id, c.code);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тара ${c.code} создана')));
      if (_isFoundry) {
        await _askDocs(c.id, c.code);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// После создания тары спрашиваем: печатать упаковочный лист?
  Future<void> _askDocs(int containerId, String code) async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Тара $code создана'),
          content: const Text(
            'Напечатать упаковочный лист (A4)?\n\n'
            'На нём: код тары, ШК, артикул, количество, вес, '
            'а для литья — детали, которые из неё делаются.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Пропустить'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Напечатать'),
            ),
          ],
        );
      },
    );
    if (result == true && mounted) {
      await _printPacking(containerId);
    }
  }

  Future<void> _printPacking(int id) async {
    try {
      final bytes = await context
          .read<ApiClient>()
          .getBytes('/api/containers/$id/simple-packing-pdf/');
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-$id.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isFoundry ? 'Новая тара литья' : 'Новая тара';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_isFoundry)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border:
                                Border.all(color: Colors.orange.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.factory,
                                color: Colors.orange.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Режим Литейки: только литьё, склад Завод.',
                                style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      if (!_isFoundry)
                        DropdownButtonFormField<int>(
                          initialValue: _warehouseId,
                          decoration: const InputDecoration(
                              labelText: 'Склад *',
                              border: OutlineInputBorder()),
                          items: _warehouses
                              .map((w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text(w.name),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _warehouseId = v),
                          validator: (v) =>
                              v == null ? 'Выберите склад' : null,
                        ),
                      if (!_isFoundry) const SizedBox(height: 16),
                      Row(children: [
                        const Expanded(
                          child: Text('Содержимое тары',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        Text('${_lines.length} строк · $_totalQty шт',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ]),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _lines.length; i++)
                        _buildLineCard(i),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить ещё артикул'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Примечание к таре',
                            border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      if (_isFoundry) ...[
                        SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _save(andAnother: false),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.qr_code_2, size: 22),
                            label: const Text('СОЗДАТЬ ТАРУ',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _save(andAnother: true),
                            icon: const Icon(Icons.add, size: 22),
                            label: const Text('СОЗДАТЬ И ЕЩЁ ОДНУ',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _save(),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.qr_code_2),
                          label: const Text('Создать и получить код'),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLineCard(int i) {
    final r = _lines[i];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductSearchField(
              products: _products,
              value: r.productId,
              label: 'Артикул',
              dense: true,
              onChanged: (v) => setState(() => r.productId = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: r.qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Кол-во',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: 'шт',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Укажите';
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n <= 0) return '> 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Убрать строку',
                onPressed: _lines.length > 1 ? () => _removeLine(i) : null,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
