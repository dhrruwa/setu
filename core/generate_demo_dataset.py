#!/usr/bin/env python3
"""Builds the one demo dataset all three Setu apps show.

During the demo we cut between Thayi Setu, ASHA Setu and Setu Care and the same
records must appear on each screen, so the dataset is defined once here and
emitted twice: as SQL for Supabase (what the apps actually read once someone is
signed in) and as Dart for the offline/mock path. Editing either output by hand
is how the two drift apart; edit this file instead.

Everything is expressed as an offset from DEMO_DATE, so moving that one constant
moves the whole dataset and nothing goes stale overnight.
"""

import datetime as dt
import json
import uuid

# The tables key on uuid, but a demo is only debuggable if the same record is
# recognisable on every screen. So the readable ids below (m-001, a-001, v-001)
# are the source of truth here and each maps to a fixed uuid derived from it —
# stable across machines, runs and all three apps.
NS = uuid.UUID("5e70de00-0000-4000-8000-000000000000")


def uid(demo_id: str) -> str:
    return str(uuid.uuid5(NS, demo_id))

DEMO_DATE = dt.date(2026, 7, 28)


def d(offset_days: int) -> dt.date:
    return DEMO_DATE + dt.timedelta(days=offset_days)


def iso(date: dt.date) -> str:
    return date.isoformat()


# --------------------------------------------------------------- accounts
DOCTOR = {
    "id": "d-001",
    "name": "Dr. Dhrruwa H L",
    "email": "dhrruwa@gmail.com",
    "designation": "Medical Officer",
    "facility": "Halebeedu Primary Health Centre",
    "district": "Hassan",
}

ASHAS = [
    {"id": "a-001", "name": "Akhila M N", "name_kn": "ಅಖಿಲಾ ಎಂ ಎನ್",
     "email": "mn.akhiladi711@gmail.com", "phone": "+91 99001 44556",
     "sub_centre": "Halebeedu Sub-Centre", "villages": ["Halebeedu", "Belur Road"]},
    {"id": "a-002", "name": "Sunita Gowda", "name_kn": "ಸುನೀತಾ ಗೌಡ",
     "email": "sunita.gowda@asha.kar.gov.in", "phone": "+91 99002 71834",
     "sub_centre": "Adagur Sub-Centre", "villages": ["Adagur"]},
    {"id": "a-003", "name": "Nagamma S", "name_kn": "ನಾಗಮ್ಮ ಎಸ್",
     "email": "nagamma.s@asha.kar.gov.in", "phone": "+91 99003 60217",
     "sub_centre": "Konanur Sub-Centre", "villages": ["Konanur"]},
]

# Village centres in Hassan district, so the ASHA app's directions land on a
# real map rather than in the sea.
VILLAGES = {
    "Halebeedu":  (13.2137, 75.9946, "Halebeedu Sub-Centre"),
    "Belur Road": (13.1628, 75.8648, "Halebeedu Sub-Centre"),
    "Adagur":     (12.9385, 76.0512, "Adagur Sub-Centre"),
    "Konanur":    (12.6389, 76.0631, "Konanur Sub-Centre"),
}

KN = {
    "Halebeedu": "ಹಳೇಬೀಡು", "Belur Road": "ಬೇಲೂರು ರಸ್ತೆ",
    "Adagur": "ಅಡಗೂರು", "Konanur": "ಕೊಣನೂರು",
}

# --------------------------------------------------------------- the mother
# Lakshmi is the demo subject and appears in all three apps. Her LMP puts her at
# 32 weeks on the demo date; her five visits are a deliberate story — weight
# climbing normally, blood pressure creeping up over the last two, haemoglobin
# drifting down. Visit 6 is left empty: that is the one recorded live.
LAKSHMI = {
    "id": "m-001",
    "name": "Lakshmi Bhat", "name_kn": "ಲಕ್ಷ್ಮಿ ಭಟ್",
    "email": "hljeevan18@gmail.com",
    "age": 24, "husband": "Ramesh Bhat", "phone": "+91 98450 11223",
    "village": "Halebeedu", "district": "Hassan",
    "lmp": dt.date(2025, 12, 18), "edd": dt.date(2025, 12, 18) + dt.timedelta(days=280),
    "gravida": 2, "para": 1, "blood_group": "B+", "height_cm": 154,
    "is_bpl": True, "prev_complications": ["previous C-section"],
    "risk": "amber", "asha": "a-001",
}

LAKSHMI_VISITS = [
    # (id, date, no, sys, dia, weight, hb, fundal, fhr)
    ("v-001", dt.date(2026, 2, 14), 1, 118, 76, 48.2, 11.2, 12, 148),
    ("v-002", dt.date(2026, 3, 20), 2, 120, 78, 50.1, 10.8, 17, 144),
    ("v-003", dt.date(2026, 5,  2), 3, 126, 82, 52.6, 10.4, 22, 146),
    ("v-004", dt.date(2026, 6, 11), 4, 134, 86, 55.0,  9.8, 27, 142),
    ("v-005", dt.date(2026, 7,  9), 5, 138, 88, 57.4,  9.6, 31, 140),
]
TT1, TT2 = dt.date(2026, 3, 20), dt.date(2026, 4, 24)

# ------------------------------------------------------------ other mothers
# Names are invented. Progressions are generated from a fixed seed so every run
# produces the same charts — a doctor comparing two demos must see the same
# curves, and a random dataset would look like noise on the trend screens.
NAMES = [
    ("Bhavya Gowda", "ಭವ್ಯಾ ಗೌಡ"), ("Rukmini Shetty", "ರುಕ್ಮಿಣಿ ಶೆಟ್ಟಿ"),
    ("Chaitra Nayak", "ಚೈತ್ರಾ ನಾಯಕ"), ("Manjula Devi", "ಮಂಜುಳಾ ದೇವಿ"),
    ("Shwetha Rao", "ಶ್ವೇತಾ ರಾವ್"), ("Kavitha B M", "ಕವಿತಾ ಬಿ ಎಂ"),
    ("Girija Hegde", "ಗಿರಿಜಾ ಹೆಗ್ಡೆ"), ("Ashwini Kumari", "ಅಶ್ವಿನಿ ಕುಮಾರಿ"),
    ("Renuka Poojary", "ರೇಣುಕಾ ಪೂಜಾರಿ"), ("Vidya Shankar", "ವಿದ್ಯಾ ಶಂಕರ್"),
    ("Sowmya Achar", "ಸೌಮ್ಯಾ ಆಚಾರ್"), ("Pushpa Latha", "ಪುಷ್ಪಾ ಲತಾ"),
    ("Deepa Naik", "ದೀಪಾ ನಾಯ್ಕ್"), ("Hemavathi K", "ಹೇಮಾವತಿ ಕೆ"),
    ("Jayanthi Rai", "ಜಯಂತಿ ರೈ"), ("Nandini Bhatta", "ನಂದಿನಿ ಭಟ್ಟ"),
    ("Roopa Shetty", "ರೂಪಾ ಶೆಟ್ಟಿ"), ("Savithri N", "ಸಾವಿತ್ರಿ ಎನ್"),
    ("Triveni Gowda", "ತ್ರಿವೇಣಿ ಗೌಡ"), ("Usha Kiran", "ಉಷಾ ಕಿರಣ್"),
    ("Vasanthi M", "ವಸಂತಿ ಎಂ"), ("Yashoda Bai", "ಯಶೋದಾ ಬಾಯಿ"),
    ("Anitha Suvarna", "ಅನಿತಾ ಸುವರ್ಣ"), ("Lalitha Prasad", "ಲಲಿತಾ ಪ್ರಸಾದ್"),
]
HUSBANDS = ["Suresh", "Mahesh", "Prakash", "Ganesh", "Ravi", "Naveen", "Kiran",
            "Harish", "Umesh", "Santhosh", "Dinesh", "Manjunath"]
BLOOD = ["O+", "A+", "B+", "AB+", "O-", "A-", "B-"]

# The three RED cases are named in the brief and drive the doctor's dashboard.
RED = {
    "m-002": ("Severe anaemia, Hb 6.4 g/dL", "hb"),
    "m-007": ("Blood pressure 164/108", "bp"),
    "m-014": ("Reduced fetal movement reported", "fm"),
}
# Six amber: two overdue for a visit, one aged over 35, three borderline.
AMBER = ["m-004", "m-006", "m-011", "m-016", "m-019", "m-023"]
OVERDUE = ["m-011", "m-019"]
OVER_35 = ["m-016"]


def lcg(seed):
    """Tiny deterministic generator — same dataset on every machine, every run."""
    state = seed
    while True:
        state = (state * 1103515245 + 12345) % (2 ** 31)
        yield state / (2 ** 31)


def build_mothers():
    rnd = lcg(20260728)
    mothers, visits = [], []

    # ---- Lakshmi
    v = VILLAGES[LAKSHMI["village"]]
    mothers.append({
        **{k: LAKSHMI[k] for k in
           ("id", "name", "name_kn", "email", "age", "husband", "phone",
            "village", "district", "gravida", "para", "blood_group",
            "height_cm", "is_bpl", "risk", "asha")},
        "sub_centre": v[2],
        "lmp": iso(LAKSHMI["lmp"]), "edd": iso(LAKSHMI["edd"]),
        "weeks": (DEMO_DATE - LAKSHMI["lmp"]).days // 7,
        "prev_complications": LAKSHMI["prev_complications"],
        "home_lat": round(v[0] + 0.0021, 6), "home_lng": round(v[1] - 0.0014, 6),
        "home_note": "Third house past the temple, blue door",
        "risk_reasons": ["Blood pressure rising over the last two visits",
                         "Haemoglobin 9.6 g/dL"],
    })
    for vid, date, no, sys, dia, wt, hb, fh, fhr in LAKSHMI_VISITS:
        visits.append({
            "id": vid, "mother_id": "m-001", "no": no, "date": iso(date),
            "sys": sys, "dia": dia, "weight": wt, "hb": hb, "fundal": fh,
            "fhr": fhr, "urine": "Nil", "danger": [], "ifa": True, "cal": True,
            "tt": 1 if date == TT1 else (2 if date == TT2 else None),
            "asha": "a-001",
        })

    # ---- the other twenty-four
    # Akhila carries 18 of the 25, which is what a real ASHA's caseload looks
    # like; the remaining 7 sit in the two neighbouring sub-centres so the
    # doctor console shows more than one worker's name.
    for i, (name, name_kn) in enumerate(NAMES, start=2):
        mid = f"m-{i:03d}"
        if i <= 18:
            village = "Halebeedu" if i % 2 == 0 else "Belur Road"
        else:
            village = "Adagur" if i % 2 == 0 else "Konanur"
        lat, lng, sub = VILLAGES[village]

        weeks = 8 + int(next(rnd) * 31)          # 8..38
        if mid in OVER_35:
            age = 36 + int(next(rnd) * 4)
        else:
            age = 20 + int(next(rnd) * 14)
        gravida = 1 + int(next(rnd) * 4)
        para = max(0, gravida - 1 - (1 if next(rnd) < 0.4 else 0))
        lmp = DEMO_DATE - dt.timedelta(days=weeks * 7)

        risk, reasons = "green", []
        if mid in RED:
            risk, reasons = "red", [RED[mid][0]]
        elif mid in AMBER:
            risk = "amber"
            reasons = (["Visit overdue"] if mid in OVERDUE
                       else ["Mother aged over 35"] if mid in OVER_35
                       else ["Haemoglobin below 11 g/dL"])

        # 18 mothers to Akhila; the rest split between the other two workers so
        # the doctor console shows more than one name.
        if village in ("Halebeedu", "Belur Road"):
            asha = "a-001"
        else:
            asha = "a-002" if village == "Adagur" else "a-003"

        n_visits = 2 + int(next(rnd) * 6)        # 2..7
        n_visits = min(n_visits, max(2, weeks // 5))

        # Plausible progressions: weight rises, BP mostly stable, Hb drifts down.
        base_wt = 44 + next(rnd) * 12
        base_hb = 12.4 - next(rnd) * 1.6
        base_sys, base_dia = 108 + next(rnd) * 14, 68 + next(rnd) * 10

        for k in range(n_visits):
            gw = max(6, int(weeks - (n_visits - 1 - k) * (weeks / max(n_visits, 1))))
            date = lmp + dt.timedelta(days=gw * 7)
            if date > DEMO_DATE:
                date = DEMO_DATE - dt.timedelta(days=3)
            last = k == n_visits - 1

            wt = round(base_wt + gw * 0.32 + next(rnd) * 0.4, 1)
            hb = round(base_hb - gw * 0.045 + (next(rnd) - 0.5) * 0.2, 1)
            sys = int(base_sys + gw * 0.25 + (next(rnd) - 0.5) * 5)
            dia = int(base_dia + gw * 0.16 + (next(rnd) - 0.5) * 4)
            danger = []

            if last and mid in RED:
                kind = RED[mid][1]
                if kind == "hb":
                    hb = 6.4
                elif kind == "bp":
                    sys, dia = 164, 108
                else:
                    danger = ["reduced_fetal_movement"]

            visits.append({
                "id": f"v-{mid[2:]}-{k + 1}", "mother_id": mid, "no": k + 1,
                "date": iso(date), "sys": sys, "dia": dia, "weight": wt,
                "hb": max(5.8, hb), "fundal": min(gw, 38) if gw >= 12 else None,
                "fhr": 136 + int(next(rnd) * 14) if gw >= 12 else None,
                "urine": "Nil" if next(rnd) > 0.12 else "Trace",
                "danger": danger, "ifa": next(rnd) > 0.15, "cal": next(rnd) > 0.2,
                "tt": None, "asha": asha,
            })

        last_visit = max(v["date"] for v in visits if v["mother_id"] == mid)
        mothers.append({
            "id": mid, "name": name, "name_kn": name_kn, "email": None,
            "age": age, "husband": f"{HUSBANDS[i % len(HUSBANDS)]} {name.split()[-1]}",
            "phone": f"+91 9{8 + i % 2}4{i:02d}0 {10000 + i * 137:05d}"[:17],
            "village": village, "sub_centre": sub, "district": "Hassan",
            "lmp": iso(lmp), "edd": iso(lmp + dt.timedelta(days=280)),
            "weeks": weeks, "gravida": gravida, "para": para,
            "blood_group": BLOOD[i % len(BLOOD)],
            "height_cm": 148 + int(next(rnd) * 14),
            "is_bpl": next(rnd) < 0.6, "prev_complications": [],
            "risk": risk, "risk_reasons": reasons, "asha": asha,
            "home_lat": round(lat + (next(rnd) - 0.5) * 0.012, 6),
            "home_lng": round(lng + (next(rnd) - 0.5) * 0.012, 6),
            "home_note": None, "last_visit": last_visit,
        })
    return mothers, visits


# ---------------------------------------------------------------- tasks
TASKS = [
    ("t-001", "m-004", "Confirm IFA tablets are being taken daily",
     "ಕಬ್ಬಿಣದ ಮಾತ್ರೆಗಳನ್ನು ಪ್ರತಿದಿನ ತೆಗೆದುಕೊಳ್ಳುತ್ತಿದ್ದಾರೆಯೇ ಎಂದು ಖಚಿತಪಡಿಸಿ",
     2, "doctor", "open", "normal"),
    ("t-002", "m-011", "Visit overdue by 12 days — schedule ANC 4",
     "ಭೇಟಿ 12 ದಿನ ತಡವಾಗಿದೆ — ನಾಲ್ಕನೇ ತಪಾಸಣೆ ನಿಗದಿಪಡಿಸಿ",
     0, "system", "open", "high"),
    ("t-003", "m-019", "Recheck BP, was 142/90 last visit",
     "ರಕ್ತದೊತ್ತಡ ಮತ್ತೆ ಪರೀಕ್ಷಿಸಿ, ಕಳೆದ ಬಾರಿ 142/90 ಇತ್ತು",
     4, "doctor", "open", "high"),
    ("t-004", "m-006", "Counselling on institutional delivery",
     "ಆಸ್ಪತ್ರೆಯಲ್ಲಿ ಹೆರಿಗೆ ಬಗ್ಗೆ ಸಲಹೆ ನೀಡಿ",
     -1, "self", "done", "normal"),
    # The fifth slot, for m-001, is deliberately empty. The doctor assigns it
    # live in step 8 of the demo and it must arrive on the ASHA's phone.
]

REFERRALS = [
    ("r-001", "m-002", "Hassan District Hospital", "Severe anaemia, Hb 6.4", "open", -2),
    ("r-002", "m-007", "Halebeedu PHC", "BP 164/108", "arrived", -5),
    ("r-003", "m-021", "Halebeedu PHC", "Routine 3rd trimester", "closed", -14),
]

# Lakshmi is BPL, in Karnataka, and this is her second delivery. PMMVY is shown
# as a refusal with its reason rather than hidden — a scheme she cannot get is
# something she should be told about, not left to wonder over.
SCHEMES = [
    ("thayi_bhagya", "Thayi Bhagya", True,
     "Free delivery and care at a government hospital.", None),
    ("jsy", "Janani Suraksha Yojana", True,
     "Cash assistance for delivering in a health facility.", None),
    ("madilu", "Madilu Kit", True,
     "A kit of baby and mother supplies after delivery.", None),
    ("jssk", "Janani Shishu Suraksha Karyakram", True,
     "Free delivery, medicines, tests, food and transport.", None),
    ("pmmvy", "Pradhan Mantri Matru Vandana Yojana", False,
     "Maternity benefit for the first living child.",
     "This is your second delivery, and this scheme covers the first living "
     "child only."),
]


def sql_str(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        if not value:
            return "'{}'"
        inner = ",".join('"' + str(v).replace('"', '\\"') + '"' for v in value)
        return "'{" + inner + "}'"
    return "'" + str(value).replace("'", "''") + "'"


def emit_sql(mothers, visits):
    out = ["""-- THE demo dataset. Generated by core/generate_demo_dataset.py — do not edit
-- by hand; edit the generator and re-run it, or this will drift from the Dart
-- copy the apps use offline.
--
-- Everything the three apps show during the demo lives here, keyed on stable
-- ids (m-001, a-001, v-001) so the same record is recognisable on every screen.

begin;

-- Clear the previous demo caseload. Only demo rows: anything a health worker
-- entered during a run is theirs and is removed with it, deliberately, so each
-- demo starts from the same place.
delete from public.prescriptions;
delete from public.access_grants;
delete from public.alerts;
delete from public.tasks;
delete from public.referrals;
delete from public.labs;
delete from public.anc_visits;
delete from public.mothers;
delete from public.asha_workers;
delete from public.staff where role in ('asha','doctor');
"""]

    # --- asha workers
    out.append("\n-- ASHA workers -----------------------------------------------------------")
    for a in ASHAS:
        out.append(
            "insert into public.asha_workers (id, name_en, name_kn, phone, "
            "sub_centre_en, sub_centre_kn, village, latitude, longitude) values "
            f"({sql_str(uid(a['id']))}, {sql_str(a['name'])}, {sql_str(a['name_kn'])}, "
            f"{sql_str(a['phone'])}, {sql_str(a['sub_centre'])}, "
            f"{sql_str(a['sub_centre'].replace('Sub-Centre', 'ಉಪ ಕೇಂದ್ರ'))}, "
            f"{sql_str(a['villages'][0])}, {VILLAGES[a['villages'][0]][0]}, "
            f"{VILLAGES[a['villages'][0]][1]});")

    out.append("\n-- Staff logins -----------------------------------------------------------")
    for a in ASHAS:
        out.append(
            "insert into public.staff (role, name, email, sub_centre, facility) values "
            f"('asha', {sql_str(a['name'])}, {sql_str(a['email'])}, "
            f"{sql_str(a['sub_centre'])}, 'Halebeedu Primary Health Centre');")
    out.append(
        "insert into public.staff (role, name, email, facility) values "
        f"('doctor', {sql_str(DOCTOR['name'])}, {sql_str(DOCTOR['email'])}, "
        f"{sql_str(DOCTOR['facility'])});")

    out.append("\n-- Mothers ----------------------------------------------------------------")
    for m in mothers:
        cols = ("id, qr_token, thayi_card_number, name_en, name_kn, email, age, "
                "guardian_en, phone, village_en, village_kn, sub_centre, "
                "district_en, district_kn, lmp, gravida, para, delivery_number, "
                "blood_group, height_cm, is_bpl, prev_complications, risk_level, "
                "risk_reasons, asha_worker_id, asha_id, home_lat, home_lng, "
                "home_note, plans_institutional_delivery, "
                "home_located_at, last_visit_date")
        vals = [
            # The token is what proves the card was physically shown, so it is
            # derived rather than sequential — nobody can guess the next one.
            uid(m["id"]), uid("qr:" + m["id"]).replace("-", "")[:24],
            m["id"], m["name"], m["name_kn"], m["email"], m["age"],
            m["husband"], m["phone"], m["village"], KN[m["village"]],
            m["sub_centre"], m["district"], "ಹಾಸನ", m["lmp"], m["gravida"],
            m["para"], m["para"] + 1, m["blood_group"], m["height_cm"],
            m["is_bpl"], m["prev_complications"], m["risk"], m["risk_reasons"],
            uid(m["asha"]), uid(m["asha"]), m["home_lat"], m["home_lng"],
            m["home_note"], True,
        ]
        rendered = ", ".join(sql_str(v) for v in vals)
        last = m.get("last_visit") or max(
            (v["date"] for v in visits if v["mother_id"] == m["id"]), default=None)
        out.append(f"insert into public.mothers ({cols}) values ({rendered}, "
                   f"now() - interval '20 days', {sql_str(last)});")

    out.append("\n-- ANC visits -------------------------------------------------------------")
    for v in visits:
        asha_name = next(a["name"] for a in ASHAS if a["id"] == v["asha"])
        out.append(
            "insert into public.anc_visits (id, mother_id, visit_no, visit_date, "
            "bp_sys, bp_dia, weight_kg, hb, fundal_height_cm, fetal_hr, "
            "urine_albumin, danger_signs, ifa_taken, calcium_taken, tt_dose_given, "
            "recorded_by, source) values ("
            f"{sql_str(uid(v['id']))}, {sql_str(uid(v['mother_id']))}, {v['no']}, {sql_str(v['date'])}, "
            f"{v['sys']}, {v['dia']}, {v['weight']}, {v['hb']}, "
            f"{sql_str(v['fundal'])}, {sql_str(v['fhr'])}, {sql_str(v['urine'])}, "
            f"{sql_str(v['danger'])}, {sql_str(v['ifa'])}, {sql_str(v['cal'])}, "
            f"{sql_str(v['tt'])}, {sql_str(asha_name)}, 'asha_app');")

    out.append("\n-- Labs -------------------------------------------------------------------")
    for m in mothers:
        mv = [v for v in visits if v["mother_id"] == m["id"]]
        if not mv:
            continue
        latest = max(mv, key=lambda v: v["date"])
        out.append(
            "insert into public.labs (mother_id, type, value, unit, result_date, ordered_by) values "
            f"({sql_str(uid(m['id']))}, 'Haemoglobin', {sql_str(str(latest['hb']))}, 'g/dL', "
            f"{sql_str(latest['date'])}, 'Halebeedu PHC');")
        out.append(
            "insert into public.labs (mother_id, type, value, unit, result_date, ordered_by) values "
            f"({sql_str(uid(m['id']))}, 'Blood group', {sql_str(m['blood_group'])}, null, "
            f"{sql_str(mv[0]['date'])}, 'Halebeedu PHC');")
        out.append(
            "insert into public.labs (mother_id, type, value, unit, result_date, ordered_by) values "
            f"({sql_str(uid(m['id']))}, 'Urine albumin', {sql_str(latest['urine'])}, null, "
            f"{sql_str(latest['date'])}, 'Halebeedu PHC');")
        out.append(
            "insert into public.labs (mother_id, type, value, unit, result_date, ordered_by) values "
            f"({sql_str(uid(m['id']))}, 'HIV / VDRL', 'Non-reactive', null, "
            f"{sql_str(mv[0]['date'])}, 'Halebeedu PHC');")

    out.append("\n-- Alerts, raised from readings already in the record ----------------------")
    for mid, (reason, kind) in RED.items():
        mv = [v for v in visits if v["mother_id"] == mid]
        latest = max(mv, key=lambda v: v["date"])
        if kind == "hb":
            kn = f"ರಕ್ತದ ಪ್ರಮಾಣ ತುಂಬಾ ಕಡಿಮೆ ಇದೆ ({latest['hb']} g/dL). ತಕ್ಷಣ ವೈದ್ಯರನ್ನು ಕಾಣಿಸಿ."
            rule = "hb_severe"
        elif kind == "bp":
            kn = f"ರಕ್ತದೊತ್ತಡ ತುಂಬಾ ಹೆಚ್ಚಿದೆ ({latest['sys']}/{latest['dia']}). ತಕ್ಷಣ ಆಸ್ಪತ್ರೆಗೆ ಕಳುಹಿಸಿ."
            rule = "bp_high"
        else:
            kn = "ಮಗುವಿನ ಚಲನೆ ಕಡಿಮೆಯಾಗಿದೆ ಎಂದು ತಾಯಿ ಹೇಳಿದ್ದಾರೆ. ತಕ್ಷಣ ಆರೋಗ್ಯ ಕೇಂದ್ರಕ್ಕೆ ಕಳುಹಿಸಿ."
            rule = "fetal_movement"
        out.append(
            "insert into public.alerts (mother_id, rule_id, severity, message_kn, "
            "message_en, visit_id) values ("
            f"{sql_str(uid(mid))}, {sql_str(rule)}, 'red', {sql_str(kn)}, "
            f"{sql_str(reason + '. Refer without delay.')}, {sql_str(uid(latest['id']))});")

    out.append("\n-- Tasks ------------------------------------------------------------------")
    for tid, mid, en, kn, due, origin, status, priority in TASKS:
        mother = next(m for m in mothers if m["id"] == mid)
        asha = next(a for a in ASHAS if a["id"] == mother["asha"])
        out.append(
            "insert into public.tasks (id, mother_id, created_by, assigned_to_asha_id, "
            "assigned_to_asha_name, type, instruction_kn, instruction_en, due_date, "
            "priority, status, origin) values ("
            f"{sql_str(uid(tid))}, {sql_str(uid(mid))}, {sql_str(DOCTOR['name'])}, "
            f"{sql_str(uid(asha['id']))}, {sql_str(asha['name'])}, 'home_visit', "
            f"{sql_str(kn)}, {sql_str(en)}, {sql_str(iso(d(due)))}, "
            f"{sql_str(priority)}, {sql_str(status)}, {sql_str(origin)});")

    out.append("\n-- Referrals --------------------------------------------------------------")
    for rid, mid, facility, reason, status, when in REFERRALS:
        out.append(
            "insert into public.referrals (id, mother_id, from_user, to_facility, "
            "reason_en, reason_kn, status, created_at) values ("
            f"{sql_str(uid(rid))}, {sql_str(uid(mid))}, {sql_str(DOCTOR['name'])}, "
            f"{sql_str(facility)}, {sql_str(reason)}, {sql_str(reason)}, "
            f"{sql_str(status)}, now() - interval '{abs(when)} days');")

    out.append("\ncommit;")
    return "\n".join(out)


def emit_dart(mothers, visits):
    """The same numbers, for the offline/mock path in each Flutter app."""
    payload = {
        "demoDate": iso(DEMO_DATE),
        "doctor": DOCTOR,
        "ashas": ASHAS,
        "mothers": mothers,
        "visits": visits,
        "tasks": [
            {"id": t[0], "motherId": t[1], "instructionEn": t[2],
             "instructionKn": t[3], "dueDate": iso(d(t[4])), "origin": t[5],
             "status": t[6], "priority": t[7]}
            for t in TASKS
        ],
        "referrals": [
            {"id": r[0], "motherId": r[1], "referredTo": r[2], "reason": r[3],
             "status": r[4], "daysAgo": abs(r[5])}
            for r in REFERRALS
        ],
        "schemes": [
            {"id": s[0], "name": s[1], "eligible": s[2], "summary": s[3],
             "reasonNotEligible": s[4]}
            for s in SCHEMES
        ],
    }
    body = json.dumps(payload, ensure_ascii=False, indent=2)
    return f'''/// The one demo dataset, shared by Thayi Setu, ASHA Setu and Setu Care.
///
/// Generated by core/generate_demo_dataset.py — do not edit by hand. The same
/// generator writes the Supabase copy, which is what the apps read once someone
/// signs in; this file is the offline and mock path. Editing one and not the
/// other is exactly the drift the generator exists to prevent.
///
/// Ids are stable across all three apps (m-001 is Lakshmi everywhere), so a
/// record recognised on one screen is the same record on the next.
///
/// No real patient data. Every person here is invented apart from the three
/// team email addresses used to sign in.
library;

/// The date the dataset is anchored to. Everything else is derived from it, so
/// the demo does not go stale overnight.
const String kDemoDate = '{iso(DEMO_DATE)}';

/// Logins. In mock mode any OTP code is accepted.
const String kThayiDemoEmail = '{LAKSHMI["email"]}';
const String kAshaDemoEmail = '{ASHAS[0]["email"]}';
const String kCareDemoEmail = '{DOCTOR["email"]}';

const Map<String, dynamic> kSeedData = {body};
'''


if __name__ == "__main__":
    import os
    import sys

    mothers, visits = build_mothers()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    sql_path = os.path.join(root, "core", "demo_dataset.sql")
    with open(sql_path, "w", encoding="utf-8") as f:
        f.write(emit_sql(mothers, visits) + "\n")

    dart = emit_dart(mothers, visits)
    written = [sql_path]
    for app in ("thayi", "asha", "care"):
        target = os.path.join(root, app, "lib", "data", "seed_data.dart")
        if os.path.isdir(os.path.dirname(target)):
            with open(target, "w", encoding="utf-8") as f:
                f.write(dart)
            written.append(target)

    reds = [m["id"] for m in mothers if m["risk"] == "red"]
    ambers = [m["id"] for m in mothers if m["risk"] == "amber"]
    print(f"mothers={len(mothers)}  visits={len(visits)}  "
          f"red={len(reds)}{reds}  amber={len(ambers)}  "
          f"green={len(mothers) - len(reds) - len(ambers)}")
    print("a-001 caseload:",
          sum(1 for m in mothers if m["asha"] == "a-001"))
    for p in written:
        print("wrote", os.path.relpath(p, root))
