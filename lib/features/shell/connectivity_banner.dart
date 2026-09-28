import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/services/connectivity_service.dart';
import '../../l10n/app_localizations.dart';

/// A one-line strip that tells the user where their data is being processed.
///
/// Requirement: the app must always make it obvious whether a feature is
/// running locally or needs the network. The banner only appears when the
/// device is offline, because "you are online" is not news — but a small
/// status pill in the app bar always shows the current mode.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ConnectivityStatus status =
        ref.watch(connectivityStatusProvider).valueOrNull ?? ConnectivityStatus.unknown;
    final AppLocalizations l10n = AppLocalizations.of(context);

    final bool offline = !status.isOnline;

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: offline
          ? Material(
              color: AppColors.offline.withValues(alpha: 0.12),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_off_rounded, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${l10n.offlineBannerTitle} — ${l10n.offlineBannerBody}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(connectivityServiceProvider)
                            .check(force: true),
                        child: Text(l10n.continueOffline),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Compact local/online indicator for app bars.
class ProcessingModePill extends ConsumerWidget {
  const ProcessingModePill({this.showLabel = true, super.key});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ConnectivityStatus status =
        ref.watch(connectivityStatusProvider).valueOrNull ?? ConnectivityStatus.unknown;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool online = status.isOnline;

    final Color color = online ? AppColors.online : AppColors.offline;
    final String label = online ? l10n.statusOnline : l10n.statusLocal;

    return Tooltip(
      message: online
          ? '${l10n.statusOnline} — ${l10n.aiTitle}'
          : '${l10n.statusOffline} — ${l10n.statusLocal}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
