import 'dart:io';
import 'dart:math' as math;

import 'package:honey_utility/common/common.dart';
import 'package:honey_utility/controller.dart';
import 'package:honey_utility/enum/enum.dart';
import 'package:honey_utility/models/models.dart';
import 'package:honey_utility/providers/providers.dart';
import 'package:honey_utility/providers/database.dart';
import 'package:honey_utility/providers/config.dart';
import 'package:honey_utility/state.dart';
import 'package:honey_utility/views/profiles/add.dart';
import 'package:honey_utility/views/proxies/common.dart';
import 'package:honey_utility/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';

import 'widgets/network_speed.dart';
import 'widgets/start_button.dart';
import 'widgets/traffic_usage.dart';

// Filter special proxy names and group types
const _kSpecialProxies = {'DIRECT', 'REJECT', 'GLOBAL'};
const _kGroupTypes = {'Selector', 'URLTest', 'Fallback', 'LoadBalance', 'Relay', 'Compatible'};

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

  Future<void> _openAddProfile() async {
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.addProfile,
        labelText: 'URL / vless:// / hy2:// / base64',
        value: '',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Введите ссылку или текст подписки';
          }
          return null;
        },
      ),
    );
    if (url == null || !mounted) return;
    final profile = await appController.addProfileSilent(url.trim());
    if (profile != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final profiles = ref.read(profilesProvider);
        final idx = profiles.indexWhere((p) => p.id == profile.id);
        if (idx >= 0) {
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
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
      floatingActionButton: const StartButton(),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          tooltip: appLocalizations.addProfile,
          onPressed: _openAddProfile,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                _StatCard(child: const NetworkSpeed()),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _StatCard(child: const _ModeSelector())),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(child: const TrafficUsage())),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (totalPages > 2)
            ListenableBuilder(
              listenable: _pageController,
              builder: (_, __) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? 0).round()
                    : 0;
                return _PageDots(current: page, total: totalPages);
              },
            ),
          if (totalPages > 2) const SizedBox(height: 8),
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
                  key: ValueKey(profile.id),
                  profile: profile,
                  isActive: profile.id == currentProfileId,
                  coreStatus: coreStatus,
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

// Compact mode selector widget
class _ModeSelector extends ConsumerWidget {
  const _ModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((s) => s.mode),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.outboundMode,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Buttons fill full height
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: Mode.values.map((m) {
                    final active = m == mode;
                    final isLast = m == Mode.values.last;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => appController.changeMode(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: active
                                ? context.colorScheme.primary
                                : context.colorScheme.surfaceContainerHighest,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            Intl.message(m.name),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: active
                                  ? context.colorScheme.onPrimary
                                  : context.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Arrows — centered, close to buttons
              Expanded(
                flex: 4,
                child: Center(child: _ModeIllustration(mode: mode)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Animated arrows illustration for mode selector
class _ModeIllustration extends StatefulWidget {
  final Mode mode;
  const _ModeIllustration({required this.mode});

  @override
  State<_ModeIllustration> createState() => _ModeIllustrationState();
}

class _ModeIllustrationState extends State<_ModeIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ModeIllustration old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _arrowCount => switch (widget.mode) {
        Mode.rule => 3,
        Mode.global => 2,
        Mode.direct => 1,
        _ => 1,
      };

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.primary;
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => CustomPaint(
        painter: _ArrowsPainter(
          arrowCount: _arrowCount,
          progress: _progress.value,
          color: color,
        ),
        size: const Size(80, 72),
      ),
    );
  }
}

class _ArrowsPainter extends CustomPainter {
  final int arrowCount;
  final double progress;
  final Color color;

  const _ArrowsPainter({
    required this.arrowCount,
    required this.progress,
    required this.color,
  });

  // Quadratic bezier interpolation helper
  Offset _lerpOff(Offset a, Offset b, double t) =>
      Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(0.75)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    // Base point at bottom center
    final p0 = Offset(cx, size.height * 0.88);

    // Each arrow defined as (control-point P1, tip P2).
    // P1 close to center → arrows start straight up, then curve out (fork shape).
    final List<(Offset, Offset)> arrows = switch (arrowCount) {
      1 => [
          (Offset(cx, size.height * 0.28), Offset(cx, size.height * 0.06)),
        ],
      2 => [
          (Offset(cx - 4,  size.height * 0.44), Offset(cx - 26, size.height * 0.09)),
          (Offset(cx + 4,  size.height * 0.44), Offset(cx + 26, size.height * 0.09)),
        ],
      _ => [
          (Offset(cx - 4,  size.height * 0.46), Offset(cx - 28, size.height * 0.09)),
          (Offset(cx,      size.height * 0.28), Offset(cx,       size.height * 0.06)),
          (Offset(cx + 4,  size.height * 0.46), Offset(cx + 28, size.height * 0.09)),
        ],
    };

    const headLen = 9.0;
    const headAngle = 30.0 * math.pi / 180;

    for (final (p1, p2) in arrows) {
      // Sub-bezier from 0 to progress via de Casteljau subdivision
      final q1 = _lerpOff(p0, p1, progress);
      final q2 = _lerpOff(_lerpOff(p0, p1, progress), _lerpOff(p1, p2, progress), progress);

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(q1.dx, q1.dy, q2.dx, q2.dy);
      canvas.drawPath(path, paint);

      // Arrowhead appears after 30% progress, tangent direction = q2 - q1
      if (progress > 0.30) {
        final t = ((progress - 0.30) / 0.70).clamp(0.0, 1.0);
        final tangent = q2 - q1;
        final stemAngle = math.atan2(tangent.dy, tangent.dx);
        final headPaint = Paint()
          ..color = color.withOpacity(0.75 * t)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (final sign in [-1.0, 1.0]) {
          final ha = stemAngle + math.pi + sign * headAngle;
          canvas.drawLine(
            q2,
            Offset(q2.dx + headLen * math.cos(ha), q2.dy + headLen * math.sin(ha)),
            headPaint,
          );
        }
      }
    }

    // Dot at base
    canvas.drawCircle(
      p0,
      3.0 * progress,
      Paint()..color = color.withOpacity(0.75 * progress),
    );
  }

  @override
  bool shouldRepaint(_ArrowsPainter old) =>
      old.progress != progress ||
      old.arrowCount != arrowCount ||
      old.color != color;
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              if (onPrev != null)
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              else
                const SizedBox(width: 32),
              const Spacer(),
              const SizedBox(width: 32),
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
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _ProfilePage({
    super.key,
    required this.profile,
    required this.isActive,
    required this.coreStatus,
    required this.onPrev,
    required this.onNext,
  });

  @override
  ConsumerState<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<_ProfilePage> {
  List<String> _proxyNames = [];
  bool _pinging = false;
  bool _refreshing = false;
  String? _selectedProxy; // local optimistic selection

  @override
  void initState() {
    super.initState();
    _loadProxyNames();
  }

  Future<void> _loadProxyNames() async {
    try {
      final file = await widget.profile.file;
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final doc = loadYaml(content);
      final raw = doc['proxies'];
      if (raw == null) return;
      final names = <String>[];
      for (final p in raw as YamlList) {
        final name = (p as YamlMap)['name'];
        if (name is String &&
            name.isNotEmpty &&
            !_kSpecialProxies.contains(name)) {
          names.add(name);
        }
      }
      if (mounted) setState(() => _proxyNames = names);
    } catch (_) {}
  }

  Future<void> _selectProxy(String proxyName) async {
    // Optimistically highlight immediately
    setState(() => _selectedProxy = proxyName);
    if (!widget.isActive) {
      ref.read(currentProfileIdProvider.notifier).value = widget.profile.id;
      appController.applyProfileDebounce();
      await Future.delayed(const Duration(milliseconds: 800));
    }
    final groups = ref.read(groupsProvider);
    final groupName = groups.isEmpty ? null : groups.first.name;
    if (groupName != null) {
      appController.changeProxyDebounce(groupName, proxyName);
    }
    appController.updateStatus(true);
  }

  Future<void> _ping() async {
    // Activate profile first if not active (loads config into core without routing traffic)
    if (!widget.isActive) {
      ref.read(currentProfileIdProvider.notifier).value = widget.profile.id;
      appController.applyProfileDebounce();
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) return;
    final group = groups.first;
    setState(() => _pinging = true);
    try {
      await delayTest(group.all, group.testUrl);
      await appController.updateGroups();
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  Future<void> _refresh() async {
    if (widget.profile.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет URL подписки — удалите профиль и добавьте заново'), duration: Duration(seconds: 3)),
      );
      return;
    }
    setState(() => _refreshing = true);
    try {
      await appController.updateProfile(widget.profile);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.isActive ? ref.watch(groupsProvider) : <Group>[];
    final isConnected =
        widget.isActive && widget.coreStatus == CoreStatus.connected;

    final mainGroup = groups.isEmpty ? null : groups.first;
    // Use local optimistic selection, fall back to live group data
    final selectedProxy = _selectedProxy ?? mainGroup?.now ?? '';

    // Live proxies: filter out group-type entries and special names
    final liveProxies = mainGroup?.all
            .where((p) =>
                !_kSpecialProxies.contains(p.name) &&
                !_kGroupTypes.contains(p.type))
            .map((p) => p.name)
            .toList() ??
        [];
    final displayNames = liveProxies.isNotEmpty ? liveProxies : _proxyNames;
    final testUrl = mainGroup?.testUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // header
          Row(
            children: [
              if (widget.onPrev != null)
                IconButton(
                  onPressed: widget.onPrev,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
              Builder(builder: (ctx) {
                final tgUrl = widget.profile.subscriptionInfo?.webPageUrl?.isNotEmpty == true
                    ? widget.profile.subscriptionInfo!.webPageUrl!
                    : (kTelegramUrl.isNotEmpty ? kTelegramUrl : null);
                if (tgUrl == null) return const SizedBox.shrink();
                return IconButton(
                  onPressed: () => launchUrl(Uri.parse(tgUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.telegram, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                  tooltip: 'Telegram',
                  color: context.colorScheme.onSurface.withOpacity(0.5),
                );
              }),
              IconButton(
                onPressed: widget.onNext,
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          // ping + refresh buttons
          ClipRect(
           child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text('Обновить', style: context.textTheme.labelSmall),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                const SizedBox(width: 4),
                _pinging
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _ping,
                        icon: const Icon(Icons.network_ping, size: 16),
                        label: Text(
                          appLocalizations.delayTest,
                          style: context.textTheme.labelSmall,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
              ],
            ),
           ),
          // Subscription info
          _SubscriptionBar(profile: widget.profile),
          // server list
          Expanded(
            child: displayNames.isEmpty
                ? Center(
                    child: Text(
                      'Нет серверов',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: displayNames.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final name = displayNames[i];
                      final isSelected =
                          widget.isActive && name == selectedProxy;
                      return _ServerTile(
                        name: name,
                        isSelected: isSelected,
                        isActive: widget.isActive,
                        testUrl: testUrl,
                        onTap: () => _selectProxy(name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  final String name;
  final bool isSelected;
  final bool isActive;
  final String? testUrl;
  final VoidCallback onTap;

  const _ServerTile({
    required this.name,
    required this.isSelected,
    required this.isActive,
    required this.testUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use getDelayProvider for correct delay lookup (keyed by URL, not group name)
    final delay = isActive
        ? ref.watch(getDelayProvider(proxyName: name, testUrl: testUrl))
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? context.colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 3,
                height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: Text(
                name,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamilyFallback: const ['NotoColorEmoji', 'Twemoji'],
                ),
              ),
            ),
            if (delay != null && delay > 0)
              Text(
                '${delay}ms',
                style: context.textTheme.labelSmall?.copyWith(
                  color: delay < 200
                      ? Colors.green
                      : delay < 500
                          ? context.colorScheme.tertiary
                          : context.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (delay == 0)
              Text(
                'n/a',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.35),
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: context.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription info bar
// ---------------------------------------------------------------------------
String _fmtBytes(int bytes) {
  if (bytes <= 0) return '0B';
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}

class _SubscriptionBar extends StatelessWidget {
  final Profile profile;
  const _SubscriptionBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final sub = profile.subscriptionInfo;
    if (sub == null) return const SizedBox.shrink();

    final used = sub.upload + sub.download;
    final isUnlimited = sub.total == 0;
    final hasTraffic = used > 0 || sub.total > 0;
    final hasExpiry = sub.expire > 0;
    if (!hasTraffic && !hasExpiry) return const SizedBox.shrink();

    final progress = (!isUnlimited && sub.total > 0) ? (used / sub.total).clamp(0.0, 1.0) : null;
    final usedStr = _fmtBytes(used);
    final totalStr = isUnlimited ? '∞' : _fmtBytes(sub.total);

    String? expiryStr;
    if (hasExpiry) {
      final dt = DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      expiryStr = '$d.$m.${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTraffic) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: context.colorScheme.surfaceContainerHighest,
                      color: progress == null
                          ? context.colorScheme.primary
                          : progress > 0.9
                              ? context.colorScheme.error
                              : progress > 0.7
                                  ? context.colorScheme.tertiary
                                  : context.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$usedStr / $totalStr',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          if (expiryStr != null)
            Text(
              'Истекает: $expiryStr',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}
