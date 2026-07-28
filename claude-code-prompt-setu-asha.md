# Claude Code prompt — Setu ASHA (field app)

Paste the fenced block below into Claude Code as your first message.
Save a copy as `asha/PROMPT.md` so you can re-feed it if a session loses context.

Paste `lib/theme/tokens.dart` and `lib/theme/app_theme.dart` from the design
system file **first**, then say: *"Use these tokens everywhere. No raw `Colors.*`,
no hardcoded padding."* Then paste this.

---

```
Build a Flutter mobile app called "Setu ASHA" that runs on BOTH Android and iOS
from a single codebase. It is the field app of Setu, a maternal health platform
for rural Karnataka, India.

=== WHO USES THIS ===
An ASHA — an accredited community health worker. She is assigned 30-40 pregnant
women in a village. She visits them at home, records their antenatal checkup
vitals, and refers them to the Primary Health Centre when something is wrong.
She is literate but not comfortable in English, works on a low-end Android phone
that is often shared, and spends most of her working day WITH NO MOBILE NETWORK.

Design for her, not for a demo:
- Kannada is the DEFAULT language. English is a toggle.
- She enters data standing in someone's doorway, one-handed, often in sunlight.
- Large numeric keypads. Minimum 56dp tap targets. 18sp body text minimum.
- Never block her on a network call. Ever.

=== THE SINGLE MOST IMPORTANT REQUIREMENT ===
THIS APP MUST WORK COMPLETELY OFFLINE. Every read and every write goes to a local
database first. Nothing in the UI ever waits on a network response. When
connectivity returns, queued writes sync in the background.

This is not a nice-to-have. The core demo is: turn on airplane mode, record a
visit with a dangerously high blood pressure, watch the risk alert fire anyway,
then turn airplane mode off and watch it sync. Build for that.

=== TECH REQUIREMENTS ===
- Flutter, latest stable, null safety, Material 3.
- Android (minSdk 23) and iOS (13.0+) from one codebase.
- State management: Riverpod.
- LOCAL DATABASE: Drift (SQLite). This is real, not mocked. All screens read from
  Drift. This is what makes offline genuinely work.
- SYNC: an abstract `SyncService` with a `MockSyncService` implementation that
  simulates a network with an artificial delay and a toggleable "online/offline"
  flag for demo purposes. A Supabase implementation will be swapped in later
  behind the same interface. Do not couple any UI to a backend.
- OUTBOX PATTERN: every local write also inserts a row into an `outbox` table
  with a status of pending. A background sync worker drains the outbox when
  online, marking rows synced or failed with a retry count.
- Localisation: flutter_localizations + ARB files, lib/l10n/app_kn.arb and
  app_en.arb. Every user-facing string goes through ARB. Kannada is the default
  locale. Never hardcode display text in a widget.
- Font: Noto Sans Kannada via google_fonts.
- Packages: flutter_riverpod, drift, sqlite3_flutter_libs, path_provider,
  google_fonts, camera or image_picker, geolocator, connectivity_plus,
  shared_preferences, url_launcher, qr_flutter, intl, fl_chart.

=== DATA MODEL (Drift tables) ===
Mothers: id, name, age, husband_name, phone, village, sub_centre, abha_id,
  lmp, edd (computed as lmp + 280 days), gravida, para, blood_group, height_cm,
  is_bpl, prev_complications (list), risk_level (green/amber/red), created_at,
  synced.
AncVisits: id, mother_id, visit_no, visit_date, bp_sys, bp_dia, weight_kg,
  fundal_height_cm, hb, urine_albumin, fetal_hr, fetal_movement, danger_signs
  (list), ifa_taken, calcium_taken, tt_dose_given, notes, gps_lat, gps_lng,
  photo_paths, recorded_by, client_created_at, synced.
Tasks: id, mother_id, type, instruction, due_date, priority, status
  (open/done/missed), origin (doctor/system/self), created_at, closed_at.
Alerts: id, mother_id, rule_id, severity, message_kn, message_en, created_at,
  acknowledged.
Referrals: id, mother_id, to_facility, reason, status, created_at.
Outbox: id, table_name, record_id, operation, payload, status, retry_count,
  created_at.

IMPORTANT DESIGN RULE: AncVisits is APPEND-ONLY. Never UPDATE a visit row. A
correction is a new row with a `corrects_id` pointing at the original. This means
two devices writing offline can never conflict, and you get a medico-legal audit
trail for free. Do not implement conflict resolution — the schema removes the
need for it.

=== SCREENS ===

1. LOGIN
   - Email and password. Cache the auth session locally so she stays logged in
     for days without any network. She must NEVER be forced to re-authenticate
     in a village with no signal.
   - A "forgot password" screen (can be a stub).
   - After first login, set a 4-digit PIN. On every subsequent app open, ask for
     the PIN or biometric — the phone is shared, and it holds other women's
     medical records.
   - Language toggle, available before login.

2. HOME — TODAY'S WORK
   - A persistent SYNC BANNER at the very top, shown only when there are pending
     outbox items or no connectivity. Kannada text like "ಆಫ್‌ಲೈನ್ — 3 ನಮೂದುಗಳು
     ಕಾಯುತ್ತಿವೆ" (offline — 3 entries pending). Tapping it opens Sync Status.
   - Three large counter tiles: Assigned mothers · High risk · Visits due.
   - A task list below. Each card shows: mother's name, village, gestational week
     (e.g. "32 ವಾರ"), the reason, the due date, and a red/amber/green status dot.
   - Each task card is visually tagged by origin: "Doctor assigned" tasks get the
     terracotta accent, "Visit overdue" system tasks get amber, self-created get
     neutral. The doctor-assigned ones must stand out — they are the point.
   - Floating action button: register a new mother.

3. REGISTER MOTHER
   Two entry paths side by side at the top of the screen:
   - SCAN THAYI CARD: opens the camera, captures a photo of the woman's existing
     paper Thayi Card, and sends it to an abstract `OcrService`. Provide a
     `MockOcrService` that returns realistic prefilled fields after a 2-second
     delay. A Gemini Vision implementation will be swapped in behind the same
     interface. After OCR returns, show every extracted field in an editable
     form so she CONFIRMS each one — never save OCR output silently.
   - MANUAL ENTRY: the same form, empty.

   Fields: name, age, husband or guardian name, phone, village, sub-centre,
   ABHA id (optional), LMP date (auto-compute EDD and current gestational week
   and show them live), gravida, para, blood group, height, BPL status,
   previous complications as multi-select chips (C-section, stillbirth, PPH,
   hypertension, gestational diabetes, anaemia).

   On save: run the risk engine, and if she is flagged high-risk at registration
   (rule R6), show it immediately. Then show a card listing the government
   schemes she qualifies for.

4. MOTHER PROFILE
   Header: name, age, "GA 32 ವಾರ 4 ದಿನ", EDD, blood group, and a risk badge.
   Four tabs:
   - TIMELINE: reverse-chronological feed mixing ANC visits, doctor notes, lab
     results, TT doses and referrals. Each entry shows WHO recorded it with a
     role icon (ASHA / doctor). This tab is the heart of the product — it is the
     thing that does not exist today. Make it look good.
   - VITALS: BP trend chart, weight trend, Hb values.
   - SCHEMES: which she qualifies for, documents needed.
   - QR CARD: her digital Thayi Card QR, so the ASHA can show it at a facility.

5. NEW ANC VISIT  ← the most-used screen in the app, optimise it hardest
   One field group per card, thumb-reachable, big numeric keypads:
   a. BP systolic / diastolic
   b. Weight, fundal height
   c. Haemoglobin (if tested), urine albumin
   d. Fetal heart rate, fetal movement yes/no
   e. Danger signs as large icon checkboxes: bleeding · severe headache ·
      blurred vision · swelling of face or hands · fever · convulsions ·
      reduced fetal movement
   f. IFA and calcium tablets taken? TT dose given?
   g. Notes, and optional photo attachment

   - A LIVE RISK BANNER pinned to the bottom that updates as she types.
   - Hard range validation. If a value is outside a plausible range, show a
     confirm dialog: "BP 190/120 — ಇದು ಸರಿಯೇ?" (is this correct?). Do not
     silently accept a typo.
   - Capture GPS coordinates and a timestamp silently in the background using
     geolocator. If GPS is unavailable, save the visit anyway with null
     coordinates — NEVER block the save. Rural GPS genuinely fails.
   - Save writes to Drift immediately and returns instantly. It never awaits
     a network call.

6. RISK ALERT & REFERRAL
   - Fires full-screen the moment a red-severity rule triggers, before she can
     save and move on.
   - States plainly in Kannada what is wrong and what to do right now.
   - Buttons: "Refer to PHC" and "Call PHC" (url_launcher, tel:).
   - Referring creates a Referral row and an Alert row locally and queues them
     in the outbox. It works fully offline — the advice appears instantly, the
     referral syncs later.

7. MY TASKS
   - Open, done, and missed tabs.
   - Tasks assigned by the doctor are visually distinct and sorted first.
   - Completing a task links it to the ANC visit that closed it.
   - IMPORTANT: this screen is the receiving end of the doctor assigning work
     back to the field. It is the single most important feature in the whole
     platform. Give it care.

8. INCENTIVE CLAIM SHEET
   - Auto-generated from the visits she has already logged: an itemised list of
     completed activities, the NHM/JSY incentive category each falls under, and
     a running total count of claimable items.
   - Must be readable entirely offline, from local data, even if sync has never
     succeeded.
   - Exportable as a plain summary she can show or share.
   - Do NOT display specific rupee amounts as guaranteed — show activity counts
     and categories, with a note to confirm rates with her ANM supervisor.

9. SYNC STATUS
   - List of pending outbox items with what each one is, when it was created,
     and its retry count.
   - A manual "retry now" button.
   - Clear success and failure states.
   - Judges will ask "what happens when sync fails" — this screen is the answer.

=== RISK ENGINE ===
Implement as a pure Dart function that takes a visit plus the mother's profile
and returns a list of alerts. It runs ON DEVICE, synchronously, with no network.
Keep the rules in a JSON asset (assets/rules/risk_rules.json) loaded at startup
so they can be edited without a rebuild.

R1  BP >= 140/90                                          AMBER  refer to PHC within 48h
R2  BP >= 160/110, OR BP >= 140/90 with headache,
    blurred vision or facial oedema                       RED    pre-eclampsia risk, PHC today
R3  Haemoglobin < 7.0                                     RED    severe anaemia
R4  Haemoglobin 7.0-9.9                                   AMBER  moderate anaemia, check IFA compliance
R5  Any of: bleeding, convulsions, reduced fetal
    movement, fever >= 38.5                               RED    emergency referral
R6  Age < 18 or > 35, OR gravida >= 5, OR previous
    C-section / stillbirth / PPH                          AMBER  high-risk pregnancy at registration
R7  No ANC visit in 30 days or a scheduled date passed    AMBER  auto-create a task for the ASHA
R8  Weight gain < 1 kg in 4 weeks after 20 weeks          AMBER  nutrition counselling

Every alert carries both a Kannada and an English message. Show a permanent
footer on any risk screen: "ಸಲಹೆ ಮಾತ್ರ — ರೋಗನಿರ್ಣಯವಲ್ಲ" (advisory only, not a
diagnosis). The medical officer's clinical judgement always prevails.

Rule R7 runs as a local periodic check that creates Task rows automatically.

=== PLATFORM CONFIGURATION ===
ANDROID (AndroidManifest.xml, build.gradle):
- applicationId com.setu.asha, minSdk 23.
- Permissions: INTERNET, ACCESS_NETWORK_STATE, CAMERA,
  ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION.
- Do NOT request CALL_PHONE — use ACTION_DIAL via url_launcher, no permission
  needed.

iOS (Info.plist):
- Bundle id com.setu.asha, deployment target 13.0.
- NSCameraUsageDescription — scanning the paper Thayi Card.
- NSLocationWhenInUseUsageDescription — confirming a home visit location.
- LSApplicationQueriesSchemes including "tel".
- CFBundleLocalizations including "kn" and "en".

=== BUILD ORDER ===
Make each step run before moving to the next:
1. Scaffold, theme, Riverpod, ARB localisation with Kannada default.
2. Drift database, all tables, and the outbox table. Seed 20 realistic mothers,
   three of them already carrying red flags. Seed data matters — a demo with
   three mothers looks like a toy.
3. Login, PIN lock, cached session.
4. Home with the sync banner and task list.
5. Register Mother, manual entry path only.
6. New ANC Visit with the live risk banner. Risk engine as a pure function.
7. Risk Alert and Referral screens.
8. Outbox and the sync worker, with a demo toggle to force offline mode.
9. My Tasks.
10. Mother Profile with the timeline.
11. Scan Thayi Card with MockOcrService.
12. Incentive Claim Sheet, Sync Status.

Steps 1-9 are the demo. Everything after can stay rough.

=== TESTING THE THING THAT MATTERS ===
After step 8, verify this exact sequence works:
- Force offline mode.
- Record a visit with BP 165/110 and the headache danger sign.
- The red pre-eclampsia alert appears immediately, in Kannada.
- The referral saves and appears in the outbox.
- The home screen sync banner shows the pending count.
- Turn offline mode off.
- The outbox drains and the banner clears.
If that sequence does not work end to end, nothing else in this app matters.

=== WHAT NOT TO DO ===
- Do not await a network call anywhere in the UI layer.
- Do not UPDATE an AncVisits row. Corrections are new rows.
- Do not block a save because GPS is unavailable.
- Do not hardcode display strings outside the ARB files.
- Do not build conflict resolution — the append-only schema removes the need.
- Do not add analytics, crash reporting, or a real backend yet.

Start with step 1. After each step, tell me what you built and what to verify
before continuing.
```

---

## Note on the two apps

Setu ASHA and Setu Thayi share the theme files and the ARB approach but nothing
else. Do not try to share a codebase — a package boundary costs more time than it
saves over 24 hours. Copy `theme/` into both and move on.

The one thing that MUST match across both apps and the doctor console is the
Drift/Postgres column naming. That lives in `core/schema.sql`. Commit it before
anyone writes UI in either app.
