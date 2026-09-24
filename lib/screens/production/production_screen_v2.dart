import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../services/api_client.dart';
import '../scanner/scanner_screen.dart';
import 'container_history_screen.dart';
import 'operation_form_screen.dart';

class ProductionScreenV2 extends StatefulWidget {
  const ProductionScreenV2({super.key});

  @override
  State<ProductionScreenV2> createState() => _ProductionScreenV2State();
}

class _ProductionScreenV2State extends State<ProductionScreenV2> {
  List<StockContainer> _all = [];
  List<StockContainer> _filtered = [];
  bool _loading = true;
  String? _error;
  String _filterTab = 'all'; // all / main / reserve
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
          .where((c) => c.quantity != '0' && c.quantity != '0.000')
          .toList();
      if (!mounted) return;
      setState(() {
        _all = list;
        _applyFilter();
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

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((c) {
      if (_filterTab == 'main') {
        final wh = (c.warehouseName ?? '').toLowerCase();
        if (!wh.contains('main') && !wh.contains('основн')) return false;
      } else if (_filterTab == 'reserve') {
        final wh = (c.warehouseName ?? '').toLowerCase();
        if (!wh.contains('reserve') &&
            !wh.contains('резерв') &&
            !wh.contains('задел')) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      if (c.code.toLowerCase().contains(q)) return true;
      for (final l in c.lines) {
        if ((l.productArticle ?? '').toLowerCase().contains(q)) return true;
        if ((l.productName ?? '').toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
    _filtered.sort((a, b) => b.code.compareTo(a.code));
  }

  Future<void> _openForm({StockContainer? source}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OperationFormScreen(sourceContainer: source),
      ),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  Future<void> _openHistory(StockContainer c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContainerHistoryScreen(container: c),
      ),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    StockContainer? c;
    for (final item in _all) {
      if (item.code == code) {
        c = item;
        break;
      }
    }
    if (c == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тара $code не найдена в списке')),
      );
      return;
    }
    await _openForm(source: c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Производство NEW'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _filtered.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Нет тар по этому фильтру')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _ContainerCard(
                          container: _filtered[i],
                          onOpenForm: () => _openForm(source: _filtered[i]),
                          onOpenHistory: () => _openHistory(_filtered[i]),
                        ),
                      ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('СКАН'),
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('ОПЕРАЦИЯ'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: 'Поиск по коду или артикулу',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip('Все', 'all'),
                const SizedBox(width: 6),
                _chip('Основной', 'main'),
                const SizedBox(width: 6),
                _chip('Задел', 'reserve'),
                const Spacer(),
                Text(
                  '${_filtered.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filterTab == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filterTab = value;
          _applyFilter();
        });
      },
    );
  }
}

class _ContainerCard extends StatelessWidget {
  final StockContainer container;
  final VoidCallback onOpenForm;
  final VoidCallback onOpenHistory;
  const _ContainerCard({
    required this.container,
    required this.onOpenForm,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (container.isPacked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'Упаковано',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (container.warehouseName != null &&
                    container.warehouseName!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      container.warehouseName!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (container.lines.isEmpty)
              const Text('Пустая')
            else
              ...container.lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.productArticle ?? ''}  ${l.productName ?? ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '${l.quantity} шт',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenHistory,
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('История'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpenForm,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Операция'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
