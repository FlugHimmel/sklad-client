import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/containers_repo.dart';
import '../../widgets/stale_banner.dart';
import '../scanner/scanner_screen.dart';
import 'container_detail_screen.dart';
import 'container_create_screen.dart';

class ContainersListScreen extends StatefulWidget {
  const ContainersListScreen({super.key});

  @override
  State<ContainersListScreen> createState() => _ContainersListScreenState();
}

class _ContainersListScreenState extends State<ContainersListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<StockContainer> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  bool _hideEmpty = false;
  bool _isFoundry = false;

  final Set<int> _selected = {};
  bool _printing = false;
  bool _showSelection = false;

  @override
  void initState() {
    super.initState();
    _initRole();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initRole() {
    try {
      final auth = context.read<AuthService>();
      final role = (auth.user?['role'] ?? 'user').toString();
      _isFoundry = role == 'foundry';
    } catch (_) {}
  }

  ContainersRepo get _repo => ContainersRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? status;
      bool? packed;

      switch (_filter) {
        case 'packed':
          packed = true;
          break;
        case 'unpacked':
          packed = false;
          break;
        case 'empty':
          status = 'empty';
          break;
      }

      final page = await _repo.list(
        search: _searchCtrl.text.trim(),
        status: status,
        packed: packed,
      );

      if (!mounted) return;
      var items = page.items;

      if (_filter == 'reserve') {
        items = items.where((c) {
          final wh = (c.warehouseName ?? '').toLowerCase();
          return wh.contains('резерв') || wh.contains('задел');
        }).toList();
      }
      if (_filter != 'all') {
        items = items.where((c) => c.shippedAt == null).toList();
      }

      // Скрыть пустые тары (если включён чекбокс)
      if (_hideEmpty) {
        items = items.where((c) => c.lines.isNotEmpty).toList();
      }

      setState(() {
        _items = items;
        _total = items.length;
        _selected.removeWhere((id) => !items.any((c) => c.id == id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _setFilter(String f) {
    setState(() => _filter = f);
    _load();
  }

  Future<void> _openDetail(StockContainer c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ContainerDetailScreen(containerId: c.id)),
    );
    if (changed == true) _load();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    try {
      final c = await _repo.byCode(code);
      if (!mounted) return;
      await _openDetail(c);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тара «$code» не найдена')));
    }
  }

  Future<void> _createNew() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ContainerCreateScreen()),
    );
    if (changed == true) _load();
  }

  void _toggleSelectAll() {
    if (_selected.length == _items.length) {
      setState(_selected.clear);
    } else {
      setState(() {
        _selected.clear();
        _selected.addAll(_items.map((c) => c.id));
      });
    }
  }

  void _toggleOne(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _printSelected() async {
    if (_selected.isEmpty) return;
    await _printPacking(_selected.toList(), 'выбранных: ${_selected.length}');
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _showSelection = false;
    });
    _load();
  }

  Future<void> _printAllFiltered() async {
    if (_items.isEmpty) return;
    final ids = _items.map((c) => c.id).toList();
    await _printPacking(ids, 'по фильтру: ${ids.length}');
    _load();
  }

  Future<void> _printSingle(StockContainer c) async {
    await _printPacking([c.id], c.code);
  }

  Future<void> _printPacking(List<int> ids, String label) async {
    if (ids.isEmpty) return;
    setState(() => _printing = true);
    try {
      final bytes = await _repo.bulkPackingPdf(ids);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-$label.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка печати: $e')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Тара ($_total)'),
        actions: [
          if (_showSelection)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: _selected.length == _items.length
                  ? 'Снять выделение'
                  : 'Выбрать все',
              onPressed: _items.isEmpty ? null : _toggleSelectAll,
            ),
          IconButton(
            icon: Icon(_showSelection ? Icons.close : Icons.checklist),
            tooltip:
                _showSelection ? 'Выйти из выбора' : 'Выбрать для печати',
            onPressed: () => setState(() {
              _showSelection = !_showSelection;
              if (!_showSelection) _selected.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Сканировать',
            onPressed: _scan,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: _showSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: _createNew,
              icon: const Icon(Icons.add),
              label: const Text('Новая тара')),
      bottomNavigationBar: _showSelection && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FilledButton.icon(
                  onPressed: _printing ? null : _printSelected,
                  icon: _printing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print),
                  label: Text(
                    _printing
                        ? 'Готовим PDF...'
                        : 'Печать упаковочных: ${_selected.length}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.teal.shade700,
                  ),
                ),
              ),
            )
          : null,
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Поиск по коду или артикулу',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            _chip('Все', 'all'),
            const SizedBox(width: 6),
            _chip('✓ Упакованные', 'packed', color: Colors.green),
            const SizedBox(width: 6),
            _chip('○ Не упакованные', 'unpacked', color: Colors.orange),
            if (!_isFoundry) ...[
              const SizedBox(width: 6),
              _chip('Задел', 'reserve', color: Colors.teal),
            ],
            const SizedBox(width: 6),
            _chip('Пустые', 'empty', color: Colors.grey),
            const SizedBox(width: 12),
            // Чекбокс: скрыть пустые
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _hideEmpty,
                    onChanged: (v) {
                      setState(() => _hideEmpty = v ?? false);
                      _load();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Скрыть пустые',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed:
                  _items.isEmpty || _printing ? null : _printAllFiltered,
              icon: const Icon(Icons.print, size: 18),
              label: Text('Печать (${_items.length})'),
            ),
          ]),
        ),
        if (_showSelection)
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Выбрано: ${_selected.length} из ${_items.length}. '
              'Отметь тары галочками слева.',
              style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _chip(String label, String value, {Color? color}) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color?.withOpacity(0.25),
      checkmarkColor: color,
      onSelected: (_) => _setFilter(value),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_items.isEmpty) {
      return Center(
        child: Text('Тар нет по фильтру «${_filterLabel()}»',
            style: const TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _items.length,
        itemBuilder: (_, i) => _buildCard(_items[i]),
      ),
    );
  }

  String _filterLabel() {
    switch (_filter) {
      case 'packed': return 'Упакованные';
      case 'unpacked': return 'Не упакованные';
      case 'reserve': return 'Задел';
      case 'empty': return 'Пустые';
      default: return 'Все';
    }
  }

  Widget _buildCard(StockContainer c) {
    final isSelected = _selected.contains(c.id);
    final isPacked = c.packedAt != null && c.shippedAt == null;
    final isShipped = c.shippedAt != null;
    final isEmpty = c.lines.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isSelected ? Colors.teal.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Colors.teal.shade400
              : (isPacked ? Colors.green.shade400 : Colors.grey.shade300),
          width: isSelected || isPacked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (_showSelection)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleOne(c.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              Expanded(
                child: InkWell(
                  onTap: () => _openDetail(c),
                  child: Text(c.code,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ),
              ),
              if (isPacked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle,
                        size: 14, color: Colors.green.shade800),
                    const SizedBox(width: 4),
                    Text('Готово к отгрузке',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900)),
                  ]),
                )
              else if (isShipped)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Отгружена',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900)),
                ),
            ]),
            const SizedBox(height: 6),
            if (isEmpty)
              const Text('Пустая', style: TextStyle(color: Colors.grey))
            else
              ...c.lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${l.productArticle} · ${l.productName}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${l.quantity} шт',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  )),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.warehouse, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(c.warehouseName ?? '—',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade700)),
              const Spacer(),
              if (!isEmpty)
                IconButton(
                  icon: const Icon(Icons.print, size: 18),
                  tooltip: 'Печать упаковочного',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _printing ? null : () => _printSingle(c),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _openDetail(c),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
