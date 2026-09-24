import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/container.dart';
import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../services/containers_repo.dart';
import '../../services/products_repo.dart';
import '../containers/container_detail_screen.dart';
import '../containers/container_transfer_screen.dart';
import '../containers/containers_list_screen.dart';
import '../production/operation_form_screen.dart';
import '../scanner/scanner_screen.dart';

class UniversalScanScreen extends StatefulWidget {
  const UniversalScanScreen({super.key});
  @override
  State<UniversalScanScreen> createState() => _UniversalScanScreenState();
}

class _UniversalScanScreenState extends State<UniversalScanScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    final trimmed = code.trim();

    setState(() => _busy = true);
    try {
      // PART:XXXX → деталь из этикетки тары литья
      if (trimmed.toUpperCase().startsWith('PART:')) {
        final article = trimmed.substring(5).trim();
        await _openPartByArticle(article);
        return;
      }
      // Иначе считаем, что это код тары
      await _openContainerByCode(trimmed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPartByArticle(String article) async {
    try {
      final page = await ProductsRepo(context.read<ApiClient>())
          .list(search: article, productType: 'part', page: 1);
      final match = page.items
          .where((p) => p.article == article)
          .cast<Product?>()
          .firstWhere((_) => true, orElse: () => null);
      final chosen = match ?? (page.items.isNotEmpty ? page.items.first : null);
      if (chosen == null) {
        if (!mounted) return;
        await _notFound('Деталь с артикулом «$article» не найдена');
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const OperationFormScreen(),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      await _notFound('Ошибка поиска детали: $e');
    }
  }

  Future<void> _openContainerByCode(String code) async {
    StockContainer? c;
    try {
      c = await ContainersRepo(context.read<ApiClient>()).byCode(code);
    } catch (_) {
      c = null;
    }
    if (!mounted) return;
    if (c == null) {
      await _containerNotFound(code);
      return;
    }
    await _showContainerActions(c);
  }

  Future<void> _containerNotFound(String code) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Тара не найдена'),
        content: Text('Код «$code» не зарегистрирован в системе.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ContainersListScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Открыть список тар'),
          ),
        ],
      ),
    );
  }

  Future<void> _notFound(String msg) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Не найдено'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContainerActions(StockContainer c) async {
    final content = c.lines.isEmpty
        ? '—'
        : c.lines.map((l) => '${l.productArticle} × ${l.quantity}').join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.qr_code_2, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.code,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                        Text(
                            '${c.statusDisplay}${c.warehouseName != null ? " · ${c.warehouseName}" : ""}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(content,
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 16),
                if (c.isOnWarehouse) ...[
                  _actionTile(
                    icon: Icons.precision_manufacturing,
                    color: Colors.green,
                    title: 'Произвести деталь',
                    subtitle: 'Взять из этой тары и сделать партию',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OperationFormScreen(
                                  sourceContainer: c,
                                )),
                      );
                    },
                  ),
                  _actionTile(
                    icon: Icons.swap_horiz,
                    color: Colors.indigo,
                    title: 'Переместить между складами',
                    subtitle: 'Открыть экран перемещения с этой тарой',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ContainerTransferScreen(
                                  prefillCode: c!.code,
                                )),
                      );
                    },
                  ),
                ],
                _actionTile(
                  icon: Icons.open_in_new,
                  color: Colors.blueGrey,
                  title: 'Открыть карточку тары',
                  subtitle: 'Содержимое, история, все действия',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ContainerDetailScreen(containerId: c!.id)),
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.print,
                  color: Colors.deepPurple,
                  title: 'Печать этикетки',
                  subtitle: 'Code128 на A4',
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _printLabel(c!.id);
                  },
                ),
                _actionTile(
                  icon: Icons.description,
                  color: Colors.brown,
                  title: 'Печать упаковочного листа',
                  subtitle: 'A4, реквизиты из настроек',
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _printPacking(c!.id);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetCtx),
                  icon: const Icon(Icons.close),
                  label: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _printLabel(int id) async {
    try {
      final bytes = await context
          .read<ApiClient>()
          .getBytes('/api/containers/$id/label-pdf/');
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'label-$id.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  Future<void> _printPacking(int id) async {
    try {
      final bytes = await context
          .read<ApiClient>()
          .getBytes('/api/containers/$id/packing-list-pdf/');
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'packing-$id.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Скан → Действие'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              const Text(
                'Отсканируйте штрихкод',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Можно сканировать:\n'
                '• ШК тары — увидишь все действия\n'
                '• ШК детали с этикетки тары литья — откроется производство',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text('СКАНИРОВАТЬ',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ContainersListScreen()),
                          );
                        },
                  icon: const Icon(Icons.list),
                  label: const Text('Открыть список тар'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
