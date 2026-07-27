import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/content.dart';
import '../providers.dart';
import '../safety/danger_sign_detector.dart';
import '../theme/tokens.dart';
import '../widgets/call_button.dart';

/// The full-screen interrupt. It is pushed by the client the moment
/// [DangerSignDetector] matches - before anything is sent anywhere.
class DangerAlertScreen extends ConsumerWidget {
  const DangerAlertScreen({super.key, required this.match});

  final DangerMatch match;

  static Future<void> show(BuildContext context, DangerMatch match) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DangerAlertScreen(match: match),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mother = ref.watch(motherProvider).valueOrNull;

    return PopScope(
      // She has to make a choice here, not swipe it away by accident.
      canPop: false,
      child: Scaffold(
        backgroundColor: C.red,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(S.screen),
            children: [
              const SizedBox(height: S.md),
              const Icon(Icons.warning_amber_rounded,
                  size: 72, color: C.onDark),
              const SizedBox(height: S.md),
              Text(
                l.dangerInterruptTitle,
                style: T.display.copyWith(color: C.onDark, fontSize: 34),
              ),
              const SizedBox(height: S.md),
              Text(
                l.dangerInterruptBody,
                style: T.body.copyWith(color: C.onDark, fontSize: 20),
              ),
              const SizedBox(height: S.lg),
              Container(
                padding: const EdgeInsets.all(S.md),
                decoration: BoxDecoration(
                  color: C.onDark.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(S.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.dangerSignTitle(match.sign),
                      style: T.h2.copyWith(color: C.onDark),
                    ),
                    const SizedBox(height: S.sm),
                    Text(
                      l.dangerSignDo(match.sign),
                      style: T.body.copyWith(color: C.onDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: S.lg),
              CallButton(
                title: l.callAmbulance,
                number: '108',
                subtitle: '108',
                background: C.ink,
                onFailureMessage: l.callFailed,
              ),
              const SizedBox(height: S.md),
              if (mother != null) ...[
                CallButton(
                  title: l.callAsha,
                  number: mother.asha.phone,
                  subtitle: l.ashaName(mother.asha),
                  background: C.terra,
                  onFailureMessage: l.callFailed,
                ),
                const SizedBox(height: S.md),
                CallButton(
                  title: l.callPhc,
                  number: mother.phc.phone,
                  subtitle: l.centreName(mother.phc),
                  background: C.terra,
                  onFailureMessage: l.callFailed,
                ),
                const SizedBox(height: S.md),
              ],
              Text(
                l.dangerInterruptNote,
                style: T.bodySoft.copyWith(
                  color: C.onDark.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: S.lg),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: C.onDark,
                  minimumSize: const Size.fromHeight(S.tapMin),
                  side: BorderSide(color: C.onDark.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l.dangerInterruptDismiss),
              ),
              const SizedBox(height: S.lg),
            ],
          ),
        ),
      ),
    );
  }
}
