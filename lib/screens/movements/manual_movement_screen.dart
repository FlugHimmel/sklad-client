import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/movements_repo.dart';
import '../../services/products_repo.dart';
import '../../services/warehouses_repo.dart';
import '../../widgets/product_search_field.dart';

class ManualMovementScreen extends StatefulWidget {
  final String initialDirection;
  const ManualMovementScreen({super.key, this.initialDirection = 'in'});

  @override
  State<ManualMovementScreen> createState() => _ManualMovementScreenState();
}

class _ManualMovementScreenState extends State<ManualMovementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  int? _productId;
  int? _warehouseId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialDirection == 'out' ? 1 : 0;
    _tabCtrl = TabController(
        length: 2, vsync: this, initialIndex: initialIndex);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _qtyCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _direction => _tabCtrl.index == 0 ? 'in' : 'out';
  bool get _isIn => _direction == 'in';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final productsRepo = ProductsRepo(api);
      final warehousesRepo = WarehousesRepo(api);

      final results = await Future.wait([
        productsRepo.list(page: 1),
        warehousesRepo.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = (results[0] as ProductPage).items;
        _warehouses = results[1] as List<Warehouse>;
        if (_warehouses.isNotEmpty) {
          _warehouseId = _warehouses.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null || _warehouseId == null) return;

    setState(() => _busy = true);
    try {
      await MovementsRepo(context.read<ApiClient>()).manual(
        direction: _direction,
        productId: _productId!,
        warehouseId: _warehouseId!,
        quantity: _qtyCtrl.text.trim().replaceAll(',', '.'),
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      final verb = _isIn ? 'Приход' : 'Расход';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$verb проведён')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isIn ? Colors.green : Colors.deepOrange;
    final title = _isIn ? 'Приход' : 'Расход';
    final button = _isIn ? 'ПРОВЕСТИ ПРИХОД' : 'ПРОВЕСТИ РАСХОД';

    return Scaffold(
      appBar: AppBar(
        title: Text('Движение вручную: $title'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Приход'),
            Tab(icon: Icon(Icons.remove_circle_outline), text: 'Расход'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          border:
                              Border.all(color: color.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(
                              _isIn
                                  ? Icons.call_received
                                  : Icons.call_made,
                              color: color,
                              size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isIn
                                  ? 'Проведение прихода на склад. Остатки увеличатся.'
                                  : 'Проведение расхода со склада. Остатки уменьшатся.',
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      ProductSearchField(
                        products: _products,
                        value: _productId,
                        label: 'Артикул',
                        onChanged: (v) => setState(() => _productId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _warehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Склад *',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Количество *',
                          border: OutlineInputBorder(),
                          suffixText: 'шт',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Укажите количество';
                          }
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Должно быть > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                          border: OutlineInputBorder(),
                          hintText:
                              'Например: брак от поставщика, возврат, пересорт',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : Icon(
                                  _isIn
                                      ? Icons.call_received
                                      : Icons.call_made,
                                  size: 24),
                          label: Text(button,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Тара не создаётся. Движение будет учтено в общих '
                        'остатках и попадает в «Журнал движений».',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
    );
  }
}
