import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Помощь'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Проверить сервер',
            onPressed: () => _pingServer(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _header(),
          const SizedBox(height: 16),
          _sectionTitle('Что делать если...', Colors.red.shade700),
          _faqItem(
            '🔴 Красная ошибка / белый экран',
            'Жми Ctrl+Shift+R. Если не помогло — F12 → Application → '
                'Service Workers → Unregister, потом Storage → Clear site data, '
                'потом F5.',
          ),
          _faqItem(
            '🔴 Всё тормозит, кнопки не жмутся',
            'Смотри на баннер сверху «Данные обновились» — жми «Обновить». '
                'Или перезагрузи страницу.',
          ),
          _faqItem(
            '🔴 Не создаётся операция, пишет ошибку',
            'Прочитай текст ошибки — обычно там написано что не так. '
                'Например: «В таре только 50, а списать 100». Исправь в форме.',
          ),
          _faqItem(
            '🔴 Не могу найти тару',
            'Жми СКАН (на главной или в Производстве) → веди по ШК. '
                'Или в разделе «Тара» используй поиск.',
          ),
          _faqItem(
            '🟡 Забыл пароль',
            'Только админ может сбросить. Открой «Пользователи» → найди себя → '
                'сбросить пароль. Или через терминал (см. ниже).',
          ),
          _faqItem(
            '🟡 Случайно сделал неправильную операцию',
            'В «Производстве» → тапни на тару → История → найди операцию → '
                'Откатить. Все тары вернутся как было.',
          ),
          _faqItem(
            '🟡 Хочу начать с чистого листа (стереть тесты)',
            'Опасная зона → СБРОСИТЬ ВСЁ. Останутся номенклатура, пользователи, '
                'склады, реквизиты. Уйдут тары, движения, заказы, операции.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('Сервер', Colors.blue.shade700),
          _infoCard(
            'Сейчас подключён',
            api.baseUrl ?? '—',
          ),
          const SizedBox(height: 8),
          _infoCard(
            'Проверить работу',
            'Нажми иконку 🔄 в правом верхнем углу — покажет результат.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('Если ничего не помогло', Colors.orange.shade800),
          _commandBlock(
            'Логи сервера (последние 50 строк с ошибкой):',
            'sudo journalctl -u sklad -n 80 --no-pager | grep -A 40 "Traceback"',
          ),
          _commandBlock(
            'Статус сервера (работает или упал):',
            'sudo systemctl status sklad --no-pager | head -5',
          ),
          _commandBlock(
            'Перезапустить сервер (если завис):',
            'sudo systemctl restart sklad',
          ),
          const SizedBox(height: 8),
          _infoCard(
            'Как чинить ошибки',
            'Нашёл Traceback → скопируй его целиком → отправь разработчику '
                '(в чат с ИИ-ассистентом). Он поправит.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('Настройка бэкапов', Colors.green.shade800),
          _infoCard(
            'Если ещё не настроено',
            'Скажи разработчику «настрой бэкапы по крону». Он добавит '
                'ежедневный бэкап БД в /opt/sklad/backups/.',
          ),
          _commandBlock(
            'Проверить, что бэкапы есть:',
            'ls -la /opt/sklad/backups/ | tail -5',
          ),
          const SizedBox(height: 20),
          _sectionTitle('Контакты', Colors.purple.shade700),
          _infoCard(
            'Разработчик',
            'Отправляй проблемы в чат с ИИ-ассистентом. Прикладывай вывод '
                'команд выше — так быстрее.',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(children: [
        Icon(Icons.help_outline, color: Colors.indigo.shade800, size: 32),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Шпаргалка на каждый день',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text(
                'Что делать если что-то не работает. '
                'Все команды — копировать и вставлять в терминал на сервере.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(question,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer,
              style: const TextStyle(fontSize: 13.5, height: 1.4)),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.35,
                  fontFamily:
                      text.contains('\n') ? 'monospace' : null)),
        ],
      ),
    );
  }

  Widget _commandBlock(String label, String command) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  command,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                      height: 1.3),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy,
                    size: 18, color: Colors.white70),
                tooltip: 'Копировать',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pingServer(BuildContext context) async {
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Проверяю сервер...'),
      duration: Duration(seconds: 1),
    ));
    try {
      await api.get('/api/operations/meta/');
      messenger.showSnackBar(const SnackBar(
        content: Text('✅ Сервер работает'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Сервер не отвечает: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}
