# Claude Code prompt — Setu Care (doctor console)

Two parts. Paste **Part 1** first, then say *"Use these tokens everywhere. No
arbitrary hex values, no hardcoded spacing."* Then paste **Part 2**.

Save Part 2 as `care/PROMPT.md` so you can re-feed it if a session loses context.

---

## Part 1 — `src/styles/tokens.css`

```css
:root {
  /* Brand */
  --ink:        #10312B;
  --teal:       #0F5257;
  --teal-soft:  #E4EFEC;
  --terra:      #D2603F;
  --terra-soft: #FBEAE3;

  /* Surfaces */
  --bg:      #F7F2EA;
  --card:    #FFFFFF;
  --divider: #E6DED2;

  /* Text */
  --text:      #10312B;
  --text-soft: #5E6E6A;

  /* Clinical status — semantic only, never decorative */
  --red:       #B23A32;
  --red-soft:  #FBEAE8;
  --amber:     #C98A2B;
  --amber-soft:#FBF2E2;
  --green:     #3E7C59;
  --green-soft:#E8F1EB;

  /* Type */
  --font: 'Inter', -apple-system, system-ui, sans-serif;
  --fs-display: 34px;
  --fs-h1:      24px;
  --fs-h2:      19px;
  --fs-body:    15px;
  --fs-small:   13px;
  --fs-label:   11px;   /* uppercase, letter-spacing 0.06em */

  /* Spacing — only these */
  --s-xs: 4px;
  --s-sm: 8px;
  --s-md: 16px;
  --s-lg: 24px;
  --s-xl: 40px;
  --radius: 12px;
  --shadow: 0 1px 3px rgba(16,49,43,.06), 0 4px 12px rgba(16,49,43,.04);
}
```

This is a clinical tool, not a consumer app. Dense, calm, information-first.
Red and amber appear **only** as clinical status — never as decoration, never as
a button colour.

---

## Part 2 — the build prompt

```
Build a React web dashboard called "Setu Care". It is the doctor-facing console
of Setu, a maternal health platform for rural Karnataka, India.

=== WHO USES THIS ===
A medical officer at a Primary Health Centre. She has 150-200 pregnant women in
her catchment across several villages. ASHA community health workers visit those
women at home and record antenatal vitals in a mobile app; that data arrives
here. She reviews it, adds clinical notes, orders labs, and — this is the point
of the whole product — assigns follow-up tasks BACK to the ASHA worker who
visits that mother.

She uses a laptop at a clinic desk. English interface. She is time-poor and
clinically trained: show her dense, accurate information, not big friendly cards.

=== TECH REQUIREMENTS ===
- React 18 + TypeScript + Vite.
- Routing: react-router-dom.
- State/data: TanStack Query.
- Styling: plain CSS modules or Tailwind — your choice, but every colour and
  spacing value must come from the tokens in src/styles/tokens.css. No arbitrary
  hex values anywhere.
- Charts: Recharts. Keep them minimal — thin lines, no gradients, no 3D.
- Icons: lucide-react.
- DATA LAYER: do NOT connect to a real backend. Define typed API functions in
  src/api/ that return mock data after a short artificial delay. Keep all mock
  data in src/api/mockData.ts so it is easy to edit before a demo. A Supabase
  client will be swapped in behind the same function signatures later. Do not
  couple any component to a backend.
- Auth: mock. Email and password, any credentials succeed, store a fake session
  in localStorage. Protected routes redirect to /login.

=== DATA SHAPES ===
Mother: id, name, age, husbandName, phone, village, subCentre, ashaId, ashaName,
  lmp, edd, gestationalWeeks, gravida, para, bloodGroup, heightCm, isBpl,
  prevComplications[], riskLevel ('green'|'amber'|'red'), riskReasons[],
  lastVisitDate.
AncVisit: id, motherId, visitNo, visitDate, recordedBy, source ('asha'|'doctor'),
  bpSys, bpDia, weightKg, fundalHeightCm, hb, urineAlbumin, fetalHr,
  fetalMovement, dangerSigns[], ifaTaken, calciumTaken, ttDoseGiven, notes.
Lab: id, motherId, type, value, unit, resultDate, orderedBy, reportUrl.
Task: id, motherId, createdBy, assignedToAshaId, assignedToAshaName, type,
  instruction, dueDate, priority, status ('open'|'done'|'missed'), createdAt.
Referral: id, motherId, fromUser, toFacility, reason, status, createdAt.
AshaWorker: id, name, phone, subCentre, assignedMotherCount, village.
ClinicalNote: id, motherId, authorName, body, createdAt.

Seed 25 mothers across 4 villages. Four of them must carry red risk flags and
six amber, with realistic vitals histories of 4-8 visits each. Realistic seed
data matters — a demo with three mothers looks like a toy.

=== LAYOUT ===
A persistent left sidebar with the Setu Care mark and navigation: Dashboard,
All Mothers, Referrals, ASHA Workers, Analytics. A top bar showing the facility
name and a user menu on the right containing Profile and Logout. Logout clears
the session and returns to /login — it is a menu action, NOT a page or a route.
Content area on --bg, cards on --card.

=== SCREENS ===

1. LOGIN (/login)
   Centred card. Email, password, submit. Setu Care wordmark and one line of
   context. Any credentials succeed.

2. DASHBOARD (/) — lands here after login
   - Four summary tiles across the top: total mothers registered, high-risk
     count, visits overdue, open referrals. Number large, label small.
   - "Needs attention" panel: mothers with red or amber flags, most severe
     first, showing name, gestational age, village, the flag reason, the last
     reading, and which ASHA covers her. Each row links to her record.
   - "Recent activity" feed: new visits recorded by ASHAs in the last 48 hours,
     newest first, each showing who recorded it.
   - A small "registrations this month by village" bar chart.

3. ALL MOTHERS (/mothers)
   - Searchable, filterable table: name, age, gestational age, village, ASHA,
     risk badge, last visit date.
   - Filters: risk level, village, ASHA worker, overdue only.
   - Risk badge is a small coloured pill using the semantic tokens. This is the
     only place colour carries meaning in the table.
   - Sortable columns. Row click opens the mother's record.

4. MOTHER RECORD (/mothers/:id)
   Three-column layout:
   LEFT — identity panel: name, age, husband, phone, village, sub-centre,
     blood group, GA and EDD, gravida/para, BPL status, and her risk flags as
     chips with the reason spelled out.
   CENTRE — tabbed:
     · Timeline: reverse-chronological feed mixing ANC visits, clinical notes,
       labs, TT doses and referrals. Every entry shows WHO recorded it with a
       role icon, ASHA or doctor. This is the heart of the product — it is what
       does not exist today. Make it look considered.
     · Vitals Trends: BP chart with systolic and diastolic lines plus a
       reference band at 140/90; weight chart; haemoglobin chart. Thin lines,
       no fills, no gradients.
     · Labs & Scans: table of results with dates and a report link.
     · Clinical Notes: list of notes, newest first, plus an add-note composer.
   RIGHT — actions rail: "Assign Task to ASHA" as the primary button, then
     Order Lab, Add Note, Create Referral, Update Risk Status.

5. ASSIGN TASK TO ASHA  ← the most important feature in the product
   A MODAL over the Mother Record, not a separate route. She must not lose her
   place.
   Fields: task type (revisit / recheck BP / confirm medication taken / bring to
   PHC / counselling), due date, free-text instruction, priority.
   It shows which ASHA it will be assigned to, resolved automatically from the
   mother's assignment — the doctor does not pick.
   On submit: optimistic update, toast confirmation, and the task appears in the
   mother's timeline immediately, tagged as doctor-assigned.
   Give this modal real care. In the live demo we submit here and then cut to
   the ASHA's phone to show it has arrived.

6. REFERRALS (/referrals)
   Table of referrals: mother, from which ASHA, to which facility, reason,
   status (open / arrived / closed), created date. Filter by status. Ability to
   mark a referral closed with an outcome note.

7. ASHA WORKERS (/asha)
   Cards or a table: name, phone, sub-centre, villages covered, number of
   mothers assigned, visits recorded this month, open tasks. Clicking one shows
   the mothers she covers.

8. PHC ANALYTICS (/analytics)
   - Registrations over time, line chart.
   - High-risk cases by village, bar chart.
   - Missed and overdue visits by village, bar chart.
   - ANC visit completion rate.
   Keep it to four charts. This screen answers the "does it scale" question; it
   is not the product.

9. PROFILE (/profile)
   Doctor's name, designation, facility, contact details, editable. A change
   password form. Nothing else.

=== BUILD ORDER ===
Make each step run before moving on:
1. Vite + TS scaffold, tokens.css, sidebar and top bar shell, routing.
2. Mock API layer and seed data.
3. Login and protected routes.
4. Dashboard.
5. All Mothers table with filters.
6. Mother Record — identity panel and Timeline tab.
7. ASSIGN TASK MODAL.
8. Vitals Trends tab.
9. Referrals, ASHA Workers.
10. Labs, Clinical Notes, Analytics, Profile.

Steps 1-8 are the demo. Everything after can stay rough.

=== DESIGN DIRECTION ===
This is a clinical tool. Dense, calm, legible. Generous whitespace between
groups but tight within them. Tables over cards wherever there is real data.
System sans-serif, 15px body. Cards are white with a subtle shadow and a 12px
radius — no borders and shadows together, pick one.

Red and amber appear ONLY as clinical status: risk badges, alert rows, overdue
markers. Never as a button, never as an accent, never decorative. If red loses
its meaning, the whole interface stops working.

The primary action colour is teal. Terracotta is reserved for the single most
important action on a screen — on the Mother Record, that is Assign Task.

=== WHAT NOT TO DO ===
- Do not use arbitrary colours or spacing outside the tokens.
- Do not make Assign Task a separate page — it is a modal.
- Do not make Logout a route.
- Do not add a real backend, auth provider, or analytics.
- Do not add a marketing landing page. The app starts at Login.
- Do not use gradients, glassmorphism, or decorative colour anywhere.

Start with step 1. After each step, tell me what you built and what to verify
before continuing.
```

---

## The one thing to check when step 7 lands

Assign Task must resolve the ASHA **automatically** from the mother's assignment
— the doctor never picks from a dropdown. If Claude Code adds an ASHA selector,
remove it. The whole premise is that the system already knows who covers that
mother; making the doctor choose reintroduces exactly the manual coordination
the product exists to eliminate.
