import 'package:flutter/material.dart';

import '../stocks/stocks_screen.dart';
import 'monthly_summary_screen.dart';
import 'production_ops_report_screen.dart';
import 'scrap_ops_report_screen.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_Tile>[
      _Tile(
        icon: Icons.factory,
        title: 'Отчёт по производству',
        subtitle: 'Операции: операторы, артикулы, периоды',
        color: Colors.orange,
        builder: () => const ProductionOpsReportScreen(),
      ),
      _Tile(
        icon: Icons.warning_amber,
        title: 'Отчёт по браку',
        subtitle: 'По причинам, операторам, артикулам',
        color: Colors.red,
        builder: () => const ScrapOpsReportScreen(),
      ),
      _Tile(
        icon: Icons.table_chart,
        title: 'Сводная таблица',
        subtitle: 'По месяцам (движения, приход/расход)',
        color: Colors.blue,
        builder: () => const MonthlySummaryScreen(),
      ),
      _Tile(
        icon: Icons.warehouse,
        title: 'Остатки по складам',
        subtitle: 'Свободный остаток и минимумы',
        color: Colors.teal,
        builder: () => const StocksScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Все отчёты с фильтрами по датам. '
                    'Быстрые кнопки: Сегодня · Неделя · Месяц · Квартал · Год · Свой период.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          ...tiles.map((t) => Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: t.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.icon,
                        color: t.enabled ? t.color : Colors.grey,
                        size: 26),
                  ),
                  title: Text(t.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: t.enabled ? null : Colors.grey)),
                  subtitle: Text(t.subtitle,
                      style: const TextStyle(fontSize: 12.5)),
                  trailing: t.enabled
                      ? const Icon(Icons.arrow_forward)
                      : const Icon(Icons.lock_clock, color: Colors.grey),
                  onTap: t.enabled
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => t.builder()),
                          )
                      : null,
                ),
              )),
        ],
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget Function() builder;
  final bool enabled;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
    this.enabled = true,
  });
}
