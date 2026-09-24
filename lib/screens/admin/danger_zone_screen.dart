import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';

class DangerZoneScreen extends StatefulWidget {
  const DangerZoneScreen({super.key});
  @override
  State<DangerZoneScreen> createState() => _DangerZoneScreenState();
}

class _DangerZoneScreenState extends State<DangerZoneScreen> {
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Точно сбросить?',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Будут удалены ВСЕ:\n'
          '• тары и их история\n'
          '• движения\n'
          '• производственные операции\n'
          '• заказы и их позиции\n'
          '• инвентаризации\n'
          '• журнал изменений\n\n'
          'Останутся: справочник номенклатуры, зависимости, склады, '
          'пользователи, реквизиты.\n\n'
          'Это НЕОБРАТИМО.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (ok1 != true) return;

    // Сбрасываем поле перед показом второго диалога
    _confirmCtrl.clear();

    final ok2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final typed = _confirmCtrl.text.trim().toUpperCase();
            final valid = typed == 'СБРОС';
            return AlertDialog(
              title: const Text('Последнее подтверждение',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Введите слово СБРОС в поле ниже и нажмите ОК.\n'
                    'Регистр не важен — можно строчными.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmCtrl,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'сброс',
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: valid ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    onChanged: (_) => setLocal(() {}),
                    onSubmitted: (_) {
                      if (valid) Navigator.pop(dialogCtx, true);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        valid ? Icons.check_circle : Icons.info_outline,
                        size: 18,
                        color: valid ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          valid
                              ? 'Слово введено верно — можно сбрасывать.'
                              : 'Введите ровно «СБРОС» (регистр не важен).',
                          style: TextStyle(
                            fontSize: 13,
                            color: valid
                                ? Colors.green.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: valid ? Colors.red : Colors.grey.shade400,
                  ),
                  onPressed: valid
                      ? () => Navigator.pop(dialogCtx, true)
                      : null,
                  child: const Text('СБРОСИТЬ'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok2 != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final resp = await context.read<ApiClient>().post(
            '/api/admin/reset-data/',
            body: {'confirm': 'СБРОС', 'keep_warehouses': true},
          );
      if (!mounted) return;
      setState(() => _result =
          (resp as Map<String, dynamic>)['deleted'] as Map<String, dynamic>?);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Опасная зона'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade900, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('ПОЛНЫЙ СБРОС ДАННЫХ',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      )),
                ),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Удаляет всё оперативное: тары, движения, заказы, '
                'производство, инвентаризации, журнал изменений.\n\n'
                'Оставляет только номенклатуру, зависимости, склады, '
                'пользователей и реквизиты.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: _busy ? null : _reset,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_forever, size: 28),
            label: const Text('СБРОСИТЬ ВСЁ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Ошибка: $_error',
                style: TextStyle(color: Colors.red.shade900)),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Сброс выполнен. Удалено:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                ..._result!.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 13)),
                    )),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}
