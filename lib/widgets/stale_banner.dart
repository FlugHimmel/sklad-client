import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_watcher.dart';

/// Тихий автообновлятор. Не показывает полосу — только всплывающий тост
/// в правом верхнем углу на 2 секунды.
///
/// Поведение:
///   * Если autoRefresh включён (по умолчанию) — сам вызывает onRefresh
///     и показывает зелёный тост «Данные обновлены».
///   * Если autoRefresh выключен — не дёргает экран, вместо тоста
///     показывается маленькая полоса «Данные могли обновиться [Обновить]»
///     с чекбоксом, чтобы включить авто.
///
/// Ставится первым виджетом в Column body любого списочного экрана.
class StaleBanner extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const StaleBanner({super.key, required this.onRefresh});

  @override
  State<StaleBanner> createState() => _StaleBannerState();
}

class _StaleBannerState extends State<StaleBanner> {
  bool _pending = false;

  Future<void> _doRefresh({bool silent = false}) async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await widget.onRefresh();
      if (!mounted) return;
      context.read<DataWatcher>().markFresh();
      if (!silent) _showToast();
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _showToast() {
    if (!mounted) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 60,
        right: 20,
        child: _Toast(text: 'Данные обновлены'),
      ),
    );
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataWatcher>(
      builder: (context, dw, _) {
        // Данные не устарели — ничего не показываем
        if (!dw.isStale) return const SizedBox.shrink();

        // Авто — просто перезагружаем, без полосы
        if (dw.autoRefresh) {
          if (!_pending) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_pending) _doRefresh();
            });
          }
          return const SizedBox.shrink();
        }

        // Авто выключено — маленькая полоса с кнопкой
        return Material(
          color: Colors.amber.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.sync_problem,
                    color: Colors.amber.shade900, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Данные могли обновиться',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _pending ? null : _doRefresh,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Обновить', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'Включить авто-обновление',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.bolt, size: 18,
                      color: Colors.amber.shade900),
                  onPressed: () => dw.setAutoRefresh(true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Всплывающий тост в правом верхнем углу.
class _Toast extends StatefulWidget {
  final String text;
  const _Toast({required this.text});
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: Colors.green.shade600,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
