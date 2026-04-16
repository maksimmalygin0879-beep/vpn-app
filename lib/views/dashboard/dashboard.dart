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
import 'widgets/traffic_usage.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  void _openAddProfile(BuildContext context) {
    showSheet(
      context: context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.addProfile,
        body: AddProfileView(context: context),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final coreStatus = ref.watch(coreStatusProvider);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) {
          _openAddProfile(context);
        }
      },
      child: CommonScaffold(
        title: appLocalizations.dashboard,
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _InfoCard(child: const NetworkSpeed()),
                  const SizedBox(height: 12),
                  _InfoCard(child: const TrafficUsage()),
                  const SizedBox(height: 16),
                  ...profiles.map(
                    (profile) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProfileCard(
                        profile: profile,
                        isActive: profile.id == currentProfileId,
                        coreStatus: coreStatus,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16, 0, 16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openAddProfile(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить подписку'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: context.colorScheme.primary.withOpacity(0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  final Profile profile;
  final bool isActive;
  final CoreStatus coreStatus;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.coreStatus,
  });

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _pinging = false;

  Future<void> _handleConnect() async {
    if (!widget.isActive) {
      ref.read(currentProfileIdProvider.notifier).value = widget.profile.id;
      appController.applyProfileDebounce();
      await Future.delayed(const Duration(milliseconds: 400));
    }
    final isConnected = widget.coreStatus == CoreStatus.connected;
    appController.updateStatus(!isConnected);
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
    final isConnected = widget.isActive && widget.coreStatus == CoreStatus.connected;
    final isConnecting = widget.isActive && widget.coreStatus == CoreStatus.connecting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive
              ? context.colorScheme.primary
              : context.colorScheme.outline.withOpacity(0.2),
          width: widget.isActive ? 1.5 : 1,
        ),
        color: context.colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.profile.label,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appLocalizations.connected,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.isActive && groups.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...groups.take(1).map(
                (group) => Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          underline: const SizedBox(),
                          value: group.all.any((p) => p.name == (group.now ?? ''))
                              ? group.now
                              : group.all.firstOrNull?.name,
                          items: group.all.map((p) {
                            final delay = ref.watch(
                              delayDataSourceProvider.select(
                                (m) => m[group.name]?[p.name],
                              ),
                            );
                            return DropdownMenuItem(
                              value: p.name,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.bodySmall,
                                    ),
                                  ),
                                  if (delay != null && delay > 0)
                                    Text(
                                      'ms',
                                      style: context.textTheme.labelSmall?.copyWith(
                                        color: delay < 200
                                            ? Colors.green
                                            : delay < 500
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              appController.changeProxyDebounce(group.name, value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: _pinging
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: appLocalizations.delayTest,
                              icon: const Icon(Icons.network_ping, size: 20),
                              onPressed: () => _ping(group),
                            ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isConnecting ? null : _handleConnect,
                style: FilledButton.styleFrom(
                  backgroundColor: isConnected
                      ? Colors.red.withOpacity(0.85)
                      : context.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isConnecting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isConnected
                            ? appLocalizations.stop
                            : widget.isActive
                                ? 'Подключить'
                                : 'Выбрать и подключить',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
