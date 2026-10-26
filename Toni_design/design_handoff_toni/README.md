# Toni — Strichsystem · Build Spec for Claude Code

> **What this is:** a complete, self-contained brief for implementing **Toni**, a group "Strichsystem" (tally / strike-tracking) app, as a real application. Hand this whole folder to Claude Code. Read this README top to bottom before writing code.

---

## 0. How to use this brief

The `reference/` folder contains an **HTML/React prototype**. It is a **design reference**, not production code to ship. It demonstrates the exact intended look, layout, copy, data model, and behavior. Your job is to **recreate it in a real, production codebase** using current best practices — not to copy the prototype's CDN-React-via-Babel setup.

Two hard requirements the user added on top of the prototype:

1. **Mobile-first.** Design and build for a phone screen first; scale *up* to tablet/desktop. The prototype leans desktop (max-width 1080, three-column grids); you must invert that priority. Touch targets ≥ 44px.
2. **Dark mode by default, light mode available.** The prototype is dark-only. You must ship **both themes**, defaulting to dark, with a user-toggle that persists. Full light palette is specified in §8.

The language of the entire UI is **German** (`lang="de"`). Keep all copy in German exactly as in the prototype unless told otherwise.

### Recommended stack
If there is no existing codebase, use: **React + TypeScript + Vite**, CSS variables for theming (no CSS-in-JS needed), and a tiny state store (Zustand or React Context + reducer). The prototype persists to `localStorage`; for a real product, design the store behind a thin data layer so it can be swapped for a backend (Supabase/Firebase/Postgres) later — see §7. If a codebase already exists, follow its conventions and ignore the stack suggestion.

---

## 1. What Toni is

Toni is a playful accountability tracker for a fixed group of people (flatmates, friends, a team). When someone does something annoying, they get a **Strich** ("a mark / strike") with a reason. Marks accumulate per **period** (a calendar month, or a free-form "occasion" like a ski trip). The person with the most marks in a period **wins** that period (the "loser" wins, ironically — it's a Hall of Shame). Monthly wins roll up into a yearly champion.

Marks are added two ways:
- **Direct entry** — a logged-in member just records it.
- **Vote** — a member proposes a mark; the group votes Ja/Nein; simple majority decides; if accepted, the mark is created automatically.

Tone is irreverent and German-casual ("Glückwunsch zur Schande", "die ewige Hall of Shame").

---

## 2. Fidelity

**High-fidelity.** Colors, type, spacing, copy, and interactions in the prototype are final. Recreate the UI faithfully, then apply the mobile-first and dual-theme requirements. Do not invent new screens or features.

---

## 3. Roles & auth

Three states: **logged out**, **logged-in member** (`mitglied`), **logged-in admin**.

| Capability | Logged out | Member | Admin |
|---|---|---|---|
| View overview, leaderboards, breakdowns | ✓ | ✓ | ✓ |
| Add a Strich (direct or start vote) | — | ✓ | ✓ |
| Cast a vote | — | ✓ | ✓ |
| Resolve a vote | — | ✓ | ✓ |
| Edit own profile (color, avatar, password) | — | ✓ | ✓ |
| Admin dashboard (people, logins, periods, all strikes) | — | — | ✓ |

- Auth is username + password. A user account is optionally linked to a **person** (`personId`) — that link is what lets a member set "their" color/avatar and is whose ballot is cast when they vote.
- Session persists (prototype: `localStorage` key `toni_session_v1`). Real build: secure session/JWT, but keep the "stay logged in" behavior.
- Gated actions trigger a **login modal** with a contextual reason string (e.g. *"Nur angemeldete Mitglieder können abstimmen."*). The Admin route shows a lock-gate screen if a non-admin reaches it.
- Demo logins seeded by the prototype: `max / toni2026` (admin), `lena / toni`, `jonas / toni` (members). Keep a demo-login affordance in the login modal (chips that prefill credentials) for the prototype/staging build.

---

## 4. Screens & views

The app is a single authenticated shell with a sticky top app-bar, two routes (**Übersicht**, **Admin**), and three modals (Add-Strich, Login, Profil). On mobile, prefer modals that **slide up from the bottom** (already the prototype pattern) and a persistent FAB for the primary "add" action.

### 4.1 App bar (`Header`)
- **Brand**: a rotated square "mark" tile (accent background, dark glyph "T", `border-radius: 11px`, slight `rotate(-4deg)`, accent glow shadow) + wordmark **TONI** with a dim `strich` suffix. Tapping it goes to Übersicht.
- **Nav**: "Übersicht" and "Admin" (Admin shows a small lock icon for non-admins). Active link gets a filled pill background.
- **Right cluster** (logged in): primary **+ Strich** button, a "whoami" button (avatar + username + "Profil bearbeiten" subtitle → opens Profil), and a logout icon button. Logged out: a ghost **Anmelden** button.
- Sticky, translucent, `backdrop-filter: blur(14px)`, bottom hairline border.
- **Mobile**: collapse the username text (`whoami__menu` hidden < 560px), shrink nav padding, hide the word "Strich" on the add button (icon only). Consider moving primary nav to a bottom tab bar on phones — acceptable enhancement as long as both routes stay one tap away.

### 4.2 Übersicht (Overview) — default route
Top of page is **conditional**:
- **If there are open votes** → render a **VoteZone**: a stack of `VoteBanner`s (see §4.4).
- **Else** → render the **WideBoard**: a rotating podium (auto-advances every 6s, pauses on hover; dot controls to switch). Two views:
  1. **`Jahr <year>`** — "Monatssiege — wer führt die Saison an" — ranking of how many monthly periods each person has won this year.
  2. **`Alle Jahre`** — "Jahressiege — die ewige Hall of Shame" — ranking of yearly titles.
  - Podium shows top 3 in 2-1-3 visual order, rank-1 block tallest (heights 92/64/46px) with amber treatment and glow; ranks 4+ appear as a wrapped row of **restchips** (rank · avatar · name · tally). Every podium/chip entry is tappable → opens the **Person breakdown** modal scoped to that view.

Below the conditional header: the **Ranks** section — one `RankList` panel **per currently-live period** (month + any active occasions whose date range includes today). Each list:
- Header: period label + "läuft" live tag, date range subtitle, and total marks badge (amber, big number + "Striche" caption).
- Rows ranked by mark count desc, then name. Each row: rank (medal color for 1/2/3), avatar, name (★ crown on the leader if count>0), tally, and a thin progress bar (`width = count/max`, filled with the person's color). Rows are buttons → open Person breakdown scoped to that period. Chevron appears on hover.
- Desktop: 3 columns. **Mobile: single column, stacked.**
- Footer hint: *"Tipp: Auf einen Namen tippen zeigt, woraus sich die Striche zusammensetzen."*

A **FAB** (bottom-right, accent, `+`, rotates 90° on hover) appears on Übersicht when logged in — same action as the header add button.

### 4.3 Person breakdown (`PersonDetail` modal)
Opened by tapping any person anywhere. Scoped to a context (`periode` / `jahr` / `alle`). Shows:
- Header: avatar, name, "<n> Striche · <scope label>", big tally in person color.
- Three stat tiles: marks in scope · monthly wins this year · yearly titles.
- Grouped list by period (newest first): each group shows period label (⚡ bolt icon for occasions), date range, a "★ gewonnen" badge if they won it, the count, then each mark's reason with a colored dot; marks created via voting get an "Abstimmung" badge.
- Empty state: *"Keine Striche in diesem Zeitraum."*

### 4.4 Vote banner (`VoteBanner`)
A live, colored card (tinted with the target person's color via a `--vb` custom prop):
- Header: pulsing live dot + "Abstimmung läuft", and "<voted>/<total> abgestimmt · <relative time>".
- Body: target avatar, headline "Strich für **<name>**?", chips (period, "vorgeschlagen von <author>"), the quoted reason.
- A **vote bar**: Ja segment (green) vs Nein segment (red), flex-weighted by counts; "noch keine Stimmen" overlay when empty. Legend below: "Ja N" · leading status ("Strich führt" / "Freispruch führt" / "Unentschieden") · "Nein N".
- Actions (logged in): two big buttons — **Freispruch** (nein) and **Strich!** (ja), each showing an "on" filled state once you've voted that way. Logged out: a single "Zum Abstimmen anmelden" lock button.
- A dashed "Abstimmung auswerten →" resolve button (disabled until ≥1 ballot). Resolving sets status to angenommen/abgelehnt by majority; if angenommen, a real mark is created (source `abstimmung`).

### 4.5 Add Strich (`AddStrikeModal`)
Three numbered steps in a bottom-sheet modal titled "Neuer Toni-Strich":
1. **Wer hat Mist gebaut?** — grid of tappable name-chips (avatar + name), selected chip outlined in person color.
2. **Wann?** — select of currently-live periods only (label + date range). If none live: hint *"Aktuell läuft kein Zeitraum — im Admin anlegen."*
3. **Was ist passiert?** — textarea, max 140 chars, with live char counter. Valid when person + period chosen and reason length > 2.
- Two actions: **Abstimmung starten** (ghost, ⚡) and **Direkt eintragen** (primary, ✓). Note line explains majority rule.
- On submit: a success **flash** (animated check or bolt mark + message) then auto-close after ~950ms.

### 4.6 Admin dashboard (`AdminDashboard`, admin only)
Tabbed: **Personen & Logins**, **Perioden**, **Aktionen**. Tab bar is a horizontally-scrollable segmented control.
- **Personen & Logins**: add a person (inline form). Each person is a card: avatar, editable name (save on blur), this-year mark count, activate/deactivate toggle, delete (confirms — removes person + their marks + their login). Below each: the linked login row (role badge, editable username, password with show/hide eye, role toggle Mitglied/Admin, remove) or an "Login für <name> anlegen" affordance that opens an inline create form.
- **Perioden & Anlässe**: add either a **Monat** (month select + year) or an **Anlass/Freitext** (name + start date + end date). List all periods (newest first) with editable start/end date inputs, "läuft" tag if live, ⚡ for occasions, delete button.
- **Aktionen**: filterable (by period) scrollable list of every mark — avatar, person name (in color), period, "Abstimmung" badge if applicable, reason, and a delete button. Empty state per filter.

### 4.7 Profil (`ProfileModal`)
- Header: avatar, person name, "<role> · @<username>".
- If linked to a person: upload a profile image (center-cropped to 256×256 JPEG via canvas — keep this behavior) or remove it; pick a color from the `PALETTE` swatches (checkmark on current).
- If not linked: hint that only a linked person can set color/avatar.
- Always: **change password** form (new + repeat, validation: length ≥ 2 and match; success/error message). Works without admin rights.

---

## 5. Interactions & behavior

- **Routing**: client-side, two routes. Admin route renders a lock-gate for non-admins (different copy for logged-out vs non-admin member) with a CTA.
- **Modals**: close on scrim mousedown, on Esc, and on the × button; lock body scroll while open; slide-up + fade entrance (`~0.28s cubic-bezier(.2,.9,.25,1)`). On mobile they should be true bottom sheets (full width, rounded top corners, max-height ~92vh, internal scroll).
- **WideBoard rotation**: `setInterval` 6000ms, cleared on unmount and paused while hovered/touched; dots jump directly; body re-animates on view change (`wbIn`, translateY 10→0, .45s).
- **Vote bar / leaderboard bars**: animate width/flex transitions (`.4–.5s`).
- **FAB hover**: `scale(1.06) rotate(90deg)`; active `scale(.96)`.
- **Buttons**: active state `translateY(1px) scale(.99)`; disabled `opacity .4`.
- **Live pulse**: the live dot uses an expanding box-shadow keyframe (`pulse`, 1.6s infinite). Respect `prefers-reduced-motion` — disable the looping pulse and decorative auto-rotation (or pause it) when reduced motion is requested.
- **Relative time** (`timeAgo`): "gerade eben" / "vor N Min" / "vor N Std" / "vor N Tagen" / dd. MMM. German locale.
- **Tally display** has three modes (user/tweak setting): **roman** (default, e.g. `XIV`), **zahl** (plain number), **striche** (hand-drawn 5-bar gate marks). Zero state renders the word "sauber" (italic, dim). Keep all three; default roman.

---

## 6. State model

App-level UI state: current route, add-modal open, login-modal `{open, reason}`, profile-modal open, and theme + tweak settings (§8).

Domain state (the store):
```
people[]   { id, name, active, color, avatar? }
periods[]  { id, type: "monat"|"freitext", year,
             month?            // monat only
             label?            // freitext only
             start, end,       // ISO "YYYY-MM-DD" (monat auto-derives from month bounds)
             active }
strikes[]  { id, personId, periodId, reason, createdAt: ISO, source: "direkt"|"abstimmung" }
votes[]    { id, personId, periodId, reason, createdBy, createdAt, status: "offen"|"angenommen"|"abgelehnt",
             resolvedAt?, ballots: { [personId]: "ja"|"nein" } }
users[]    { id, username, password, role: "admin"|"mitglied", personId }
currentPeriodId
```

### Derived selectors (recreate these — they drive the whole UI)
- `activePeople` — people where `active`.
- `currentPeriod` — first live month period, else first live period, else newest month, else first.
- `isPeriodLive(p)` — today within `[start, end]` inclusive.
- `leaderboard(scope, opts)` — counts per active person for scope `periode` (by `periodId`) / `jahr` (by year) / `alle`; sorted by count desc then name.
- `periodWinners(periodId)` — person(s) with the max (>0) marks in a period (ties → multiple).
- `yearWins(year)` — per person, number of monthly periods won that year (drives the "Jahr" board).
- `yearTitles()` — per person, number of years they were the year-champion (drives "Alle Jahre").
- `monthsWon(personId, year)`, `yearChampion(year)`.
- `breakdownByPeriod(personId)` — marks grouped by period, periods newest-first.
- `livePeriods()` — all periods live today (month first, then occasions), fallback to currentPeriod.
- `countInYear(personId, year)`, `personStrikes(personId)`, `feed(periodId)`, `openVotes`.

### Actions
`login, logout, addStrike, removeStrike, startVote, castVote(voteId, personId, choice), resolveVote, dismissVote, addPerson, togglePerson, removePerson, renamePerson, updatePerson(patch), addAccount, updateUser(patch), removeUser, addPeriod(month, year), addFreitext(label, year, start, end), updatePeriod(patch), togglePeriod, removePeriod, setCurrentPeriod, ensureFreitext, resetDemo`.

**resolveVote** logic: count ja vs nein in `ballots`; status = `ja > nein ? angenommen : abgelehnt`; on `angenommen`, push a new strike with `source: "abstimmung"`.

See `reference/store.jsx` for the exact seed data and reference implementations of every selector and action.

---

## 7. Persistence / backend

Prototype uses `localStorage` (`toni_store_v10`, `toni_session_v1`) with a `seed()` for first run. For production:
- Put all reads/writes behind a single data-access module so the storage engine is swappable.
- Recommended real backend: Supabase or Firebase — tables/collections mirror §6. Passwords must be **hashed server-side** (never store plaintext as the prototype does). Votes and strikes should be append-only-ish with auth checks matching the role table in §3.
- Keep an offline-friendly cache + optimistic updates so the snappy feel survives.

---

## 8. Design tokens & theming

### 8.1 Type
- **Headlines** (`--font-head`): **Space Grotesk** (tweakable: Archivo Black, Syne, Bricolage Grotesque). Letter-spacing `-0.01em` on h1–h3.
- **Body** (`--font-body`): **Hanken Grotesk**.
- **Mono** (`--font-mono`): **Space Mono** — used for counts, meta, timestamps, ranks, labels.
- Base line-height 1.5; antialiased.

### 8.2 Accent colors (theme-independent, tweakable set)
Default **lime** accent. Four accent sets — each defines `acid` (primary), `amber` (gold/winner), `magenta` (vote/secondary):
| Set | acid | amber | magenta |
|---|---|---|---|
| lime (default) | `#a3e635` | `#f59e0b` | `#f472b6` |
| cyan | `#22d3ee` | `#fbbf24` | `#f472b6` |
| magenta | `#f472b6` | `#f59e0b` | `#a3e635` |
| violet | `#c084fc` | `#fbbf24` | `#22d3ee` |

Semantic vote colors: **Ja** `--ja: #34d399`, **Nein** `--nein: #fb7185` (both themes).

### 8.3 Neutrals — dual theme

Drive theming with `data-theme` on `<html>` + `color-scheme`. **Default dark.** Provide a toggle (place it in the Tweaks/settings and/or profile); persist choice to `localStorage` (e.g. `toni_theme`). On first load with no stored value, default to dark (optionally honor `prefers-color-scheme`, but dark is the specified default).

**Dark (default)** — neutrals are oklch, hue 265:
```css
:root, [data-theme="dark"] {
  color-scheme: dark;
  --bg:     oklch(0.165 0.012 265);
  --bg-1:   oklch(0.205 0.015 265);
  --bg-2:   oklch(0.245 0.017 265);
  --bg-3:   oklch(0.295 0.018 265);
  --line:   oklch(0.34 0.018 265);
  --line-2: oklch(0.42 0.02 265);
  --text:   oklch(0.96 0.004 265);
  --dim:    oklch(0.72 0.012 265);
  --dim-2:  oklch(0.56 0.014 265);
}
```
Dark body has a subtle accent radial glow at the top:
`radial-gradient(120% 80% at 50% -10%, color-mix(in oklab, var(--acid) 7%, transparent), transparent 60%)`.

**Light** — derived, same hue, inverted lightness, slightly higher chroma on text for legibility:
```css
[data-theme="light"] {
  color-scheme: light;
  --bg:     oklch(0.99 0.004 265);
  --bg-1:   oklch(0.975 0.006 265);
  --bg-2:   oklch(0.95 0.008 265);
  --bg-3:   oklch(0.915 0.01 265);
  --line:   oklch(0.88 0.012 265);
  --line-2: oklch(0.82 0.016 265);
  --text:   oklch(0.24 0.03 265);
  --dim:    oklch(0.45 0.022 265);
  --dim-2:  oklch(0.58 0.018 265);
}
```
Light-mode notes:
- Drop the top glow to ~3% or remove it; light bg shouldn't look muddy.
- Accent **acid** as a button background keeps **dark** text (`#0c0d10`) in both themes — it's a bright color. Verify contrast of acid-on-light for any *text/icon* usage; if acid text on a light bg fails contrast, darken it for light theme only (e.g. shift acid text uses to a `color-mix(acid 70%, black)`), but keep acid as a fill color unchanged.
- `::selection` stays `background: var(--acid); color: #000;` in both.
- Shadows: dark theme uses accent-tinted glows; in light theme reduce glow opacity and add a soft neutral drop shadow so cards read as elevated on white.
- All component colors already reference these tokens via `color-mix(... var(--token) ...)`, so a correct token swap themes the whole app. **Do not hardcode neutral hex anywhere** — always go through tokens so both themes work.

### 8.4 Spacing, radius, shape
- Spacing base `--pad: 22px` (compact density: 16px). Radius `--r: 16px` (compact 13px). Buttons `border-radius: 11px`. Avatars circular. Pills/tags `border-radius: 99px`.
- Content max width `--maxw: 1080px`, centered. **Mobile-first**: default to full-width with `--pad` gutters; introduce the max-width container and multi-column grids only at ≥ tablet breakpoints.
- **Density** is a tweak (`compact` / `regular`) that scales `--pad` and `--r` via `data-density` on `<html>`.

### 8.5 Breakpoints (from prototype — invert to mobile-first)
The prototype's max-width media queries map to these mobile-first stacking rules:
- **Base (phone)**: everything single-column; ranks stacked; modals full-width bottom sheets; app-bar condensed (no username text, icon-only add); period date inputs full width; stat tiles stacked.
- **≥ 560px**: show username cluster, "Strich" label, inline seg controls.
- **≥ 860px**: overview's secondary grid goes two-column.
- **≥ 980px**: the three live-period RankLists go to a 3-column grid.

---

## 9. Iconography
Simple 24×24 stroke icons (`stroke: currentColor`, width 2, round caps/joins). Set used: `plus, close, check, chevron, chevronR, lock, trash, user, bolt, back, eye, eyeOff, power, edit, flame`. Use any equivalent line-icon library (Lucide is a close match) or port the inline SVGs from `reference/ui.jsx`.

## 10. Assets
No external image assets. Avatars are either generated initials (color-tinted) or user-uploaded images stored as data URLs (prototype) — in production store uploads in object storage and reference by URL. Fonts load from Google Fonts (Space Grotesk, Hanken Grotesk, Space Mono, plus the alt headline fonts Archivo Black, Syne, Bricolage Grotesque).

## 11. Tweaks / settings (keep, but make them real settings)
The prototype exposes: **Akzent** (4 accent colors), **Headline-Schrift** (4 fonts), **Dichte** (compact/regular), **Strich-Darstellung** (roman/zahl/striche), and **Demo zurücksetzen**. In the real app, surface these as user settings (persisted) and **add the dark/light theme toggle here**. The theme toggle is the one new control not in the prototype.

---

## 12. Reference files (in `reference/`)
| File | Contains |
|---|---|
| `Toni Strichsystem.html` | Full CSS (every component class + responsive rules) and app bootstrap. The CSS is the source of truth for exact spacing/colors/animation. |
| `store.jsx` | Data model, seed data, all selectors & actions, persistence. |
| `app.jsx` | Shell, routing, header, login modal, tweak wiring, accent application. |
| `ui.jsx` | Shared primitives: Icon, Avatar, Tally/StrichMarks, Btn, Modal, Field, timeAgo. |
| `overview.jsx` | Übersicht: WideBoard/Podium, RankList/RankRow, PersonDetail. |
| `addstrike.jsx` | Add-Strich modal + VoteBanner. |
| `admin.jsx` | Admin dashboard (people+logins, periods, actions). |
| `profile.jsx` | Profile modal (avatar crop, color, password). |
| `tweaks-panel.jsx` | The prototype's tweak-panel host (reference only — replace with real settings UI). |

Open `Toni Strichsystem.html` in a browser to interact with the working prototype before building.

---

## 13. Build checklist
- [ ] Mobile-first layouts; everything single-column on phone, scales up at the §8.5 breakpoints.
- [ ] Dark theme default; light theme via `data-theme`; toggle persisted; both verified for contrast.
- [ ] All neutrals through CSS variables — zero hardcoded neutral hex.
- [ ] German copy preserved exactly.
- [ ] Role-based gating per §3; login-required modals with contextual reasons.
- [ ] Vote lifecycle (propose → ballots → resolve → auto-create strike).
- [ ] Three tally display modes + "sauber" zero state.
- [ ] Period model supports both months and dated occasions; "live" logic by date range.
- [ ] Passwords hashed server-side; storage behind a swappable data layer.
- [ ] `prefers-reduced-motion` respected (no looping pulse / auto-rotation).
- [ ] Touch targets ≥ 44px; bottom-sheet modals on phone.
