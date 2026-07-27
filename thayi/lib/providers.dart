import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/chat_service.dart';
import 'data/models.dart';
import 'data/mother_repository.dart';
import 'safety/danger_sign_detector.dart';

/// Overridden in main() once SharedPreferences has loaded.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

// ---------------------------------------------------------------- language

const kSupportedLocales = [Locale('kn'), Locale('en')];

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._prefs) : super(_read(_prefs));

  static const _key = 'locale_code';
  final SharedPreferences _prefs;

  /// Kannada is the default. English is the toggle, never the other way round.
  static Locale _read(SharedPreferences prefs) {
    final code = prefs.getString(_key);
    return code == 'en' ? const Locale('en') : const Locale('kn');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await _prefs.setString(_key, locale.languageCode);
  }

  bool get isKannada => state.languageCode == 'kn';
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(ref.watch(prefsProvider)),
);

// -------------------------------------------------------------------- auth

@immutable
class AuthState {
  const AuthState({this.token, this.phone, this.consentAt});

  final String? token;
  final String? phone;
  final DateTime? consentAt;

  bool get isSignedIn => token != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs) : super(_read(_prefs));

  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'auth_phone';
  static const _consentKey = 'consent_at';
  final SharedPreferences _prefs;

  static AuthState _read(SharedPreferences prefs) {
    final consent = prefs.getString(_consentKey);
    return AuthState(
      token: prefs.getString(_tokenKey),
      phone: prefs.getString(_phoneKey),
      consentAt: consent == null ? null : DateTime.tryParse(consent),
    );
  }

  /// Mock sign-in: any 6 digit code is accepted. The token is a placeholder
  /// until a real auth provider is added.
  Future<void> signIn({required String phone}) async {
    final now = DateTime.now();
    final token = 'mock-${now.millisecondsSinceEpoch}';
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_phoneKey, phone);
    state = AuthState(token: token, phone: phone, consentAt: state.consentAt);
  }

  Future<void> recordConsent() async {
    final now = DateTime.now();
    await _prefs.setString(_consentKey, now.toIso8601String());
    state = AuthState(token: state.token, phone: state.phone, consentAt: now);
  }

  Future<void> signOut() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_phoneKey);
    state = AuthState(consentAt: state.consentAt);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(prefsProvider)),
);

// -------------------------------------------------------------------- data

final motherRepositoryProvider = Provider<MotherRepository>(
  (ref) => const MockMotherRepository(),
);

final motherProvider = FutureProvider<Mother>(
  (ref) => ref.watch(motherRepositoryProvider).getMother(),
);

final checkupsProvider = FutureProvider<List<Checkup>>(
  (ref) => ref.watch(motherRepositoryProvider).getCheckups(),
);

final healthRecordProvider = FutureProvider<HealthRecord>(
  (ref) => ref.watch(motherRepositoryProvider).getHealthRecord(),
);

final schemesProvider = FutureProvider<List<Scheme>>(
  (ref) => ref.watch(motherRepositoryProvider).getSchemes(),
);

final babyRecordProvider = FutureProvider<BabyRecord>(
  (ref) => ref.watch(motherRepositoryProvider).getBabyRecord(),
);

/// The next checkup she has not attended yet, overdue ones first.
Checkup? nextCheckup(List<Checkup> all, DateTime now) {
  final pending = all.where((c) => !c.completed).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return pending.isEmpty ? null : pending.first;
}

// ------------------------------------------------------------------ safety

final dangerSignDetectorProvider =
    Provider<DangerSignDetector>((ref) => const DangerSignDetector());

// -------------------------------------------------------------------- chat

final chatServiceProvider = Provider<ChatService>(
  (ref) => const MockChatService(),
);

// -------------------------------------------------------- tablets for today

@immutable
class TabletState {
  const TabletState({required this.ifaTaken, required this.calciumTaken});
  final bool ifaTaken;
  final bool calciumTaken;
}

class TabletController extends StateNotifier<TabletState> {
  TabletController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static String get _dayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static TabletState _read(SharedPreferences prefs) => TabletState(
        ifaTaken: prefs.getBool('ifa_$_dayKey') ?? false,
        calciumTaken: prefs.getBool('cal_$_dayKey') ?? false,
      );

  Future<void> setIfa(bool taken) async {
    await _prefs.setBool('ifa_$_dayKey', taken);
    state = TabletState(ifaTaken: taken, calciumTaken: state.calciumTaken);
  }

  Future<void> setCalcium(bool taken) async {
    await _prefs.setBool('cal_$_dayKey', taken);
    state = TabletState(ifaTaken: state.ifaTaken, calciumTaken: taken);
  }
}

final tabletControllerProvider =
    StateNotifierProvider<TabletController, TabletState>(
  (ref) => TabletController(ref.watch(prefsProvider)),
);
