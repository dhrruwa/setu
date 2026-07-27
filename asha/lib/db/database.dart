import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

// Column names here MUST match core/schema.sql and the doctor console. This is
// the one thing that has to stay identical across all three clients.

class Mothers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get husbandName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get village => text()();
  TextColumn get subCentre => text().nullable()();
  TextColumn get abhaId => text().nullable()();
  DateTimeColumn get lmp => dateTime()();
  IntColumn get gravida => integer().withDefault(const Constant(1))();
  IntColumn get para => integer().withDefault(const Constant(0))();
  TextColumn get bloodGroup => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  BoolColumn get isBpl => boolean().withDefault(const Constant(false))();

  /// JSON list of ids: cSection, stillbirth, pph, hypertension, gdm, anaemia.
  TextColumn get prevComplications =>
      text().withDefault(const Constant('[]'))();

  /// green | amber | red — the worst level currently known for her.
  TextColumn get riskLevel => text().withDefault(const Constant('green'))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// APPEND-ONLY. A correction is a new row whose [correctsId] points at the
/// original. Two devices writing offline can therefore never conflict, and the
/// audit trail comes for free. Never write an UPDATE against this table.
class AncVisits extends Table {
  TextColumn get id => text()();
  TextColumn get motherId => text().references(Mothers, #id)();
  IntColumn get visitNo => integer()();
  DateTimeColumn get visitDate => dateTime()();
  IntColumn get bpSys => integer().nullable()();
  IntColumn get bpDia => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get fundalHeightCm => real().nullable()();
  RealColumn get hb => real().nullable()();
  TextColumn get urineAlbumin => text().nullable()();
  IntColumn get fetalHr => integer().nullable()();
  BoolColumn get fetalMovement => boolean().nullable()();

  /// JSON list of danger sign ids.
  TextColumn get dangerSigns => text().withDefault(const Constant('[]'))();
  BoolColumn get ifaTaken => boolean().withDefault(const Constant(false))();
  BoolColumn get calciumTaken => boolean().withDefault(const Constant(false))();
  IntColumn get ttDoseGiven => integer().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get gpsLat => real().nullable()();
  RealColumn get gpsLng => real().nullable()();
  TextColumn get photoPaths => text().withDefault(const Constant('[]'))();
  TextColumn get recordedBy => text()();
  DateTimeColumn get clientCreatedAt => dateTime()();
  TextColumn get correctsId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get motherId => text().references(Mothers, #id)();

  /// ancVisit | followUp | referralFollowUp | labResult | counselling
  TextColumn get type => text()();
  TextColumn get instructionKn => text().nullable()();
  TextColumn get instructionEn => text().nullable()();
  DateTimeColumn get dueDate => dateTime()();

  /// high | normal
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// open | done | missed
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// doctor | system | self — doctor-assigned work is the point of the product.
  TextColumn get origin => text().withDefault(const Constant('self'))();
  TextColumn get closedByVisitId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Alerts extends Table {
  TextColumn get id => text()();
  TextColumn get motherId => text().references(Mothers, #id)();
  TextColumn get ruleId => text()();

  /// red | amber
  TextColumn get severity => text()();
  TextColumn get messageKn => text()();
  TextColumn get messageEn => text()();
  TextColumn get visitId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Referrals extends Table {
  TextColumn get id => text()();
  TextColumn get motherId => text().references(Mothers, #id)();
  TextColumn get toFacility => text()();
  TextColumn get reasonKn => text()();
  TextColumn get reasonEn => text()();

  /// pending | accepted | completed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get visitId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Every local write also lands here. The sync worker drains it when online.
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get tableName => text()();
  TextColumn get recordId => text()();

  /// insert | update
  TextColumn get operation => text()();
  TextColumn get payload => text()();

  /// pending | syncing | synced | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Mothers, AncVisits, Tasks, Alerts, Referrals, Outbox],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // ------------------------------------------------------------- mothers

  Stream<List<Mother>> watchMothers() =>
      (select(mothers)..orderBy([(m) => OrderingTerm(expression: m.name)]))
          .watch();

  Future<List<Mother>> allMothers() => select(mothers).get();

  Stream<Mother?> watchMother(String id) =>
      (select(mothers)..where((m) => m.id.equals(id))).watchSingleOrNull();

  Future<Mother?> findMother(String id) =>
      (select(mothers)..where((m) => m.id.equals(id))).getSingleOrNull();

  Stream<List<Mother>> watchHighRisk() => (select(mothers)
        ..where((m) => m.riskLevel.isIn(['red', 'amber']))
        ..orderBy([(m) => OrderingTerm(expression: m.riskLevel)]))
      .watch();

  Future<void> setRiskLevel(String motherId, String level) =>
      (update(mothers)..where((m) => m.id.equals(motherId)))
          .write(MothersCompanion(riskLevel: Value(level)));

  // -------------------------------------------------------------- visits

  /// Latest first. Superseded rows (those corrected by a later row) are
  /// filtered out by [effectiveVisits].
  Stream<List<AncVisit>> watchVisits(String motherId) => (select(ancVisits)
        ..where((v) => v.motherId.equals(motherId))
        ..orderBy([
          (v) => OrderingTerm(
              expression: v.visitDate, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<AncVisit>> visitsFor(String motherId) => (select(ancVisits)
        ..where((v) => v.motherId.equals(motherId))
        ..orderBy([(v) => OrderingTerm(expression: v.visitDate)]))
      .get();

  Future<AncVisit?> lastVisit(String motherId) async {
    final rows = await (select(ancVisits)
          ..where((v) => v.motherId.equals(motherId))
          ..orderBy([
            (v) => OrderingTerm(
                expression: v.visitDate, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  // --------------------------------------------------------------- tasks

  Stream<List<Task>> watchTasks(String status) => (select(tasks)
        ..where((t) => t.status.equals(status))
        ..orderBy([
          // Doctor-assigned work sorts first — it is the point of the product.
          (t) => OrderingTerm(expression: t.origin),
          (t) => OrderingTerm(expression: t.dueDate),
        ]))
      .watch();

  Future<List<Task>> openTasksFor(String motherId) => (select(tasks)
        ..where((t) => t.motherId.equals(motherId) & t.status.equals('open')))
      .get();

  // -------------------------------------------------------------- alerts

  Stream<List<Alert>> watchAlerts(String motherId) => (select(alerts)
        ..where((a) => a.motherId.equals(motherId))
        ..orderBy([
          (a) => OrderingTerm(
              expression: a.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();

  // -------------------------------------------------------------- outbox

  Stream<List<OutboxData>> watchOutbox() => (select(outbox)
        ..orderBy([
          (o) => OrderingTerm(
              expression: o.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Stream<int> watchPendingCount() {
    final count = outbox.id.count();
    final query = selectOnly(outbox)
      ..addColumns([count])
      ..where(outbox.status.isIn(['pending', 'failed']));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<List<OutboxData>> pendingOutbox() => (select(outbox)
        ..where((o) => o.status.isIn(['pending', 'failed']))
        ..orderBy([(o) => OrderingTerm(expression: o.createdAt)]))
      .get();

  /// The only way anything gets written. Local row and outbox entry go in one
  /// transaction, so a queued change can never be lost or half-written.
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        id: 'ob-$recordId-${DateTime.now().microsecondsSinceEpoch}',
        tableName: tableName,
        recordId: recordId,
        operation: operation,
        payload: jsonEncode(payload),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> markOutbox(String id, String status, {String? error}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(
          status: Value(status),
          lastError: Value(error),
          syncedAt: Value(status == 'synced' ? DateTime.now() : null),
        ),
      );

  Future<void> bumpRetry(String id, String error) async {
    final row =
        await (select(outbox)..where((o) => o.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (update(outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(
        status: const Value('failed'),
        retryCount: Value(row.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'setu_asha.sqlite'));
    // Needed on older Android for a working, up-to-date SQLite.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    return NativeDatabase.createInBackground(file);
  });
}
