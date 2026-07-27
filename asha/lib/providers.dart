import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/ocr_service.dart';
import 'data/seed_data.dart';
import 'data/sync_service.dart';
import 'db/database.dart';
import 'risk/risk_engine.dart';

/// Both are overridden in main() once opened.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final dbProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('dbProvider must be overridden'),
);

// ---------------------------------------------------------------- language

const kSupportedLocales = [Locale('kn'), Locale('en')];

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._prefs) : super(_read(_prefs));

  static const _key = 'locale_code';
  final SharedPreferences _prefs;

  /// Kannada is the default. English is the toggle.
  static Locale _read(SharedPreferences prefs) =>
      prefs.getString(_key) == 'en' ? const Locale('en') : const Locale('kn');

  Future<void> set(Locale locale) async {
    state = locale;
    await _prefs.setString(_key, locale.languageCode);
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(ref.watch(prefsProvider)),
);

// -------------------------------------------------------------------- auth

@immutable
class AshaSession {
  const AshaSession({this.email, this.name, this.pin, this.unlocked = false});

  final String? email;
  final String? name;
  final String? pin;

  /// PIN entered this run. The phone is shared, so this resets on every open.
  final bool unlocked;

  bool get isSignedIn => email != null;
  bool get hasPin => pin != null && pin!.length == 4;

  AshaSession copyWith({
    String? email,
    String? name,
    String? pin,
    bool? unlocked,
  }) =>
      AshaSession(
        email: email ?? this.email,
        name: name ?? this.name,
        pin: pin ?? this.pin,
        unlocked: unlocked ?? this.unlocked,
      );
}

class AuthController extends StateNotifier<AshaSession> {
  AuthController(this._prefs) : super(_read(_prefs));

  static const _emailKey = 'asha_email';
  static const _nameKey = 'asha_name';
  static const _pinKey = 'asha_pin';
  final SharedPreferences _prefs;

  static AshaSession _read(SharedPreferences prefs) => AshaSession(
        email: prefs.getString(_emailKey),
        name: prefs.getString(_nameKey),
        pin: prefs.getString(_pinKey),
      );

  /// The session is cached locally and never expires on its own — she must
  /// never be asked to re-authenticate in a village with no signal.
  Future<void> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _prefs.setString(_emailKey, email);
    await _prefs.setString(_nameKey, SeedData.ashaName);
    state = state.copyWith(
      email: email,
      name: SeedData.ashaName,
      unlocked: true,
    );
  }

  Future<void> setPin(String pin) async {
    await _prefs.setString(_pinKey, pin);
    state = state.copyWith(pin: pin, unlocked: true);
  }

  bool checkPin(String pin) => state.pin == pin;

  void unlock() => state = state.copyWith(unlocked: true);

  Future<void> signOut() async {
    await _prefs.remove(_emailKey);
    await _prefs.remove(_pinKey);
    state = const AshaSession();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AshaSession>(
  (ref) => AuthController(ref.watch(prefsProvider)),
);

// -------------------------------------------------------------------- risk

/// Loaded once from the JSON asset at startup.
final riskEngineProvider = FutureProvider<RiskEngine>(
  (ref) => RiskEngine.load(),
);

// -------------------------------------------------------------------- sync

final syncServiceProvider = Provider<SyncService>((ref) => MockSyncService());

final syncWorkerProvider = Provider<SyncWorker>(
  (ref) => SyncWorker(ref.watch(dbProvider), ref.watch(syncServiceProvider)),
);

/// Real device connectivity, folded into the mock service so the demo toggle
/// and genuine airplane mode behave identically.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  bool up(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.contains(ConnectivityResult.none);
  yield up(initial);
  yield* connectivity.onConnectivityChanged.map(up);
});

/// Rebuilt whenever the toggle flips so banners repaint immediately.
final offlineModeProvider = StateProvider<bool>((ref) => false);

final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(dbProvider).watchPendingCount(),
);

final outboxProvider = StreamProvider<List<OutboxData>>(
  (ref) => ref.watch(dbProvider).watchOutbox(),
);

// -------------------------------------------------------------------- data

final mothersProvider = StreamProvider<List<Mother>>(
  (ref) => ref.watch(dbProvider).watchMothers(),
);

final motherProvider = StreamProvider.family<Mother?, String>(
  (ref, id) => ref.watch(dbProvider).watchMother(id),
);

final visitsProvider = StreamProvider.family<List<AncVisit>, String>(
  (ref, motherId) => ref.watch(dbProvider).watchVisits(motherId),
);

final alertsProvider = StreamProvider.family<List<Alert>, String>(
  (ref, motherId) => ref.watch(dbProvider).watchAlerts(motherId),
);

final tasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, status) => ref.watch(dbProvider).watchTasks(status),
);

final ocrServiceProvider = Provider<OcrService>((ref) => const MockOcrService());

// ------------------------------------------------------------ write paths

/// Every write goes through here: local row and outbox entry, one transaction,
/// no network call anywhere on the path.
class VisitRepository {
  VisitRepository(this._db);

  final AppDatabase _db;

  Future<String> saveVisit({
    required String motherId,
    required int visitNo,
    required String recordedBy,
    int? bpSys,
    int? bpDia,
    double? weightKg,
    double? fundalHeightCm,
    double? hb,
    String? urineAlbumin,
    int? fetalHr,
    bool? fetalMovement,
    List<String> dangerSigns = const [],
    bool ifaTaken = false,
    bool calciumTaken = false,
    int? ttDoseGiven,
    String? notes,
    double? gpsLat,
    double? gpsLng,
    List<String> photoPaths = const [],
    String? correctsId,
  }) async {
    final now = DateTime.now();
    final id = 'v-$motherId-${now.microsecondsSinceEpoch}';

    await _db.transaction(() async {
      await _db.into(_db.ancVisits).insert(
            AncVisitsCompanion.insert(
              id: id,
              motherId: motherId,
              visitNo: visitNo,
              visitDate: DateTime(now.year, now.month, now.day),
              bpSys: Value(bpSys),
              bpDia: Value(bpDia),
              weightKg: Value(weightKg),
              fundalHeightCm: Value(fundalHeightCm),
              hb: Value(hb),
              urineAlbumin: Value(urineAlbumin),
              fetalHr: Value(fetalHr),
              fetalMovement: Value(fetalMovement),
              dangerSigns: Value(jsonEncode(dangerSigns)),
              ifaTaken: Value(ifaTaken),
              calciumTaken: Value(calciumTaken),
              ttDoseGiven: Value(ttDoseGiven),
              notes: Value(notes),
              gpsLat: Value(gpsLat),
              gpsLng: Value(gpsLng),
              photoPaths: Value(jsonEncode(photoPaths)),
              recordedBy: recordedBy,
              clientCreatedAt: now,
              correctsId: Value(correctsId),
            ),
          );

      await _db.enqueue(
        entityTable: 'anc_visits',
        recordId: id,
        operation: 'insert',
        payload: payloadOf({
          'id': id,
          'mother_id': motherId,
          'visit_no': visitNo,
          'bp_sys': bpSys,
          'bp_dia': bpDia,
          'weight_kg': weightKg,
          'hb': hb,
          'danger_signs': dangerSigns,
          'client_created_at': now,
        }),
      );
    });

    return id;
  }

  Future<void> saveAlerts(
    String motherId,
    String? visitId,
    List<RiskAlert> alerts,
  ) async {
    if (alerts.isEmpty) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      for (var i = 0; i < alerts.length; i++) {
        final a = alerts[i];
        final id = 'a-$motherId-${now.microsecondsSinceEpoch}-$i';
        await _db.into(_db.alerts).insert(
              AlertsCompanion.insert(
                id: id,
                motherId: motherId,
                ruleId: a.ruleId,
                severity: a.isRed ? 'red' : 'amber',
                messageKn: a.messageKn,
                messageEn: a.messageEn,
                visitId: Value(visitId),
                createdAt: now,
              ),
            );
        await _db.enqueue(
          entityTable: 'alerts',
          recordId: id,
          operation: 'insert',
          payload: payloadOf({
            'id': id,
            'mother_id': motherId,
            'rule_id': a.ruleId,
            'severity': a.isRed ? 'red' : 'amber',
            'created_at': now,
          }),
        );
      }
      await _db.setRiskLevel(motherId, RiskEngine.levelOf(alerts));
    });
  }

  Future<void> createReferral({
    required String motherId,
    required String facility,
    required String reasonKn,
    required String reasonEn,
    String? visitId,
  }) async {
    final now = DateTime.now();
    final id = 'r-$motherId-${now.microsecondsSinceEpoch}';
    await _db.transaction(() async {
      await _db.into(_db.referrals).insert(
            ReferralsCompanion.insert(
              id: id,
              motherId: motherId,
              toFacility: facility,
              reasonKn: reasonKn,
              reasonEn: reasonEn,
              visitId: Value(visitId),
              createdAt: now,
            ),
          );
      await _db.enqueue(
        entityTable: 'referrals',
        recordId: id,
        operation: 'insert',
        payload: payloadOf({
          'id': id,
          'mother_id': motherId,
          'to_facility': facility,
          'created_at': now,
        }),
      );
    });
  }

  Future<String> registerMother({
    required String name,
    required int age,
    required String village,
    required DateTime lmp,
    String? husbandName,
    String? phone,
    String? subCentre,
    String? abhaId,
    int gravida = 1,
    int para = 0,
    String? bloodGroup,
    double? heightCm,
    bool isBpl = false,
    List<String> prevComplications = const [],
    String riskLevel = 'green',
  }) async {
    final now = DateTime.now();
    final id = 'm-${now.microsecondsSinceEpoch}';
    await _db.transaction(() async {
      await _db.into(_db.mothers).insert(
            MothersCompanion.insert(
              id: id,
              name: name,
              age: age,
              husbandName: Value(husbandName),
              phone: Value(phone),
              village: village,
              subCentre: Value(subCentre),
              abhaId: Value(abhaId),
              lmp: lmp,
              gravida: Value(gravida),
              para: Value(para),
              bloodGroup: Value(bloodGroup),
              heightCm: Value(heightCm),
              isBpl: Value(isBpl),
              prevComplications: Value(jsonEncode(prevComplications)),
              riskLevel: Value(riskLevel),
              createdAt: now,
            ),
          );
      await _db.enqueue(
        entityTable: 'mothers',
        recordId: id,
        operation: 'insert',
        payload: payloadOf({
          'id': id,
          'name': name,
          'age': age,
          'village': village,
          'lmp': lmp,
          'created_at': now,
        }),
      );
    });
    return id;
  }

  Future<void> closeTask(String taskId, {String? visitId}) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: const Value('done'),
        closedAt: Value(DateTime.now()),
        closedByVisitId: Value(visitId),
      ),
    );
    await _db.enqueue(
      entityTable: 'tasks',
      recordId: taskId,
      operation: 'update',
      payload: payloadOf({'id': taskId, 'status': 'done'}),
    );
  }
}

final visitRepositoryProvider =
    Provider<VisitRepository>((ref) => VisitRepository(ref.watch(dbProvider)));

// ----------------------------------------------------------------- helpers

int gestationWeeks(DateTime lmp, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return (n.difference(lmp).inDays / 7).floor().clamp(0, 45);
}

int gestationDays(DateTime lmp, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return n.difference(lmp).inDays.remainder(7).clamp(0, 6);
}

DateTime eddOf(DateTime lmp) => lmp.add(const Duration(days: 280));

List<String> decodeIds(String raw) {
  try {
    return (jsonDecode(raw) as List).cast<String>();
  } catch (_) {
    return const [];
  }
}
