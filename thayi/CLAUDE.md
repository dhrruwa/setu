# Thayi Setu

Flutter app for pregnant women in rural Karnataka. Android + iOS, one codebase.

Kannada is the default language — all strings live in `lib/l10n/*.arb`, never inline.
Ids in the data layer resolve to text through `lib/l10n/content.dart`.
She reads her record, never edits it. The only thing she can change is today's
tablet tick and her language.

Data comes from `MockMotherRepository` behind the `MotherRepository` interface.
Supabase will be swapped in later — do not couple UI to any backend.
All demo data is in `lib/data/mock_data.dart` and is relative to today, so she is
always 32 weeks pregnant whenever the demo is run.

Safety: `DangerSignDetector` runs client-side before any chat message is sent.
It is a hard-coded keyword matcher, not a model call, and must fire every time.
It is covered by `test/danger_sign_detector_test.dart` — keep those tests green.

Never put personal data in the QR payload. It is `setu://m/<uuid>?t=<token>` and
nothing else.

The chat never answers about medicines or dosages — `MockChatService` refuses
those outright, in the client.

## Design system

Use `C`, `T`, `S` from `lib/theme/tokens.dart` everywhere. No raw `Colors.*`, no
magic numbers. Build screens from `lib/widgets/` — `SetuCard`, `StatCard`,
`RiskChip`, `BigActionButton`, `CallButton`, `SetuScaffold`, `SectionHeader`,
`EmptyState`. Red appears only on emergency and danger elements.

Every post-login screen is wrapped in `SetuScaffold`, which is what puts the
floating emergency button on screen. Do not add it per screen.

Never leave a screen blank while loading — use `SkeletonList`/`SkeletonCard`,
and `EmptyState` for errors, never a red Flutter exception box.

## Commands

```
flutter pub get
flutter gen-l10n          # after editing any .arb file
flutter analyze
flutter test
flutter build apk --release
```
