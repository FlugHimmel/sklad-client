import 'package:flutter/material.dart';

import '../models/product.dart';

/// Поле с поиском артикула "на лету".
/// Начинаешь вводить — показывает подсказки. Клик по подсказке — выбирает.
/// Поиск по любому вхождению в артикул или название.
class ProductSearchField extends StatefulWidget {
  final List<Product> products;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;
  final String? hintText;
  final bool dense;

  const ProductSearchField({
    super.key,
    required this.products,
    required this.value,
    required this.onChanged,
    this.label = 'Артикул',
    this.hintText,
    this.dense = false,
  });

  @override
  State<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _link = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlay;
  double _fieldWidth = 0;

  @override
  void initState() {
    super.initState();
    _syncText();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ProductSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _syncText();
  }

  void _syncText() {
    final p = widget.products.where((x) => x.id == widget.value).firstOrNull;
    final newText = p?.article ?? '';
    if (_ctrl.text != newText) _ctrl.text = newText;
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _openSuggestions();
    } else {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focus.hasFocus) _closeSuggestions();
      });
    }
  }

  List<Product> _filteredProducts() {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products.take(30).toList();
    return widget.products
        .where((p) =>
            p.article.toLowerCase().contains(q) ||
            p.name.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  void _openSuggestions() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _fieldWidth = box.size.width;

    _overlay = OverlayEntry(builder: (ctx) {
      final items = _filteredProducts();
      return Positioned(
        width: _fieldWidth > 0 ? _fieldWidth : 320,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Ничего не найдено',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final p = items[i];
                        return ListTile(
                          dense: true,
                          title: Text(p.article,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          subtitle: Text(p.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _ctrl.text = p.article;
                            widget.onChanged(p.id);
                            _closeSuggestions();
                            _focus.unfocus();
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _closeSuggestions() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _closeSuggestions();
    _focus.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _fieldWidth = constraints.maxWidth;
          return TextField(
            key: _fieldKey,
            controller: _ctrl,
            focusNode: _focus,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText ?? 'Начните вводить артикул или название',
              border: const OutlineInputBorder(),
              isDense: widget.dense,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: widget.value != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        widget.onChanged(null);
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onTap: _openSuggestions,
            onChanged: (_) {
              if (_overlay == null) _openSuggestions();
              _overlay?.markNeedsBuild();
              final exact = widget.products
                  .where((p) =>
                      p.article.toLowerCase() ==
                      _ctrl.text.trim().toLowerCase())
                  .firstOrNull;
              if (exact != null && exact.id != widget.value) {
                widget.onChanged(exact.id);
              }
              setState(() {});
            },
          );
        },
      ),
    );
  }
}
