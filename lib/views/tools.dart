import 'dart:io';

import 'package:honey_utility/common/common.dart';
import 'package:honey_utility/controller.dart';
import 'package:honey_utility/l10n/l10n.dart';
import 'package:honey_utility/providers/providers.dart';
import 'package:honey_utility/views/about.dart';
import 'package:honey_utility/views/application_setting.dart';
import 'package:honey_utility/views/config/config.dart';
import 'package:honey_utility/views/config/general.dart';
import 'package:honey_utility/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import '../state.dart';

class ToolsView extends ConsumerWidget {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );

    final items = [
      // ── Интерфейс ──────────────────────────────────────────────────
      ...generateSection(
        title: context.appLocalizations.settings,
        isFirst: true,
        items: [
          _LocaleItem(),
          const _ThemeItem(),
        ],
      ),

      // ── Приложение ─────────────────────────────────────────────────
      ...generateSection(
        title: context.appLocalizations.application,
        items: [
          if (system.isDesktop) ...[
            const AutoLaunchItem(),
            const SilentLaunchItem(),
          ],
          const MinimizeItem(),
          const AutoRunItem(),
        ],
      ),

      // ── Подключение ────────────────────────────────────────────────
      ...generateSection(
        title: context.appLocalizations.connectivity,
        items: [
          const _RoutingItem(),
          const AllowLanItem(),
        ],
      ),

      // ── Другое ────────────────────────────────────────────────────
      ...generateSection(
        title: context.appLocalizations.other,
        items: [
          const _ResetItem(),
        ],
      ),

      // ── О программе ───────────────────────────────────────────────
      ...generateSection(
        title: context.appLocalizations.about,
        items: [
          const _InfoItem(),
        ],
      ),
    ];

    return CommonScaffold(
      title: context.appLocalizations.tools,
      body: ListView.builder(
        key: toolsStoreKey,
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
        padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) {
    if (locale == null) return context.appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(context.appLocalizations.language),
      subtitle: Text(_getLocaleString(context, currentLocale)),
      delegate: OptionsDelegate(
        title: context.appLocalizations.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (Locale? value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(locale: value?.toString()));
        },
        textBuilder: (locale) => _getLocaleString(context, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(context.appLocalizations.theme),
      subtitle: Text(context.appLocalizations.themeDesc),
      delegate: OpenDelegate(widget: const ThemeView()),
    );
  }
}

class _RoutingItem extends StatelessWidget {
  const _RoutingItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.route_outlined),
      title: Text(context.appLocalizations.basicConfig),
      subtitle: Text(context.appLocalizations.basicConfigDesc),
      delegate: OpenDelegate(widget: const ConfigView()),
    );
  }
}

class _ResetItem extends ConsumerWidget {
  const _ResetItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem(
      leading: const Icon(Icons.restore, color: Colors.red),
      title: Text(
        context.appLocalizations.reset,
        style: const TextStyle(color: Colors.red),
      ),
      onTap: () async {
        final res = await globalState.showMessage(
          message: TextSpan(text: context.appLocalizations.resetTip),
        );
        if (res != true) return;
        appController.handleExit(false);
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.info_outline),
      title: Text(context.appLocalizations.about),
      delegate: OpenDelegate(widget: const AboutView()),
    );
  }
}
