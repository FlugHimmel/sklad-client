import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/inventory_repo.dart';
import '../../services/warehouses_repo.dart';
import '../../widgets/stale_banner.dart';
import 'inventory_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});
  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  List<Inventory> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await InventoryRepo(context.read<ApiClient>()).list();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    final warehouses = await WarehousesRepo(context.read<ApiClient>()).list();
    if (!mounted) return;
    final commentCtrl = TextEditingController();
    int? selectedWid = warehouses.isNotEmpty ? warehouses.first.id : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новая инвентаризация'),
        content: StatefulBuilder(
          builder: (_, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: selectedWid,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Склад',
                border: OutlineInputBorder(),
              ),
              items: warehouses.map((w) => DropdownMenuItem(
                value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setSt(() => selectedWid = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true || selectedWid == null) return;

    try {
      final inv = await InventoryRepo(context.read<ApiClient>()).create(
        warehouseId: selectedWid!,
        comment: commentCtrl.text.trim(),
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(inventoryId: inv.id)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _open(Inventory inv) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => InventoryDetailScreen(inventoryId: inv.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Инвентаризации (${_items.length})'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: const Text('Новая инвентаризация'),
      ),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_items.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.fact_check, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Инвентаризаций нет',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _createNew,
            icon: const Icon(Icons.add),
            label: const Text('Создать первую'),
          ),
        ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14, horizontalMargin: 12,
            headingRowHeight: 42, dataRowMinHeight: 34, dataRowMaxHeight: 44,
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
            columns: const [
              DataColumn(label: _Th('№')),
              DataColumn(label: _Th('Склад')),
              DataColumn(label: _Th('Статус')),
              DataColumn(numeric: true, label: _Th('Позиций')),
              DataColumn(numeric: true, label: _Th('Расхождений')),
              DataColumn(label: _Th('Начата')),
              DataColumn(label: _Th('Завершена')),
              DataColumn(label: _Th('Комментарий')),
              DataColumn(label: _Th('')),
            ],
            rows: _items.map((inv) {
              final diff = inv.diffCount;
              return DataRow(cells: [
                DataCell(Text('#${inv.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(inv.warehouseName)),
                DataCell(_statusChip(inv.status, inv.statusDisplay)),
                DataCell(Text('${inv.lines.length}')),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diff > 0 ? Colors.orange.shade100 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$diff',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: diff > 0 ? Colors.orange.shade900 : Colors.green.shade800,
                      )),
                )),
                DataCell(Text(_fmtDate(inv.startedAt),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(inv.completedAt == null ? '—' : _fmtDate(inv.completedAt),
                    style: const TextStyle(fontSize: 12))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(inv.comment, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)))),
                DataCell(IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () => _open(inv))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _statusChip(String st, String display) {
    Color c;
    switch (st) {
      case 'draft': c = Colors.grey; break;
      case 'in_progress': c = Colors.orange; break;
      case 'completed': c = Colors.green; break;
      case 'cancelled': c = Colors.red; break;
      default: c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(display,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
