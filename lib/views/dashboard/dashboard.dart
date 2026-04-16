import 'package:honey_utility/common/common.dart';
import 'package:honey_utility/controller.dart';
import 'package:honey_utility/enum/enum.dart';
import 'package:honey_utility/models/models.dart';
import 'package:honey_utility/providers/providers.dart';
import 'package:honey_utility/providers/database.dart';
import 'package:honey_utility/state.dart';
import 'package:honey_utility/views/profiles/add.dart';
import 'package:honey_utility/views/proxies/common.dart';
import 'package:honey_utility/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/network_speed.dart';
import 'widgets/outbound_mode.dart';
import 'widgets/traffic_usage.dart';

const _kSpecialProxies = {'DIRECT', 'REJECT', 'GLOBAL'};

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openAddProfile() {
    showSheet(
      context: context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.addProfile,
        body: AddProfileView(context: context),
      ),
    );
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final coreStatus = ref.watch(coreStatusProvider);
    final totalPages = profiles.length + 1;

    return CommonScaffold(
      title: appLocalizations.dashboard,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          tooltip: appLocalizations.addProfile,
          onPressed: _openAddProfile,
        ),
      ],
      body: Column(
        children: [
          // stats: network speed full width
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                _StatCard(child: const NetworkSpeed()),
                const SizedBox(height: 10),
                // mode selector + traffic usage in one row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _StatCard(child: const OutboundModeV2())),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(child: const TrafficUsage())),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // page indicator
          ListenableBuilder(
            listenable: _pageController,
            builder: (_, __) {
              final page = _pageController.hasClients
                  ? (_pageController.page ?? 0).round()
                  : 0;
              return _PageDots(current: page, total: totalPages);
            },
          ),
          const SizedBox(height: 8),
          // main swipeable area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              itemBuilder: (context, index) {
                if (index == profiles.length) {
                  return _AddPage(
                    onAdd: _openAddProfile,
                    onPrev: profiles.isNotEmpty
                        ? () => _goToPage(index - 1)
                        : null,
                  );
                }
                final profile = profiles[index];
                return _ProfilePage(
                  profile: profile,
                  isActive: profile.id == currentProfileId,
                  coreStatus: coreStatus,
                  pageIndex: index,
                  totalProfiles: profiles.length,
                  onPrev: index > 0 ? () => _goToPage(index - 1) : null,
                  onNext: () => _goToPage(index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Widget child;
  const _StatCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _PageDots extends StatelessWidget {
  final int current;
  final int total;
  const _PageDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active
                ? context.colorScheme.primary
                : context.colorScheme.outline.withOpacity(0.3),
          ),
        );
      }),
    );
  }
}

class _AddPage extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback? onPrev;
  const _AddPage({required this.onAdd, this.onPrev});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // back arrow row
          Row(
            children: [
              if (onPrev != null)
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 64,
                  color: context.colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  appLocalizations.addProfile,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Вставьте ссылку подписки, vless://, hy2:// или base64',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(appLocalizations.addProfile),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends ConsumerStatefulWidget {
  final Profile profile;
  final bool isActive;
  final CoreStatus coreStatus;
  final int pageIndex;
  final int totalProfiles;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _ProfilePage({
    required this.profile,
    required this.isActive,
    required this.coreStatus,
    required this.pageIndex,
    required this.totalProfiles,
    required this.onPrev,
    required this.onNext,
  });

  @override
  ConsumerState<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<_ProfilePage> {
  bool _pinging = false;

  void _activateProfile() {
    ref.read(currentProfileIdProvider.notifier).value = widget.profile.id;
    appController.applyProfileDebounce();
  }

  Future<void> _selectProxy(String groupName, String proxyName) async {
    if (!widget.isActive) {
      _activateProfile();
      await Future.delayed(const Duration(milliseconds: 400));
    }
    appController.changeProxyDebounce(groupName, proxyName);
    if (widget.coreStatus != CoreStatus.connected) {
      appController.updateStatus(true);
    }
  }

  Future<void> _ping(Group group) async {
    setState(() => _pinging = true);
    try {
      await delayTest(group.all, group.testUrl);
      await appController.updateGroups();
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.isActive ? ref.watch(groupsProvider) : <Group>[];
    final delayMap = widget.isActive
        ? ref.watch(delayDataSourceProvider)
        : <String, Map<String, int?>>{};
    final isConnected =
        widget.isActive && widget.coreStatus == CoreStatus.connected;

    final mainGroup = groups.isEmpty ? null : groups.first;
    final proxies = mainGroup?.all
            .where((p) => !_kSpecialProxies.contains(p.name))
            .toList() ??
        [];
    final selectedProxy = mainGroup?.now ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // profile header row with arrows
          Row(
            children: [
              if (widget.onPrev != null)
                IconButton(
                  onPressed: widget.onPrev,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              else
                const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.profile.label,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isConnected)
                      Text(
                        appLocalizations.connected,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onNext,
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // body: not active → activate button; active → server list
          Expanded(
            child: !widget.isActive
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: context.colorScheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _activateProfile,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Выбрать профиль'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // ping button
                      if (mainGroup != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _pinging
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : TextButton.icon(
                                    onPressed: () => _ping(mainGroup),
                                    icon: const Icon(Icons.network_ping,
                                        size: 16),
                                    label: Text(
                                      appLocalizations.delayTest,
                                      style: context.textTheme.labelSmall,
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                          ],
                        ),
                      // servers list
                      Expanded(
                        child: proxies.isEmpty
                            ? Center(
                                child: Text(
                                  'Загрузка серверов...',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: proxies.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final proxy = proxies[i];
                                  final groupDelays = mainGroup != null
                                      ? delayMap[mainGroup.name]
                                      : null;
                                  final delay = groupDelays?[proxy.name];
                                  final isSelected = proxy.name ==
                                          selectedProxy &&
                                      widget.isActive;

                                  return InkWell(
                                    onTap: mainGroup != null
                                        ? () => _selectProxy(
                                            mainGroup.name, proxy.name)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        color: isSelected
                                            ? context.colorScheme.primary
                                                .withOpacity(0.12)
                                            : Colors.transparent,
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelected)
                                            Container(
                                              width: 3,
                                              height: 20,
                                              margin: const EdgeInsets.only(
                                                  right: 10),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              proxy.name,
                                              style: context
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (delay != null && delay > 0)
                                            Text(
                                              '${delay}ms',
                                              style: context
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: delay < 200
                                                    ? Colors.green
                                                    : delay < 500
                                                        ? Colors.orange
                                                        : Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color:
                                                  context.colorScheme.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
