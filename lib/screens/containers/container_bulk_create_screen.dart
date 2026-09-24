import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../../services/warehouses_repo.dart';

/// Создание пустых тар-болванок пачкой. Коды генерируются автоматически.
class ContainerBulkCreateScreen extends StatefulWidget {
  const ContainerBulkCreateScreen({super.key});

  @override
  State<ContainerBulkCreateScreen> createState() =>
      _ContainerBulkCreateScreenState();
}

class _ContainerBulkCreateScreenState
    extends State<ContainerBulkCreateScreen> {
  final _countCtrl = TextEditingController(text: '50');
  final _noteCtrl = TextEditingController();

  List<Warehouse> _warehouses = [];
  int? _warehouseId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>>? _created;
  List<int> _createdIds = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final list = await WarehousesRepo(context.read<ApiClient>()).list();
      if (!mounted) return;
      int? mainId;
      for (final w in list) {
        if (w.code == 'MAIN') {
          mainId = w.id;
          break;
        }
      }
      mainId ??= list.isNotEmpty ? list.first.id : null;
      setState(() {
        _warehouses = list;
        _warehouseId = mainId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count < 1 || count > 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Число от 1 до 500'),
      ));
      return;
    }
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Выберите склад'),
      ));
      return;
    }

    setState(() => _busy = true);
    try {
      final created = await ContainersRepo(context.read<ApiClient>())
          .bulkCreateEmpty(
        count: count,
        warehouseId: _warehouseId!,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _created = created;
        _createdIds = created
            .map((e) => (e['id'] as num).toInt())
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printAll() async {
    if (_createdIds.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await ContainersRepo(context.read<ApiClient>())
          .bulkLabelsPdf(_createdIds);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'bulk-labels-empty.pdf',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать болванки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _created == null
                  ? _buildForm()
                  : _buildResult(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Пустые тары — «болванки». Наклейки с их кодами нужно '
            'распечатать и раздать на участки. Когда оператор положит '
            'детали в болванку и отсканирует её — тара «оживёт» '
            'с содержимым.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _warehouseId,
          decoration: const InputDecoration(
            labelText: 'Склад, где будут лежать болванки',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: _warehouses
              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
              .toList(),
          onChanged: (v) => setState(() => _warehouseId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _countCtrl,
          decoration: const InputDecoration(
            labelText: 'Сколько создать',
            helperText: 'От 1 до 500',
            border: OutlineInputBorder(),
            suffixText: 'шт',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Примечание (необязательно)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_box),
            label: Text(
              _busy ? 'Создаю...' : 'СОЗДАТЬ',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final created = _created!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle,
                  color: Colors.green.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Создано ${created.length} пустых тар',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _busy ? null : _printAll,
            icon: const Icon(Icons.print),
            label: Text(
              'ПЕЧАТЬ ЭТИКЕТОК (${created.length})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Коды:',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(
            created.map((e) => e['code'].toString()).join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _created = null;
              _createdIds = [];
            }),
            child: const Text('Создать ещё'),
          ),
        ),
      ],
    );
  }
}
