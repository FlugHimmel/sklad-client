import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/orders_repo.dart';
import '../../services/products_repo.dart';
import '../../widgets/product_search_field.dart';

class _LineDraft {
  int? productId;
  final TextEditingController qtyCtrl = TextEditingController();
  void dispose() => qtyCtrl.dispose();
}

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final List<_LineDraft> _lines = [_LineDraft()];

  String _kind = 'production';
  DateTime? _dueDate;
  List<Product> _parts = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _customerCtrl.dispose();
    _commentCtrl.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final parts =
          await ProductsRepo(context.read<ApiClient>()).listByType('part');
      if (!mounted) return;
      setState(() => _parts = parts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_numberCtrl.text.trim().isEmpty) return;

    final lines = <Map<String, dynamic>>[];
    for (final l in _lines) {
      if (l.productId == null) continue;
      final q = l.qtyCtrl.text.trim().replaceAll(',', '.');
      if (q.isEmpty) continue;
      lines.add({'product': l.productId, 'quantity_planned': q});
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавь хотя бы одну позицию')));
      return;
    }

    setState(() => _busy = true);
    try {
      final fmt = (DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await OrdersRepo(context.read<ApiClient>()).create(
        number: _numberCtrl.text.trim(),
        kind: _kind,
        customer: _customerCtrl.text.trim(),
        dueDate: _dueDate != null ? fmt(_dueDate!) : null,
        comment: _commentCtrl.text.trim(),
        lines: lines,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый заказ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _numberCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Номер заказа *',
                            border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Укажи номер'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _kind,
                        decoration: const InputDecoration(
                            labelText: 'Тип', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'production',
                              child: Text('Производственный')),
                          DropdownMenuItem(
                              value: 'shipment', child: Text('На отгрузку')),
                        ],
                        onChanged: (v) =>
                            setState(() => _kind = v ?? 'production'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customerCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Заказчик',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Срок',
                              border: OutlineInputBorder()),
                          child: Text(_dueDate == null
                              ? '—'
                              : '${_dueDate!.day.toString().padLeft(2, '0')}.${_dueDate!.month.toString().padLeft(2, '0')}.${_dueDate!.year}'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        const Expanded(
                          child: Text('Позиции',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _lines.add(_LineDraft())),
                          icon: const Icon(Icons.add),
                          label: const Text('Позиция'),
                        ),
                      ]),
                      ..._buildLines(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Комментарий',
                            border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: const Text('Создать заказ',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildLines() {
    return List.generate(_lines.length, (i) {
      final l = _lines[i];
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductSearchField(
                products: _parts,
                value: l.productId,
                label: 'Деталь',
                dense: true,
                onChanged: (v) => setState(() => l.productId = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: l.qtyCtrl,
                    decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: 'шт',
                        labelText: 'Кол-во'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _lines.length > 1
                      ? () => setState(() {
                            _lines.removeAt(i);
                            l.dispose();
                          })
                      : null,
                  icon: Icon(Icons.close,
                      color: _lines.length > 1 ? Colors.red : Colors.grey),
                ),
              ]),
            ],
          ),
        ),
      );
    });
  }
}
