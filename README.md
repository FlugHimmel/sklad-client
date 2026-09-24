# Склад — клиент (Flutter Web)

Веб-клиент для системы складского учёта. Backend — Django + DRF
(отдельный репозиторий: sklad-backend).

## Что внутри

* **Тары** — список с фильтрами, карточка, наполнение, перемещение.
* **Операции** — ввод постфактум: взял из тар → положил → брак.
* **Накладные** — подготовка отгрузки, история.
* **Отчёты** — производство, брак, готово к отгрузке, сводная по месяцам.
* **Номенклатура** — справочник с алиасами (старый → главный).
* **Заказы** — план/факт, импорт из Excel.
* **Настройки** — реквизиты для PDF, опасная зона, аудит.

## Стек

Flutter (stable) · Provider · http · Flutter Web.

## Запуск (dev)

    flutter pub get
    flutter run -d chrome

URL сервера — в lib/config.dart.

## Сборка в прод

    flutter build web --release
    sudo rsync -a --delete build/web/ /var/www/sklad-client/
    sudo chown -R www-data:www-data /var/www/sklad-client

## Структура

    lib/
    ├── models/        — модели
    ├── screens/       — экраны
    │   ├── containers/     — тары
    │   ├── production/     — операции
    │   ├── shipment/       — накладные
    │   ├── reports/        — отчёты
    │   ├── products/       — номенклатура
    │   ├── orders/         — заказы
    │   ├── settings/       — настройки
    │   ├── users/          — пользователи
    │   └── admin/          — опасная зона
    ├── services/      — API-клиенты
    ├── widgets/       — виджеты
    └── config.dart    — URL сервера

## Лицензия

MIT. См. LICENSE.
