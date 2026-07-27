import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Supabase exports an AuthState of its own; this file already has one.
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'config/env.dart';
import 'data/chat_service.dart';
import 'data/models.dart';
import 'data/mother_repository.dart';
import 'data/profile_photo_service.dart';
import 'data/supabase_mother_repository.dart';
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
  const AuthState({this.token, this.email, this.consentAt});

  final String? token;
  final String? email;
  final DateTime? consentAt;

  bool get isSignedIn => token != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs, this._client) : super(_read(_prefs));

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _consentKey = 'consent_at';
  final SharedPreferences _prefs;

  /// Null when Supabase is unavailable — the app then runs the mock flow so a
  /// demo with no signal still works.
  final sb.SupabaseClient? _client;

  bool get usesSupabase => _client != null;

  static AuthState _read(SharedPreferences prefs) {
    final consent = prefs.getString(_consentKey);
    return AuthState(
      token: prefs.getString(_tokenKey),
      email: prefs.getString(_emailKey),
      consentAt: consent == null ? null : DateTime.tryParse(consent),
    );
  }

  /// Set when the project cannot send a code (provider disabled, SMTP
  /// rejected). She must not be dead-ended at the login screen because of a
  /// backend setting, so the app falls back to the local flow.
  bool _otpUnavailable = false;

  bool get otpUnavailable => _otpUnavailable;

  static bool _isProviderDisabled(sb.AuthException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    return code == 'email_provider_disabled' ||
        code == 'phone_provider_disabled' ||
        message.contains('provider disabled') ||
        message.contains('unsupported');
  }

  /// Emails her a six digit code. The SMTP credentials live in Supabase's
  /// server-side config and never touch this app.
  Future<void> sendOtp(String email) async {
    final client = _client;
    if (client == null) {
      _otpUnavailable = true;
      return;
    }
    try {
      await client.auth.signInWithOtp(email: email.trim());
      _otpUnavailable = false;
    } on sb.AuthException catch (error) {
      if (_isProviderDisabled(error)) {
        _otpUnavailable = true;
        debugPrint(
          'Supabase email auth is not configured; using the local sign-in '
          'flow and mock data.',
        );
        return;
      }
      rethrow;
    }
  }

  /// Verifies the code and opens a real Supabase session, which is what Row
  /// Level Security scopes her record to. In mock mode any 6 digits pass.
  Future<void> verifyOtp({
    required String email,
    required String code,
  }) async {
    final client = _client;
    if (client == null || _otpUnavailable) {
      await _signInMock(email: email);
      return;
    }

    final response = await client.auth.verifyOTP(
      type: sb.OtpType.email,
      email: email.trim(),
      token: code,
    );
    final session = response.session;
    if (session == null) {
      throw const sb.AuthException('Verification did not return a session');
    }

    await _prefs.setString(_tokenKey, session.accessToken);
    await _prefs.setString(_emailKey, email.trim());
    state = AuthState(
      token: session.accessToken,
      email: email.trim(),
      consentAt: state.consentAt,
    );
  }

  Future<void> _signInMock({required String email}) async {
    final now = DateTime.now();
    final token = 'mock-${now.millisecondsSinceEpoch}';
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_emailKey, email);
    state = AuthState(token: token, email: email, consentAt: state.consentAt);
  }

  Future<void> recordConsent() async {
    final now = DateTime.now();
    await _prefs.setString(_consentKey, now.toIso8601String());
    state = AuthState(token: state.token, email: state.email, consentAt: now);
  }

  /// She was promised at login that she could take this back. Clears the
  /// consent record and signs her out; the paper record is unaffected.
  Future<void> withdrawConsent() async {
    await _prefs.remove(_consentKey);
    await _client?.auth.signOut();
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_emailKey);
    state = const AuthState();
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_emailKey);
    state = AuthState(consentAt: state.consentAt);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(prefsProvider),
    ref.watch(supabaseClientProvider),
  ),
);

// -------------------------------------------------------------------- data

/// Null when Supabase is switched off, unconfigured, or failed to initialise.
final supabaseClientProvider = Provider<sb.SupabaseClient?>((ref) {
  if (!Env.useSupabase || !Env.isSupabaseConfigured) return null;
  try {
    return sb.Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Rebuilds the repository the moment a Supabase session appears or expires.
final supabaseSessionProvider = StreamProvider<sb.Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange
      .map((event) => event.session)
      .distinct((a, b) => a?.accessToken == b?.accessToken);
});

/// The swap point. Supabase is used only when there is a real session — every
/// query is scoped by RLS to that user. Anything else falls back to mock data
/// so a demo never dies on a bad connection.
final motherRepositoryProvider = Provider<MotherRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session =
      ref.watch(supabaseSessionProvider).valueOrNull ?? client?.auth.currentSession;

  if (client != null && session != null) {
    return SupabaseMotherRepository(client);
  }
  return const MockMotherRepository();
});

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

// ----------------------------------------------------------- profile photo

final profilePhotoServiceProvider = Provider<ProfilePhotoService>(
  (ref) => ProfilePhotoService(ref.watch(prefsProvider)),
);

@immutable
class ProfilePhoto {
  const ProfilePhoto({this.file, this.version = 0});

  final File? file;

  /// The file path never changes, so Flutter's image cache would happily show
  /// the previous photo forever. Bumping this rebuilds the Image widget.
  final int version;

  bool get exists => file != null;
}

class ProfilePhotoController extends StateNotifier<ProfilePhoto> {
  ProfilePhotoController(this._service)
      : super(ProfilePhoto(file: _service.currentPhoto()));

  final ProfilePhotoService _service;

  /// Returns false if she backed out of the picker, so the UI can stay quiet
  /// rather than claim something happened.
  Future<bool> pick(PhotoSource source) async {
    final file = await _service.pick(source);
    if (file == null) return false;
    await FileImage(file).evict();
    state = ProfilePhoto(file: file, version: state.version + 1);
    return true;
  }

  Future<void> remove() async {
    final previous = state.file;
    await _service.remove();
    if (previous != null) await FileImage(previous).evict();
    state = ProfilePhoto(file: null, version: state.version + 1);
  }
}

final profilePhotoProvider =
    StateNotifierProvider<ProfilePhotoController, ProfilePhoto>(
  (ref) => ProfilePhotoController(ref.watch(profilePhotoServiceProvider)),
);

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
