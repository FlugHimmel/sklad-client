import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'admin/danger_zone_screen.dart';
import 'audit/audit_log_screen.dart';
import 'containers/container_bulk_create_screen.dart';
import 'containers/container_revision_screen.dart';
import 'containers/container_state_screen.dart';
import 'containers/container_transfer_screen.dart';
import 'containers/containers_list_screen.dart';
import 'containers/container_create_screen.dart';
import 'dependencies/dependencies_screen.dart';
import 'help/help_screen.dart';
import 'inventory/inventory_list_screen.dart';
import 'login_screen.dart';
import 'movements/manual_movement_screen.dart';
import 'movements/movements_screen.dart';
import 'orders/orders_list_screen.dart';
import 'production/production_screen_v2.dart';
import 'products/products_list_screen.dart';
import 'reports/ready_to_ship_report_screen.dart';
import 'reports/reports_hub_screen.dart';
import 'settings/company_settings_screen.dart';
import 'shipment/shipment_screen.dart';
import 'shipment/shipment_scan_screen.dart';
import 'shipment/shipping_docs_screen.dart';
import 'shipment/shipment_notes_history_screen.dart';
import 'universal/universal_scan_screen.dart';
import 'users/users_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final api = context.read<ApiClient>();
    final user = auth.user ?? const <String, dynamic>{};

    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final displayName =
        fullName.isNotEmpty ? fullName : (user['username'] ?? '—').toString();
    final role = (user['role'] ?? 'user').toString();
    final isAdmin = role == 'admin' || user['is_superuser'] == true;
    final isFoundry = role == 'foundry';

    final tiles = <Widget>[];

    if (isFoundry) {
      tiles.addAll([
        _MenuTile(
          icon: Icons.add_box, title: 'Создать тару',
          subtitle: 'Литьё на склад Завод',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainerCreateScreen())),
        ),
        _MenuTile(
          icon: Icons.description, title: 'Подготовить отгрузку',
          subtitle: 'Накладная + упаковочные листы',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ShippingDocsScreen())),
        ),
        _MenuTile(
          icon: Icons.history, title: 'История накладных',
          subtitle: 'Все отгрузки',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ShipmentNotesHistoryScreen())),
        ),
        _MenuTile(
          icon: Icons.qr_code, title: 'Мои тары',
          subtitle: 'Список созданных',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainersListScreen())),
        ),
        _MenuTile(
          icon: Icons.print, title: 'Реквизиты печати',
          subtitle: 'Что печатать на листах',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const CompanySettingsScreen())),
        ),
        _MenuTile(
          icon: Icons.help_outline, title: 'Помощь',
          subtitle: 'Что делать если что-то сломалось',
          color: Colors.indigo,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
      ]);
    } else {
      tiles.addAll([
        _MenuTile(
          icon: Icons.qr_code, title: 'Тара',
          subtitle: 'Все тары + сканер',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainersListScreen())),
        ),
        _MenuTile(
          icon: Icons.bolt, title: 'Производство',
          subtitle: 'Взял → Положил. Без партий.',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ProductionScreenV2())),
        ),
        _MenuTile(
          icon: Icons.playlist_add_check, title: 'Ревизия',
          subtitle: 'Занести что лежит в тарах',
          color: Colors.teal,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainerRevisionScreen())),
        ),
        _MenuTile(
          icon: Icons.inventory, title: 'Состояние тары',
          subtitle: 'Упакована / не упакована',
          color: Colors.lightGreen,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainerStateScreen())),
        ),
        _MenuTile(
          icon: Icons.inventory, title: 'Готово к отгрузке',
          subtitle: 'Упаковано и ждёт отправки',
          color: Colors.green,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ReadyToShipReportScreen())),
        ),
        _MenuTile(
          icon: Icons.local_shipping, title: 'Отгрузка сканом',
          subtitle: 'Скан тар → списать и удалить',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ShipmentScanScreen())),
        ),
        _MenuTile(
          icon: Icons.call_received, title: 'Приёмка от Завода',
          subtitle: 'Завод → Цех (MAIN) с накладной',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ShipmentScreen(
                      title: 'Приёмка от Завода',
                      subtitle: 'Завод / Литейка  →  Основной склад',
                      fromWarehouseCode: 'ZLK',
                      toWarehouseCode: 'MAIN',
                      actionVerb: 'ПРИНЯТЬ',
                      askPrintNote: true,
                    ))),
        ),
        _MenuTile(
          icon: Icons.receipt_long, title: 'Заказы',
          subtitle: 'План и выполнение',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OrdersListScreen())),
        ),
        _MenuTile(
          icon: Icons.add_box_outlined, title: 'Создать болванки',
          subtitle: 'Пустые тары для ШК',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainerBulkCreateScreen())),
        ),
        _MenuTile(
          icon: Icons.bar_chart, title: 'Отчёты',
          subtitle: 'Производство · Брак · Сводная · Остатки',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReportsHubScreen())),
        ),
        _MenuTile(
          icon: Icons.inventory_2, title: 'Справочник',
          subtitle: 'Номенклатура',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductsListScreen())),
        ),
        _MenuTile(
          icon: Icons.account_tree, title: 'Зависимости',
          subtitle: 'Отливка → детали',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DependenciesScreen())),
        ),
        _MenuTile(
          icon: Icons.swap_horiz, title: 'Перемещение',
          subtitle: 'Между складами',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ContainerTransferScreen())),
        ),
        _MenuTile(
          icon: Icons.history, title: 'История накладных',
          subtitle: 'Отгрузки Завод → Модель',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ShipmentNotesHistoryScreen())),
        ),
        _MenuTile(
          icon: Icons.compare_arrows, title: 'Приход / Расход',
          subtitle: 'Вручную, без тары',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ManualMovementScreen())),
        ),
        _MenuTile(
          icon: Icons.history, title: 'История склада',
          subtitle: 'Что пришло / ушло, с фильтрами',
          color: Colors.indigo,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const MovementsScreen())),
        ),
        _MenuTile(
          icon: Icons.fact_check, title: 'Инвентаризация',
          subtitle: 'Пересчёт остатков',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InventoryListScreen())),
        ),
        _MenuTile(
          icon: Icons.help_outline, title: 'Помощь',
          subtitle: 'Что делать если что-то сломалось',
          color: Colors.indigo,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        if (isAdmin)
          _MenuTile(
            icon: Icons.history_edu, title: 'Журнал изменений',
            subtitle: 'Кто, что, когда поменял',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AuditLogScreen())),
          ),
        if (isAdmin)
          _MenuTile(
            icon: Icons.people, title: 'Пользователи',
            subtitle: 'Создание / права / пароли',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UsersListScreen())),
          ),
        if (isAdmin)
          _MenuTile(
            icon: Icons.dangerous, title: 'Опасная зона',
            subtitle: 'Полный сброс данных',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DangerZoneScreen())),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isFoundry ? 'Литейка' : 'Складской учёт'),
      ),
      drawer: _buildDrawer(context, auth, displayName, isAdmin, isFoundry),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final maxContentW = w >= 1400 ? 1360.0 : (w >= 900 ? 1100.0 : w);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentW),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Привет, $displayName!',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Роль: ${isAdmin ? 'Администратор' : (isFoundry ? 'Литейка' : 'Пользователь')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 64,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const UniversalScanScreen()),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 28),
                        label: const Text('СКАНИРОВАТЬ ШТРИХКОД',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Разделы',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: _columnsFor(w),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: _ratioFor(w),
                      children: tiles,
                    ),
                    const SizedBox(height: 30),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Подпись автора внизу главной.
  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: InkWell(
          onTap: () async {
            final uri = Uri(
              scheme: 'mailto',
              path: 'csgofix123@mail.ru',
              query: 'subject=Складской учёт',
            );
            try {
              await launchUrl(uri, mode: LaunchMode.platformDefault);
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Разработал FlugHimmel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.email_outlined, size: 14,
                    color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'csgofix123@mail.ru',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _columnsFor(double w) {
    if (w >= 1300) return 6;
    if (w >= 1000) return 5;
    if (w >= 760) return 4;
    if (w >= 520) return 3;
    return 2;
  }

  double _ratioFor(double w) {
    if (w >= 1000) return 1.9;
    if (w >= 760) return 1.8;
    if (w >= 520) return 1.7;
    return 1.55;
  }

  Drawer _buildDrawer(BuildContext context, AuthService auth,
      String displayName, bool isAdmin, bool isFoundry) {
    final items = <Widget>[
      ListTile(
        leading: const Icon(Icons.dashboard),
        title: const Text('Главная'),
        selected: true,
        onTap: () => Navigator.pop(context),
      ),
      const Divider(),
    ];

    if (isFoundry) {
      items.addAll([
        _nav(context, Icons.add_box, 'Создать тару',
            () => const ContainerCreateScreen(),
            subtitle: 'Литьё на склад Завод'),
        _nav(context, Icons.description, 'Подготовить отгрузку',
            () => const ShippingDocsScreen(),
            subtitle: 'Накладная и упаковочные листы'),
        _nav(context, Icons.history, 'История накладных',
            () => const ShipmentNotesHistoryScreen(),
            subtitle: 'Все отгрузки'),
        _nav(context, Icons.qr_code, 'Мои тары',
            () => const ContainersListScreen()),
        const Divider(),
        _nav(context, Icons.print, 'Реквизиты для печати',
            () => const CompanySettingsScreen()),
        _nav(context, Icons.help_outline, 'Помощь',
            () => const HelpScreen(),
            subtitle: 'Что делать если что-то сломалось'),
      ]);
    } else {
      items.addAll([
        _nav(context, Icons.qr_code_scanner, 'Скан → Действие',
            () => const UniversalScanScreen(),
            subtitle: 'Сканировать ШК тары или детали'),
        _nav(context, Icons.qr_code, 'Тара',
            () => const ContainersListScreen()),
        _nav(context, Icons.bolt, 'Производство',
            () => const ProductionScreenV2(),
            subtitle: 'Взял → Положил. Без партий.'),
        _nav(context, Icons.playlist_add_check, 'Ревизия',
            () => const ContainerRevisionScreen(),
            subtitle: 'Занести что лежит в тарах'),
        _nav(context, Icons.inventory, 'Состояние тары',
            () => const ContainerStateScreen(),
            subtitle: 'Упакована / не упакована'),
        _nav(context, Icons.inventory, 'Готово к отгрузке',
            () => const ReadyToShipReportScreen(),
            subtitle: 'Упаковано и ждёт отправки'),
        _nav(context, Icons.local_shipping, 'Отгрузка сканом',
            () => const ShipmentScanScreen(),
            subtitle: 'Скан тар → списать и удалить'),
        _nav(context, Icons.call_received, 'Приёмка от Завода',
            () => const ShipmentScreen(
                  title: 'Приёмка от Завода',
                  subtitle: 'Завод / Литейка  →  Основной склад',
                  fromWarehouseCode: 'ZLK',
                  toWarehouseCode: 'MAIN',
                  actionVerb: 'ПРИНЯТЬ',
                  askPrintNote: true,
                ),
            subtitle: 'Партия с накладной'),
        _nav(context, Icons.receipt_long, 'Заказы',
            () => const OrdersListScreen()),
        _nav(context, Icons.add_box_outlined, 'Создать болванки',
            () => const ContainerBulkCreateScreen(),
            subtitle: 'Пустые тары для ШК'),
        _nav(context, Icons.bar_chart, 'Отчёты',
            () => const ReportsHubScreen(),
            subtitle: 'Производство · Брак · Сводная · Остатки'),
        _nav(context, Icons.inventory_2, 'Справочник',
            () => const ProductsListScreen()),
        _nav(context, Icons.account_tree, 'Зависимости',
            () => const DependenciesScreen(), subtitle: 'Отливка → детали'),
        _nav(context, Icons.swap_horiz, 'Перемещение между складами',
            () => const ContainerTransferScreen()),
        _nav(context, Icons.history, 'История накладных',
            () => const ShipmentNotesHistoryScreen(),
            subtitle: 'Отгрузки Завод → Модель'),
        _nav(context, Icons.compare_arrows, 'Приход / Расход',
            () => const ManualMovementScreen(),
            subtitle: 'Вручную, без тары'),
        _nav(context, Icons.history, 'История склада',
            () => const MovementsScreen(),
            subtitle: 'Что пришло / ушло за период'),
        _nav(context, Icons.fact_check, 'Инвентаризация',
            () => const InventoryListScreen(),
            subtitle: 'Пересчёт остатков на складе'),
        _nav(context, Icons.help_outline, 'Помощь',
            () => const HelpScreen(),
            subtitle: 'Что делать если что-то сломалось'),
        const Divider(),
        _nav(context, Icons.print, 'Реквизиты для печати',
            () => const CompanySettingsScreen()),
        if (isAdmin)
          _nav(context, Icons.history_edu, 'Журнал изменений',
              () => const AuditLogScreen(),
              subtitle: 'Кто, что, когда и как поменял'),
        if (isAdmin)
          _nav(context, Icons.people, 'Пользователи',
              () => const UsersListScreen(),
              subtitle: 'Создание / права / пароли'),
        if (isAdmin)
          _nav(context, Icons.dangerous, 'Опасная зона',
              () => const DangerZoneScreen(),
              subtitle: 'Полный сброс данных'),
      ]);
    }

    items.add(ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text('Выйти'),
      onTap: () async {
        await auth.logout();
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
    ));

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(displayName),
            accountEmail: Text(
              isAdmin
                  ? 'Администратор'
                  : (isFoundry ? 'Литейка' : 'Пользователь'),
            ),
            currentAccountPicture:
                const CircleAvatar(child: Icon(Icons.person, size: 32)),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, IconData icon, String title,
      Widget Function() builder, {String? subtitle}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final iconColor = enabled
        ? (color ?? Theme.of(context).colorScheme.primary)
        : Colors.grey;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: enabled ? null : Colors.grey)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
