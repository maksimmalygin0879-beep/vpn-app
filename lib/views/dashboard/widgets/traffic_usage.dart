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

    final hasLimit = subTotal > 0;
    final displayBytes = hasLimit ? subUsed : downBytes;

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
        Row(
          children: [
            Text(
              "WiFi ↓",
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.primary.withOpacity(0.85),
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              hasLimit
                  ? "${_fmt(displayBytes)} / ${_fmt(subTotal)}"
                  : _fmt(displayBytes),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (hasLimit) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (subUsed / subTotal).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  context.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              valueColor: AlwaysStoppedAnimation<Color>(
                subUsed / subTotal > 0.9
                    ? context.colorScheme.error
                    : subUsed / subTotal > 0.7
                        ? context.colorScheme.tertiary
                        : context.colorScheme.primary,
              ),
            ),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 0.0,
              minHeight: 6,
              backgroundColor:
                  context.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _fmt(int b) {
    if (b <= 0) return "0B";
    if (b < 1024) return "${b}B";
    if (b < 1024 * 1024) return "${(b / 1024).toStringAsFixed(0)}KB";
    if (b < 1024 * 1024 * 1024)
      return "${(b / (1024 * 1024)).toStringAsFixed(1)}MB";
    return "${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB";
  }
}
