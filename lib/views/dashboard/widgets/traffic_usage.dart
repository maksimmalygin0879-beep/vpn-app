import "package:honey_utility/common/common.dart";
import "package:honey_utility/providers/app.dart";
import "package:honey_utility/providers/state.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class TrafficUsage extends ConsumerWidget {
  const TrafficUsage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalTraffic = ref.watch(totalTrafficProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final sub = currentProfile?.subscriptionInfo;

    final downBytes = totalTraffic.down.toInt();
    final subTotal = sub?.total ?? 0;
    final subUsed = (sub?.upload ?? 0) + (sub?.download ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          appLocalizations.trafficUsage,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 10),
        _TrafficBar(
          label: "WiFi ↓",
          bytes: subTotal > 0 ? subUsed : downBytes,
          limitBytes: subTotal,
          color: context.colorScheme.primary,
        ),
      ],
    );
  }
}

class _TrafficBar extends StatelessWidget {
  final String label;
  final int bytes;
  final int limitBytes;
  final Color color;

  const _TrafficBar({
    required this.label,
    required this.bytes,
    required this.limitBytes,
    required this.color,
  });

  String _fmt(int b) {
    if (b <= 0) return "0B";
    if (b < 1024) return "${b}B";
    if (b < 1024 * 1024) return "${(b / 1024).toStringAsFixed(0)}KB";
    if (b < 1024 * 1024 * 1024)
      return "${(b / (1024 * 1024)).toStringAsFixed(1)}MB";
    return "${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB";
  }

  @override
  Widget build(BuildContext context) {
    final hasLimit = limitBytes > 0;
    final progress =
        hasLimit ? (bytes / limitBytes).clamp(0.0, 1.0) : null;
    final barColor = (progress != null && progress > 0.9)
        ? context.colorScheme.error
        : (progress != null && progress > 0.7)
            ? context.colorScheme.tertiary
            : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: color.withOpacity(0.85),
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              hasLimit
                  ? "${_fmt(bytes)} / ${_fmt(limitBytes)}"
                  : _fmt(bytes),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress ?? (bytes > 0 ? null : 0.0),
            minHeight: 6,
            backgroundColor:
                context.colorScheme.surfaceContainerHighest.withOpacity(0.7),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
