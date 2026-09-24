import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/products_repo.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ProductsRepo get _repo => ProductsRepo(context.read<ApiClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _repo.get(widget.productId);
      if (!mounted) return;
      setState(() => _product = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    if (_product == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: _product)),
    );
    if (changed == true) {
      _dirty = true;
      await _load();
    }
  }

  Future<void> _toggleActive() async {
    if (_product == null) return;
    final p = _product!;
    final action = p.isActive ? 'деактивировать' : 'активировать';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text('Вы уверены, что хотите $action «${p.article}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (p.isActive) {
        await _repo.deactivate(p.id);
      } else {
        await _repo.activate(p.id);
      }
      _dirty = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _delete() async {
    if (_product == null) return;
    final p = _product!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить артикул?'),
        content: Text(
          'Артикул «${p.article}» будет удалён навсегда.\n\n'
          'Если он где-то используется (в спецификации, таре, движении, заказе) — '
          'удаление не пройдёт. В этом случае используйте «Деактивировать».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(p.id);
      if (!mounted) return;
      _dirty = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Артикул удалён')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось удалить: $e\n'
            'Скорее всего, артикул используется. Попробуйте «Деактивировать».',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_product?.article ?? 'Артикул'),
          actions: [
            if (_product != null) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _edit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить',
                onPressed: _delete,
              ),
            ],
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    final p = _product!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(p.productTypeDisplay),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    if (!p.isActive)
                      const Chip(
                        label: Text('НЕАКТИВЕН'),
                        backgroundColor: Colors.redAccent,
                        labelStyle: TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoTile('Артикул', p.article),
        _InfoTile('Ед. изм.', p.uomDisplay),
        _InfoTile('Вес единицы', '${p.weightKg} кг (${p.weightG} г)'),
        _InfoTile('Мин. остаток', '${p.minStock} ${p.uomDisplay}'),
        if (p.productType == 'casting') ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Варианты мех. обработки',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _IdTile('МО слот 1', p.mo1),
          _IdTile('МО слот 2', p.mo2),
          _IdTile('МО слот 3', p.mo3),
          _IdTile('МО слот 4', p.mo4),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _toggleActive,
          icon: Icon(p.isActive ? Icons.block : Icons.check_circle),
          label: Text(p.isActive ? 'Деактивировать' : 'Активировать'),
          style: OutlinedButton.styleFrom(
            foregroundColor: p.isActive ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
    );
  }
}

class _IdTile extends StatelessWidget {
  final String label;
  final int? value;
  const _IdTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(
        value == null ? '—' : '#$value',
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
    );
  }
}
