import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/shipment_repo.dart';
import '../scanner/scanner_screen.dart';

/// Экран сканирующей отгрузки.
///
/// Кладовщик сканирует все тары, которые уходят со склада,
/// затем нажимает одну большую кнопку — содержимое списывается,
/// тары полностью удаляются из системы.
class ShipmentScanScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionVerb;

  const ShipmentScanScreen({
    super.key,
    this.title = 'Отгрузка сканом',
    this.subtitle =
        'Сканируйте тары. После нажатия кнопки они спишутся со склада и исчезнут.',
    this.actionVerb = 'ОТГРУЗИТЬ',
  });

  @override
  State<ShipmentScanScreen> createState() => _ShipmentScanScreenState();
}

class _Scanned {
  final String code;
  final int? id;
  final String? productArticle;
  final String? productName;
  final String? quantity;
  final String? warehouseName;
  final String? status;
  final String? error;
  _Scanned({
    required this.code,
    this.id,
    this.productArticle,
    this.productName,
    this.quantity,
    this.warehouseName,
    this.status,
    this.error,
  });
}

class _ShipmentScanScreenState extends State<ShipmentScanScreen> {
  final _codeCtrl = TextEditingController();
  final List<_Scanned> _scanned = [];
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    await _addByCode(code);
  }

  Future<void> _addByCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (_scanned.any((s) => s.code == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тара $code уже в списке')),
      );
      _codeCtrl.clear();
      return;
    }
    if (code.startsWith('PART:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Это ШК детали, а не тары')),
      );
      _codeCtrl.clear();
      return;
    }

    setState(() => _scanned.add(_Scanned(code: code, error: 'проверяется...')));
    _codeCtrl.clear();
    try {
      final resp = await context
          .read<ApiClient>()
          .get('/api/containers/by-code/', query: {'code': code});
      final data = resp as Map<String, dynamic>;
      final lines = (data['lines'] ?? []) as List;
      final first =
          lines.isNotEmpty ? lines.first as Map<String, dynamic> : null;
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == code);
        if (idx == -1) return;
        _scanned[idx] = _Scanned(
          code: code,
          id: data['id'] as int?,
          productArticle:
              (data['product_article'] ?? first?['product_article'] ?? '')
                  .toString(),
          productName:
              (data['product_name'] ?? first?['product_name'] ?? '').toString(),
          quantity: (data['quantity'] ?? first?['quantity'] ?? '0').toString(),
          warehouseName: (data['warehouse_name'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _scanned.indexWhere((s) => s.code == code);
        if (idx == -1) return;
        _scanned[idx] = _Scanned(code: code, error: 'не найдена');
      });
    }
  }

  bool get _canShip {
    if (_busy) return false;
    final valid = _scanned.where((s) => s.id != null && s.error == null).toList();
    if (valid.isEmpty) return false;
    // Все валидные должны быть в статусе "warehouse".
    return valid.every((s) => (s.status ?? '') == 'warehouse');
  }

  Future<void> _doShip() async {
    final codes = _scanned
        .where((s) => s.id != null && s.error == null)
        .map((s) => s.code)
        .toList();
    if (codes.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отгрузить всё?'),
        content: Text(
          'Будет отгружено тар: ${codes.length}.\n\n'
          'Содержимое спишется со склада, а сами тары исчезнут '
          'из системы. Отменить нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.local_shipping),
            label: const Text('Отгрузить'),
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade700),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final res = await ShipmentRepo(context.read<ApiClient>()).bulkShipDelete(
        codes: codes,
        comment: 'Сканирующая отгрузка',
      );
      if (!mounted) return;

      final msg = StringBuffer()
        ..writeln('Отгружено тар: ${res.shipped.length}')
        ..writeln('Не найдено: ${res.notFound.length}')
        ..writeln('Пропущено: ${res.skipped.length}')
        ..writeln('Ошибок: ${res.errors.length}');
      if (res.notFound.isNotEmpty) {
        msg.writeln();
        msg.writeln('Не найдено: ${res.notFound.join(", ")}');
      }
      if (res.skipped.isNotEmpty) {
        msg.writeln();
        for (final s in res.skipped) {
          msg.writeln('${s['code']}: ${s['reason']}');
        }
      }
      if (res.errors.isNotEmpty) {
        msg.writeln();
        for (final e in res.errors) {
          msg.writeln('${e['code']}: ${e['error']}');
        }
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Готово'),
          content: SingleChildScrollView(child: Text(msg.toString())),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      // Убираем из списка только успешно отгруженные
      final shippedCodes = res.shipped
          .map((e) => (e['code'] ?? '').toString())
          .toSet();
      setState(() {
        _scanned.removeWhere((s) => shippedCodes.contains(s.code));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _scanned.where((s) => s.id != null && s.error == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} ($valid)'),
        actions: [
          if (_scanned.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Очистить список',
              onPressed: () => setState(_scanned.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.deepOrange.shade50,
            child: Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    onSubmitted: _addByCode,
                    decoration: const InputDecoration(
                      hintText: 'Код тары (TARA-XXXXXX)',
                      prefixIcon: Icon(Icons.qr_code_2),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить',
                  onPressed: () => _addByCode(_codeCtrl.text),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Сканировать',
                  onPressed: _scan,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
          if (_scanned.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _canShip ? _doShip : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.local_shipping, size: 22),
                  label: Text(
                    _busy ? 'Работаю...' : '${widget.actionVerb} ВСЁ ($valid)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.indigo.shade700,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_scanned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Сканируйте тары одну за другой',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'Отсканировали все? — жмите большую кнопку внизу.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _scanned.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = _scanned[i];
        final ok = s.error == null && s.id != null;
        final onWh = (s.status ?? '') == 'warehouse';
        Color avColor;
        IconData avIcon;
        if (!ok) {
          avColor = Colors.red;
          avIcon = Icons.close;
        } else if (!onWh) {
          avColor = Colors.orange;
          avIcon = Icons.warning_amber;
        } else {
          avColor = Colors.green;
          avIcon = Icons.check;
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avColor,
            child: Icon(avIcon, color: Colors.white),
          ),
          title: Text(
            s.code,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'monospace'),
          ),
          subtitle: ok
              ? Text(
                  '${s.productArticle ?? ''} · ${s.productName ?? ''}\n'
                  'Склад: ${s.warehouseName ?? '?'} · ${s.quantity ?? '?'} шт',
                  style: const TextStyle(fontSize: 12),
                )
              : Text(
                  s.error ?? '—',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
          isThreeLine: ok,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _scanned.removeAt(i)),
          ),
        );
      },
    );
  }
}
