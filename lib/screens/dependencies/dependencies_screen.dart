import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/products_repo.dart';

class DependenciesScreen extends StatefulWidget {
  const DependenciesScreen({super.key});

  @override
  State<DependenciesScreen> createState() => _DependenciesScreenState();
}

class _DependenciesScreenState extends State<DependenciesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Product> _allCastings = [];
  List<Product> _filteredCastings = [];
  List<Product> _parts = [];
  bool _loading = true;
  String? _error;
  final Set<int> _savingIds = {};

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
      final repo = ProductsRepo(context.read<ApiClient>());
      final results = await Future.wait([
        repo.listByType('casting'),
        repo.listByType('part'),
      ]);
      if (!mounted) return;
      setState(() {
        _allCastings = results[0];
        _parts = results[1];
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredCastings = List.from(_allCastings);
    } else {
      _filteredCastings = _allCastings.where((c) {
        return c.article.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(_applyFilter);
    });
  }

  Future<void> _saveMo(
    Product casting,
    String field,
    int? partId,
  ) async {
    setState(() => _savingIds.add(casting.id));
    try {
      final data = <String, dynamic>{
        'article': casting.article,
        'name': casting.name,
        'product_type': casting.productType,
        'category': casting.category,
        'uom': casting.uom,
        'weight_g': casting.weightG,
        'min_stock': casting.minStock,
        'is_active': casting.isActive,
        'mo1': casting.mo1,
        'mo2': casting.mo2,
        'mo3': casting.mo3,
        'mo4': casting.mo4,
        'mo5': casting.mo5,
        'mo6': casting.mo6,
        'mo7': casting.mo7,
        'mo8': casting.mo8,
      };
      data[field] = partId;
      final repo = ProductsRepo(context.read<ApiClient>());
      await repo.update(casting.id, data);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingIds.remove(casting.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Зависимости: отливка → детали'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по артикулу или названию отливки',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(_applyFilter);
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'Найдено: ${_filteredCastings.length} из ${_allCastings.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Ошибка: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_allCastings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Нет отливок (тип «Заготовка / литьё»).\n\n'
            'Создай их в разделе «Справочник».',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_filteredCastings.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredCastings.length,
      itemBuilder: (_, i) {
        final c = _filteredCastings[i];
        return _CastingCard(
          casting: c,
          parts: _parts,
          saving: _savingIds.contains(c.id),
          onSaveMo: (field, partId) => _saveMo(c, field, partId),
        );
      },
    );
  }
}

class _CastingCard extends StatelessWidget {
  final Product casting;
  final List<Product> parts;
  final bool saving;
  final void Function(String field, int? partId) onSaveMo;

  const _CastingCard({
    required this.casting,
    required this.parts,
    required this.saving,
    required this.onSaveMo,
  });

  @override
  Widget build(BuildContext context) {
    final slots = casting.moSlots;
    final filled = slots.where((x) => x != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_in_ar, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${casting.article} — ${casting.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: filled > 0
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Mo: $filled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: filled > 0
                            ? Colors.blue.shade800
                            : Colors.grey.shade700,
                      )),
                ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Вес отливки: ${casting.weightKg} кг',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < slots.length; i++) ...[
              _buildSlot('МО ${i + 1}', slots[i], 'mo${i + 1}'),
              if (i < slots.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(String label, int? value, String field) {
    final valid = parts.any((p) => p.id == value) ? value : null;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: valid,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('— не задан —',
                    style: TextStyle(color: Colors.grey)),
              ),
              ...parts.map((p) => DropdownMenuItem<int?>(
                    value: p.id,
                    child: Text(
                      '${p.article} (${p.weightKg} кг)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: saving ? null : (v) => onSaveMo(field, v),
          ),
        ),
      ],
    );
  }
}
