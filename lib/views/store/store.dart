import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class _Service {
  final String icon;
  final String name;
  final String desc;
  final String tariff;
  final String? trial;
  final String link;
  const _Service({required this.icon, required this.name, required this.desc, required this.tariff, this.trial, required this.link});
}

const _services = [
  _Service(
    icon: '🍯',
    name: 'HoneyVPN',
    desc: 'VPN через LTE-мосты. Серверы в Нидерландах и Франции. Быстрый обход блокировок даже с мобильного интернета.',
    tariff: '90 ₽ / месяц',
    trial: '3 дня бесплатно',
    link: 'https://t.me/honeyvpnru_bot',
  ),
  _Service(
    icon: '⚡',
    name: 'AlphaVPN',
    desc: 'Надёжный VPN с серверами в Нидерландах, Франции, Германии и США. Без ограничений по скорости.',
    tariff: 'от 90 ₽ / месяц',
    trial: '7 дней бесплатно',
    link: 'https://t.me/alphavpnru_bot',
  ),
];

class StoreView extends StatelessWidget {
  const StoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Витрина VPN'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Выберите подходящий VPN-сервис',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.5)),
          ),
          const SizedBox(height: 12),
          ..._services.map((s) => _ServiceCard(service: s)),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _Service service;
  const _ServiceCard({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(service.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(service.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (service.trial != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(service.trial!, style: TextStyle(fontSize: 11, color: Colors.green.shade300, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),
            Text(service.desc, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.75))),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.payments_outlined, size: 16, color: scheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(service.tariff, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () => launchUrl(Uri.parse(service.link), mode: LaunchMode.externalApplication),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(90, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Перейти'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
