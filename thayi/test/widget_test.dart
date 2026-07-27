import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu_thayi/main.dart';
import 'package:setu_thayi/providers.dart';
import 'package:setu_thayi/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens on the splash screen in Kannada by default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const SetuThayiApp(),
      ),
    );
    await tester.pump();

    // Kannada is the default locale, not English.
    expect(find.text('ಸೇತು ತಾಯಿ'), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Let the splash timer fire so the test does not end with it pending.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
  });

  testWidgets('an unauthenticated start lands on login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const SetuThayiApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.text('ನಿಮ್ಮ ಫೋನ್ ನಂಬರ್ ಹಾಕಿ'), findsOneWidget);
    // The language toggle has to work before login.
    expect(find.text('English'), findsOneWidget);
  });
}
