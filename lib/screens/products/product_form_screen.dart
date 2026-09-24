import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/products_repo.dart';
import '../../widgets/product_search_field.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _articleCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();

  String _type = 'part';
  String _uom = 'pcs';
  bool _isActive = true;

  // 8 слотов Mo
  int? _mo1, _mo2, _mo3, _mo4, _mo5, _mo6, _mo7, _mo8;

  // Дубли
  int? _aliasOf;
  String? _aliasOfArticle;
  String? _aliasOfName;
  List<ProductAlias> _aliases = [];

  bool _saving = false;
  bool _aliasBusy = false;
  List<Product> _partOptions = [];
  bool _loadingParts = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _articleCtrl.text = p.article;
      _nameCtrl.text = p.name;
      _weightCtrl.text = p.weightG;
      _minStockCtrl.text = p.minStock;
      _type = p.productType;
      _uom = p.uom;
      _isActive = p.isActive;
      _mo1 = p.mo1;
      _mo2 = p.mo2;
      _mo3 = p.mo3;
      _mo4 = p.mo4;
      _mo5 = p.mo5;
      _mo6 = p.mo6;
      _mo7 = p.mo7;
      _mo8 = p.mo8;
      _aliasOf = p.aliasOf;
      _aliasOfArticle = p.aliasOfArticle;
      _aliasOfName = p.aliasOfName;
      _aliases = List.from(p.aliases);
    }
    if (_type == 'casting') {
      _loadParts();
    }
  }

  @override
  void dispose() {
    _articleCtrl.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  ProductsRepo get _repo => ProductsRepo(context.read<ApiClient>());

  Future<void> _loadParts() async {
    if (_loadingParts) return;
    setState(() => _loadingParts = true);
    try {
      final parts = await _repo.listByType('part');
      if (!mounted) return;
      setState(() => _partOptions = parts);
    } catch (_) {
      // тихо
    } finally {
      if (mounted) setState(() => _loadingParts = false);
    }
  }

  List<(String, String)> get _availableTypes {
    final list = List<(String, String)>.from(kProductTypes);
    final hasCurrent = list.any((t) => t.$1 == _type);
    if (!hasCurrent) {
      list.insert(0, (_type, productTypeDisplay(_type)));
    }
    return list;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'article': _articleCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'product_type': _type,
      'uom': _uom,
      'weight_g': _weightCtrl.text.trim().isEmpty
          ? '0'
          : _weightCtrl.text.trim(),
      'min_stock': _minStockCtrl.text.trim().isEmpty
          ? '0'
          : _minStockCtrl.text.trim(),
      'is_active': _isActive,
      'mo1': _mo1,
      'mo2': _mo2,
      'mo3': _mo3,
      'mo4': _mo4,
      'mo5': _mo5,
      'mo6': _mo6,
      'mo7': _mo7,
      'mo8': _mo8,
    };

    try {
      if (_isEdit) {
        await _repo.update(widget.product!.id, data);
      } else {
        await _repo.create(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Сохранено' : 'Создано')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── ДУБЛИ АРТИКУЛОВ ───────────────────────────────────────────────

  Future<void> _reloadProduct() async {
    if (!_isEdit) return;
    try {
      final fresh = await _repo.get(widget.product!.id);
      if (!mounted) return;
      setState(() {
        _aliasOf = fresh.aliasOf;
        _aliasOfArticle = fresh.aliasOfArticle;
        _aliasOfName = fresh.aliasOfName;
        _aliases = List.from(fresh.aliases);
      });
    } catch (_) {}
  }

  Future<void> _linkAsAlias() async {
    if (!_isEdit) return;
    final picked = await showDialog<Product>(
      context: context,
      builder: (_) => _PickMainProductDialog(
        repo: _repo,
        excludeId: widget.product!.id,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _aliasBusy = true);
    try {
      await _repo.linkAlias(widget.product!.id, mainId: picked.id);
      await _reloadProduct();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Этот артикул теперь дубль: ${picked.article}'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _aliasBusy = false);
    }
  }

  Future<void> _unlinkAlias() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отвязать от главного?'),
        content: Text(
            'Этот артикул сейчас дубль «$_aliasOfArticle». '
            'Отвязать — он снова станет самостоятельным?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _aliasBusy = true);
    try {
      await _repo.unlinkAlias(widget.product!.id);
      await _reloadProduct();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Отвязано — артикул снова самостоятельный'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _aliasBusy = false);
    }
  }

  /// Открыть другой продукт-дубль, чтобы редактировать его.
  Future<void> _openAlias(ProductAlias a) async {
    // Просто закрываем текущий и возвращаем сигнал — родитель откроет
    Navigator.pop(context, {'open_product_id': a.id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование' : 'Новый артикул'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _articleCtrl,
              decoration: const InputDecoration(
                labelText: 'Артикул *',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите артикул' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Наименование *',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Укажите наименование'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Тип *',
                border: OutlineInputBorder(),
              ),
              items: _availableTypes
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _type = v);
                if (v == 'casting' && _partOptions.isEmpty) {
                  _loadParts();
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _uom,
              decoration: const InputDecoration(
                labelText: 'Ед. изм. *',
                border: OutlineInputBorder(),
              ),
              items: kUomOptions
                  .map((u) =>
                      DropdownMenuItem(value: u.$1, child: Text(u.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _uom = v ?? 'pcs'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightCtrl,
              decoration: const InputDecoration(
                labelText: 'Вес единицы, г',
                hintText: 'например 2186',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minStockCtrl,
              decoration: const InputDecoration(
                labelText: 'Мин. остаток',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Активен'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),

            // ДУБЛИ АРТИКУЛОВ — только в режиме редактирования
            if (_isEdit) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Дубли артикула (старые ↔ новые)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _buildAliasSection(),
            ],

            if (_type == 'casting') ...[
              const SizedBox(height: 16),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Слоты МО — детали, которые делаются из этой отливки',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_loadingParts)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _buildMoField('МО слот 1', _mo1,
                    (v) => setState(() => _mo1 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 2', _mo2,
                    (v) => setState(() => _mo2 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 3', _mo3,
                    (v) => setState(() => _mo3 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 4', _mo4,
                    (v) => setState(() => _mo4 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 5', _mo5,
                    (v) => setState(() => _mo5 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 6', _mo6,
                    (v) => setState(() => _mo6 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 7', _mo7,
                    (v) => setState(() => _mo7 = v)),
                const SizedBox(height: 8),
                _buildMoField('МО слот 8', _mo8,
                    (v) => setState(() => _mo8 = v)),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Сохранить' : 'Создать'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAliasSection() {
    final isAlias = _aliasOf != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlias ? Colors.orange.shade50 : Colors.blue.shade50,
        border: Border.all(
            color: isAlias ? Colors.orange.shade300 : Colors.blue.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAlias) ...[
            // Это дубль
            Row(children: [
              Icon(Icons.link, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Этот артикул — ДУБЛЬ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Главный: $_aliasOfArticle${_aliasOfName != null ? " — $_aliasOfName" : ""}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _aliasBusy ? null : _unlinkAlias,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Отвязать от главного'),
            ),
          ] else ...[
            // Это главный
            Row(children: [
              Icon(Icons.star, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Главный артикул',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Всё, что вводится старым артикулом, будет считаться этим.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 8),
            if (_aliases.isEmpty)
              const Text('Дублей пока нет',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ..._aliases.map((a) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link, size: 18,
                        color: Colors.orange),
                    title: Text(a.article,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    subtitle: Text(a.name,
                        style: const TextStyle(fontSize: 11)),
                    trailing: Icon(
                      a.isActive ? Icons.check_circle : Icons.pause_circle,
                      size: 18,
                      color: a.isActive ? Colors.green : Colors.grey,
                    ),
                    onTap: () => _openAlias(a),
                  )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _aliasBusy ? null : _linkAsAlias,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Сделать этот артикул дублем другого'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoField(
      String label, int? value, ValueChanged<int?> onChanged) {
    return ProductSearchField(
      products: _partOptions,
      value: value,
      label: label,
      dense: true,
      onChanged: onChanged,
    );
  }
}

// ─── ДИАЛОГ ВЫБОРА ГЛАВНОГО АРТИКУЛА ───────────────────────────────
class _PickMainProductDialog extends StatefulWidget {
  final ProductsRepo repo;
  final int excludeId;
  const _PickMainProductDialog({
    required this.repo,
    required this.excludeId,
  });

  @override
  State<_PickMainProductDialog> createState() => _PickMainProductDialogState();
}

class _PickMainProductDialogState extends State<_PickMainProductDialog> {
  final _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repo.list(search: q, page: 1);
      if (!mounted) return;
      setState(() {
        _results = page.items
            .where((p) => p.id != widget.excludeId && !p.isAlias)
            .take(50)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(children: [
                const Icon(Icons.star, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Какой артикул главный?',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по артикулу или названию',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _search(v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Ошибка: $_error'))
                      : _results.isEmpty
                          ? const Center(
                              child: Text('Ничего не найдено',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final p = _results[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(p.article,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace')),
                                  subtitle: Text(p.name,
                                      style: const TextStyle(fontSize: 12)),
                                  onTap: () => Navigator.pop(context, p),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
