import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../scanner/scanner_screen.dart';

class ContainerStateScreen extends StatefulWidget {
  const ContainerStateScreen({super.key});

  @override
  State<ContainerStateScreen> createState() => _ContainerStateScreenState();
}

class _ContainerStateScreenState extends State<ContainerStateScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<StockContainer> _all = [];
  List<StockContainer> _filtered = [];
  final Set<int> _selected = {};

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _filterTab = 'all'; // all / packed / unpacked / reserve

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final page = await repo.list();
      if (!mounted) return;
      setState(() {
        _all = page.items
            .where((c) => c.shippedAt == null)  // отгруженные не трогаем
            .toList();
        _selected.removeWhere((id) => !_all.any((c) => c.id == id));
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
    final q = _searchCtrl.text.trim().toLowerCase();
    _filtered = _all.where((c) {
      // Фильтр-чип
      switch (_filterTab) {
        case 'packed':
          if (c.packedAt == null) return false;
          break;
        case 'unpacked':
          if (c.packedAt != null) return false;
          break;
        case 'reserve':
          final wh = (c.warehouseName ?? '').toLowerCase();
          if (!wh.contains('резерв') && !wh.contains('задел')) return false;
          break;
      }
      // Поиск
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

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(_applyFilter);
    });
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      final visibleIds = _filtered.map((c) => c.id).toSet();
      final allSelected = visibleIds.every((id) => _selected.contains(id));
      if (allSelected) {
        _selected.removeAll(visibleIds);
      } else {
        _selected.addAll(visibleIds);
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  Future<void> _scanAndSelect() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    // Ищем в загруженном списке
    final found = _all.firstWhere(
      (c) => c.code == code,
      orElse: () => StockContainer(
        id: -1, code: code, quantity: '0',
        status: '', statusDisplay: '', note: '',
      ),
    );

    if (found.id == -1) {
      // Нет в списке — возможно отгружена или не существует
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тара $code не найдена среди активных')),
      );
      return;
    }

    // Автовыбор + скролл к ней (просто выбираем)
    setState(() {
      if (_selected.contains(found.id)) {
        _selected.remove(found.id);
      } else {
        _selected.add(found.id);
      }
      // Сброс фильтра чтобы точно её увидеть
      _filterTab = 'all';
      _searchCtrl.clear();
      _applyFilter();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_selected.contains(found.id)
            ? '✓ ${found.code} выбран'
            : '○ ${found.code} снят'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _applyBulk(bool packed) async {
    if (_selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(packed
            ? 'Отметить упакованными?'
            : 'Снять отметку упаковки?'),
        content: Text(
            'Выбрано тар: ${_selected.length}\n\n'
            '${packed ? "Они будут отмечены как готовые к отгрузке." : "Они перестанут быть готовыми к отгрузке."}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(packed ? 'Отметить' : 'Снять'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final repo = ContainersRepo(context.read<ApiClient>());
      final res = await repo.bulkSetPacked(
        ids: _selected.toList(),
        packed: packed,
      );
      if (!mounted) return;

      final updated = res['updated'] as int? ?? 0;
      final skipped = (res['skipped'] as List?) ?? [];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(skipped.isEmpty
              ? '✓ Обновлено: $updated'
              : '✓ Обновлено: $updated, пропущено: ${skipped.length}'),
          backgroundColor: packed ? Colors.green : Colors.orange,
        ),
      );
      setState(() {
        _selected.clear();
        _busy = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleIds = _filtered.map((c) => c.id).toSet();
    final allSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selected.contains(id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Состояние тары (${_filtered.length})'),
        actions: [
          if (_filtered.isNotEmpty)
            IconButton(
              icon: Icon(allSelected
                  ? Icons.deselect
                  : Icons.select_all),
              tooltip: allSelected ? 'Снять выбор' : 'Выбрать все',
              onPressed: _toggleAll,
            ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Верх: поиск + скан
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Поиск по коду или артикулу',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Сканировать ШК',
              onPressed: _scanAndSelect,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ]),
        ),
        // Фильтр-чипы
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            _chip('Все', 'all'),
            const SizedBox(width: 6),
            _chip('Упакованные', 'packed'),
            const SizedBox(width: 6),
            _chip('Не упакованные', 'unpacked'),
            const SizedBox(width: 6),
            _chip('Задел', 'reserve'),
          ]),
        ),
        // Инфо-плашка про выбор
        if (_selected.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Icon(Icons.check_circle, size: 16,
                  color: Colors.teal.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Выбрано: ${_selected.length}',
                    style: TextStyle(
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('Снять'),
              ),
            ]),
          ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
      bottomNavigationBar: _selected.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filterTab == value;
    return FilterChip(
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('Тар не найдено',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(StockContainer c) {
    final isSelected = _selected.contains(c.id);
    final isPacked = c.packedAt != null;
    final isMain = (c.warehouseName ?? '').toLowerCase().contains('основн');
    final isEmpty = c.lines.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isSelected ? Colors.teal.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Colors.teal.shade400
              : (isPacked ? Colors.green.shade300 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isEmpty ? null : () => _toggle(c.id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Чекбокс
            if (!isEmpty)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggle(c.id),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (isEmpty)
              const SizedBox(width: 40),
            const SizedBox(width: 4),
            // Содержимое
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(c.code,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    if (isPacked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 12,
                                  color: Colors.green.shade800),
                              const SizedBox(width: 3),
                              Text('Упакована',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900)),
                            ]),
                      )
                    else if (!isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Не упакована',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  if (isEmpty)
                    const Text('Пустая',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey))
                  else
                    ...c.lines.map((l) => Text(
                          '${l.productArticle} · ${l.productName} — ${l.quantity} шт',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        )),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.warehouse,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(c.warehouseName ?? '—',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700)),
                    if (!isMain && !isPacked && !isEmpty) ...[
                      const SizedBox(width: 8),
                      Text('(не MAIN — упаковать нельзя)',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontStyle: FontStyle.italic)),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final selected = _filtered.where((c) => _selected.contains(c.id)).toList();
    final packedCount = selected.where((c) => c.packedAt != null).length;
    final unpackedCount = selected.where((c) => c.packedAt == null).length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          boxShadow: const [
            BoxShadow(color: Colors.black12,
                blurRadius: 4, offset: Offset(0, -2)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Выбрано: ${_selected.length} · упаковано: $packedCount · не упаковано: $unpackedCount',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || unpackedCount == 0
                    ? null
                    : () => _applyBulk(true),
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 20),
                label: Text(
                  'УПАКОВАТЬ ($unpackedCount)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || packedCount == 0
                    ? null
                    : () => _applyBulk(false),
                icon: const Icon(Icons.undo, size: 20),
                label: Text(
                  'СНЯТЬ ($packedCount)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
