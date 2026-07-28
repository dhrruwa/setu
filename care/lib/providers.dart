import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/care_api.dart';
import 'data/models.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final apiProvider = Provider<CareApi>((ref) => CareApi());

// -------------------------------------------------------------------- auth

/// Mock auth: any credentials succeed and a fake session is kept locally.
/// Protected routes bounce to /login when this is null.
class Session {
  const Session({required this.email});
  final String email;
}

class AuthController extends StateNotifier<Session?> {
  AuthController(this._prefs) : super(_read(_prefs));

  static const _key = 'care_session_email';
  final SharedPreferences _prefs;

  static Session? _read(SharedPreferences prefs) {
    final email = prefs.getString(_key);
    return email == null ? null : Session(email: email);
  }

  Future<void> signIn(String email) async {
    await Future.delayed(const Duration(milliseconds: 350));
    await _prefs.setString(_key, email);
    state = Session(email: email);
  }

  Future<void> signOut() async {
    await _prefs.remove(_key);
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthController, Session?>(
  (ref) => AuthController(ref.watch(prefsProvider)),
);

// -------------------------------------------------------------------- data

final dashboardProvider = FutureProvider<DashboardSummary>(
  (ref) => ref.watch(apiProvider).getDashboard(),
);

final mothersProvider = FutureProvider<List<Mother>>(
  (ref) => ref.watch(apiProvider).getMothers(),
);

final motherProvider = FutureProvider.family<Mother?, String>(
  (ref, id) => ref.watch(apiProvider).getMother(id),
);

final visitsProvider = FutureProvider.family<List<AncVisit>, String>(
  (ref, motherId) => ref.watch(apiProvider).getVisits(motherId),
);

final labsProvider = FutureProvider.family<List<Lab>, String>(
  (ref, motherId) => ref.watch(apiProvider).getLabs(motherId),
);

final notesProvider = FutureProvider.family<List<ClinicalNote>, String>(
  (ref, motherId) => ref.watch(apiProvider).getNotes(motherId),
);

final motherTasksProvider = FutureProvider.family<List<Task>, String>(
  (ref, motherId) => ref.watch(apiProvider).getTasks(motherId: motherId),
);

final ashasProvider = FutureProvider<List<AshaWorker>>(
  (ref) => ref.watch(apiProvider).getAshas(),
);

final referralsProvider = FutureProvider<List<Referral>>(
  (ref) => ref.watch(apiProvider).getReferrals(),
);

// ----------------------------------------------------- mothers list filters

@immutable
class MotherFilters {
  const MotherFilters({
    this.query = '',
    this.risk,
    this.village,
    this.ashaId,
    this.overdueOnly = false,
    this.sort = MotherSort.risk,
  });

  final String query;
  final RiskLevel? risk;
  final String? village;
  final String? ashaId;
  final bool overdueOnly;
  final MotherSort sort;

  MotherFilters copyWith({
    String? query,
    RiskLevel? risk,
    String? village,
    String? ashaId,
    bool? overdueOnly,
    MotherSort? sort,
    bool clearRisk = false,
    bool clearVillage = false,
    bool clearAsha = false,
  }) =>
      MotherFilters(
        query: query ?? this.query,
        risk: clearRisk ? null : (risk ?? this.risk),
        village: clearVillage ? null : (village ?? this.village),
        ashaId: clearAsha ? null : (ashaId ?? this.ashaId),
        overdueOnly: overdueOnly ?? this.overdueOnly,
        sort: sort ?? this.sort,
      );

  bool get isActive =>
      query.isNotEmpty ||
      risk != null ||
      village != null ||
      ashaId != null ||
      overdueOnly;
}

enum MotherSort { risk, name, gestation, lastVisit }

final motherFiltersProvider =
    StateProvider<MotherFilters>((ref) => const MotherFilters());

/// The filtered, sorted list the table renders.
final filteredMothersProvider = Provider<List<Mother>>((ref) {
  final all = ref.watch(mothersProvider).valueOrNull ?? const <Mother>[];
  final f = ref.watch(motherFiltersProvider);

  final q = f.query.trim().toLowerCase();
  var list = all.where((m) {
    if (q.isNotEmpty &&
        !m.name.toLowerCase().contains(q) &&
        !m.village.toLowerCase().contains(q) &&
        !m.ashaName.toLowerCase().contains(q)) {
      return false;
    }
    if (f.risk != null && m.riskLevel != f.risk) return false;
    if (f.village != null && m.village != f.village) return false;
    if (f.ashaId != null && m.ashaId != f.ashaId) return false;
    if (f.overdueOnly && !m.isOverdue) return false;
    return true;
  }).toList();

  list.sort((a, b) => switch (f.sort) {
        MotherSort.risk =>
          b.riskLevel.index.compareTo(a.riskLevel.index),
        MotherSort.name => a.name.compareTo(b.name),
        MotherSort.gestation =>
          b.gestationalWeeks.compareTo(a.gestationalWeeks),
        MotherSort.lastVisit => (a.lastVisitDate ?? DateTime(2000))
            .compareTo(b.lastVisitDate ?? DateTime(2000)),
      });
  return list;
});
