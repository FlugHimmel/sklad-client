import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/products_repo.dart';
import '../../widgets/stale_banner.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});
  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Product> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  String? _filterType;
  bool _filterActiveOnly = false;
  bool _filterDraftsOnly = false;
  bool _showAliases = false; // показывать ли дубли
  String? _resolvedFrom;     // какой старый артикул ввёл пользователь

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  ProductsRepo get _repo => ProductsRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = await _repo.list(
        search: _searchCtrl.text.trim(),
        productType: _filterType,
        isActive: _filterActiveOnly ? true : null, page: 1);
      if (!mounted) return;
      var items = page.items;
      if (_filterDraftsOnly) {
        items = items.where((p) => !p.isActive).toList();
      }
      // Скрываем дубли, если чекбокс выключен
      if (!_showAliases) {
        items = items.where((p) => p.aliasOf == null).toList();
      }

      // RESOLVE: если поиск дал 0 и запрос похож на артикул — пробуем resolve
      String? resolvedFrom;
      final q = _searchCtrl.text.trim();
      if (items.isEmpty && q.isNotEmpty) {
        try {
          final mainP = await _repo.resolve(q);
          items = [mainP];
          resolvedFrom = q;
        } catch (_) {
          // не нашли — оставляем пусто
        }
      }

      setState(() {
        _items = items;
        _total = page.total;
        _resolvedFrom = resolvedFrom;
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

  Future<void> _openDetail(Product p) async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
    if (changed == true) _load();
  }

  Future<void> _createNew() async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = _filterDraftsOnly
        ? _items.length
        : _items.where((p) => !p.isActive).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Справочник ($_total)'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew, icon: const Icon(Icons.add),
        label: const Text('Новый артикул')),
      body: Column(children: [
        StaleBanner(onRefresh: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl, onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Поиск по артикулу или названию',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            FilterChip(label: const Text('Только активные'),
              selected: _filterActiveOnly,
              onSelected: (v) {
                setState(() { _filterActiveOnly = v; if (v) _filterDraftsOnly = false; });
                _load();
              }),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('Только черновые${
                draftCount > 0 ? " ($draftCount)" : ""}'),
              selected: _filterDraftsOnly,
              selectedColor: Colors.orange.shade100,
              onSelected: (v) {
                setState(() { _filterDraftsOnly = v; if (v) _filterActiveOnly = false; });
                _load();
              }),
            const SizedBox(width: 8),
            // Чекбокс: показать дубли
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
                    value: _showAliases,
                    onChanged: (v) {
                      setState(() => _showAliases = v ?? false);
                      _load();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Показать дубли',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ...kProductTypes.map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(label: Text(t.$2),
                selected: _filterType == t.$1,
                onSelected: (v) {
                  setState(() => _filterType = v ? t.$1 : null); _load();
                }))),
          ]),
        ),
        // Плашка «найдено по старому артикулу»
        if (_resolvedFrom != null)
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.link, size: 18,
                  color: Colors.blue.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Поиск по старому артикулу «$_resolvedFrom» → '
                  'показан главный «${_items.isNotEmpty ? _items.first.article : ""}»',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchCtrl.clear();
                    _resolvedFrom = null;
                  });
                  _load();
                },
                child: const Text('Сбросить'),
              ),
            ]),
          ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_items.isEmpty) return const Center(child: Text('Ничего не найдено'));
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18, horizontalMargin: 12,
            headingRowHeight: 40, dataRowMinHeight: 32, dataRowMaxHeight: 42,
            headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
            columns: const [
              DataColumn(label: _Th('Артикул')),
              DataColumn(label: _Th('Наименование')),
              DataColumn(label: _Th('Тип')),
              DataColumn(label: _Th('Ед.')),
              DataColumn(numeric: true, label: _Th('Вес, кг')),
              DataColumn(label: _Th('Статус')),
              DataColumn(label: _Th('')),
            ],
            rows: _items.map(_buildRow).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Product p) {
    // Цвет фона строки
    Color? rowColor;
    if (p.isAlias) {
      rowColor = Colors.grey.shade100;      // дубль — серый
    } else if (!p.isActive) {
      rowColor = Colors.orange.shade50;     // черновик — оранжевый
    }

    return DataRow(
      color: rowColor == null ? null : MaterialStateProperty.all(rowColor),
      cells: [
        // Артикул + пометки
        DataCell(Row(children: [
          Text(p.article, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13,
            fontFamily: 'monospace',
          )),
          if (p.isAlias)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Дубль — используется главный артикул',
                child: Icon(Icons.link, size: 14, color: Colors.grey),
              ),
            ),
          if (!p.isAlias && p.aliasesCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text('+${p.aliasesCount}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800)),
              ),
            ),
        ])),
        // Наименование + у дубля подпись «дубль X»
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.name, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
              if (p.isAlias && p.aliasOfArticle != null)
                Text('дубль ${p.aliasOfArticle}',
                    style: TextStyle(fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
            ],
          ),
        )),
        DataCell(_typeChip(p.productTypeDisplay)),
        DataCell(Text(p.uomDisplay, style: const TextStyle(fontSize: 13))),
        DataCell(Text(p.weightKg, style: const TextStyle(fontSize: 13))),
        DataCell(p.isActive
          ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Активен',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800)))
          : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Черновик',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900)))),
        DataCell(IconButton(
          icon: const Icon(Icons.arrow_forward, size: 18),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          onPressed: () => _openDetail(p))),
      ],
    );
  }

  Widget _typeChip(String label) {
    Color color;
    switch (label) {
      case 'Сырьё': color = Colors.brown; break;
      case 'Заготовка / литьё': color = Colors.blueGrey; break;
      case 'Деталь': color = Colors.indigo; break;
      case 'Готовая продукция': color = Colors.green; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color,
        fontSize: 11, fontWeight: FontWeight.w600)));
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}
