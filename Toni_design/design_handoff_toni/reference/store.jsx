// store.jsx — Datenmodell, Persistenz, Auth und Aktionen für das Toni-System
const { createContext, useContext, useState, useEffect, useCallback } = React;

const MONTHS_DE = ["Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"];
const STORE_KEY = "toni_store_v10";
const SESSION_KEY = "toni_session_v1";

// ---- Helpers ----------------------------------------------------------------
const uid = () => Math.random().toString(36).slice(2, 9);

function toRoman(num) {
  if (!num || num < 1) return "—";
  const map = [["M",1000],["CM",900],["D",500],["CD",400],["C",100],["XC",90],["L",50],["XL",40],["X",10],["IX",9],["V",5],["IV",4],["I",1]];
  let out = "", n = num;
  for (const [sym, val] of map) { while (n >= val) { out += sym; n -= val; } }
  return out;
}

function periodLabel(p) {
  if (!p) return "—";
  return p.type === "freitext" ? p.label : `${MONTHS_DE[p.month]} ${p.year}`;
}

const isoDate = (d) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")}`;
function monthBounds(month, year) {
  return { start: isoDate(new Date(year, month, 1)), end: isoDate(new Date(year, month+1, 0)) };
}
function periodRange(p) {
  if (!p || !p.start) return "";
  const s = new Date(p.start+"T00:00:00"), e = new Date(p.end+"T00:00:00");
  const sFmt = s.toLocaleDateString("de-DE", { day:"numeric", month:"short" });
  const eFmt = e.toLocaleDateString("de-DE", { day:"numeric", month:"short", year:"numeric" });
  return `${sFmt} – ${eFmt}`;
}
function isPeriodLive(p) {
  if (!p || !p.start) return false;
  const t = isoDate(new Date());
  return p.start <= t && t <= p.end;
}

const PALETTE = ["#a3e635","#f59e0b","#f472b6","#38bdf8","#c084fc","#fb7185","#34d399","#fbbf24"];

// ---- Seed -------------------------------------------------------------------
function seed() {
  const ppl = [
    { id: "p1", name: "Max",   active: true, color: PALETTE[0] },
    { id: "p2", name: "Lena",  active: true, color: PALETTE[2] },
    { id: "p3", name: "Jonas", active: true, color: PALETTE[3] },
    { id: "p4", name: "Sophie",active: true, color: PALETTE[4] },
    { id: "p5", name: "Tim",   active: true, color: PALETTE[1] },
    { id: "p6", name: "Nina",  active: true, color: PALETTE[6] },
  ];
  const mk = (id, month, year) => ({ id, type:"monat", month, year, active:true, ...monthBounds(month, year) });
  const periods = [
    mk("per0", 11, 2025), mk("per1", 0, 2026), mk("per2", 1, 2026), mk("per3", 2, 2026),
    mk("per4", 3, 2026), mk("per5", 4, 2026), mk("per6", 5, 2026), // Juni 2026 = aktuell
    // abgeschlossene Vorjahre (für "Alle Jahre")
    mk("per24a", 9, 2024), mk("per24b", 10, 2024), mk("per24c", 11, 2024),
    mk("per25a", 8, 2025), mk("per25b", 9, 2025), mk("per25c", 10, 2025),
    { id: "perF1", type:"freitext", label: "Skiurlaub 2026", year: 2026, active: true, start: "2026-02-07", end: "2026-02-14" },
    { id: "perF0", type:"freitext", label: "Silvester '25", year: 2025, active: true, start: "2025-12-30", end: "2026-01-01" },
    { id: "perF2", type:"freitext", label: "Grillsaison 2026", year: 2026, active: true, start: "2026-06-01", end: "2026-08-31" },
  ];
  const reasons = [
    "Abwasch eine ganze Woche stehen lassen",
    "Letztes Bier aus dem Kühlschrank weggetrunken",
    "Mülltonne wieder nicht rausgestellt",
    "Mit Schuhen aufs Sofa gelegt",
    "Klopapier leer und nicht nachgefüllt",
    "Um 4 Uhr laut nach Hause gekommen",
    "Pfandkisten seit 3 Wochen im Flur",
    "Gemeinsame Kasse vergessen aufzufüllen",
    "Lautsprecher um Mitternacht aufgedreht",
    "Pizza im Ofen vergessen → Rauchmelder",
    "Spülmaschine falsch eingeräumt (Streit-Modus)",
    "Toaster mal wieder nicht ausgekratzt",
    "Skipass am ersten Tag verloren",
    "Beim Après-Ski eingeschlafen",
    "Um Mitternacht Feuerwerk im Innenhof",
  ];
  const strikes = [];
  const dist = { per0:[["p1",2],["p3",1]], per1:[["p5",3],["p2",1],["p4",2]],
    per2:[["p1",1],["p3",2],["p6",1]], per3:[["p2",2],["p5",1],["p1",3]],
    per4:[["p4",1],["p6",2],["p3",1]], per5:[["p1",2],["p2",1],["p5",2],["p3",1]],
    per6:[["p3",2],["p5",1],["p1",1]], perF1:[["p5",2],["p1",1]], perF0:[["p3",1],["p4",1]], perF2:[["p4",2],["p6",1],["p2",1]],
    per24a:[["p3",2],["p1",1]], per24b:[["p3",2],["p5",1]], per24c:[["p1",2],["p2",1]],
    per25a:[["p3",2],["p4",1]], per25b:[["p3",2],["p6",1]], per25c:[["p3",1],["p2",2]] };
  let day = 2; let ri = 0;
  Object.entries(dist).forEach(([per, arr]) => {
    arr.forEach(([pid, n]) => {
      for (let i=0;i<n;i++){
        const p = periods.find(x=>x.id===per);
        const m = p.type==="monat" ? p.month : (p.start ? new Date(p.start+"T00:00:00").getMonth() : 2);
        strikes.push({ id: uid(), personId: pid, periodId: per, reason: reasons[ri++ % reasons.length],
          createdAt: new Date(p.year, m, (day++ % 26)+1, 19, 30).toISOString(), source: "direkt" });
      }
    });
  });
  const votes = [
    { id: uid(), personId: "p2", periodId: "per6", reason: "Hat behauptet sie hätte abgewaschen — Beweis: voller Spülbecken-Turm",
      createdBy: "p3", createdAt: new Date(2026,5,5,21,12).toISOString(), status: "offen",
      ballots: { p1: "ja", p4: "nein" } },
  ];
  // Benutzer (Login) — jedem optional an eine Person gekoppelt
  const users = [
    { id: "u1", username: "max",   password: "toni2026", role: "admin",    personId: "p1" },
    { id: "u2", username: "lena",  password: "toni",     role: "mitglied", personId: "p2" },
    { id: "u3", username: "jonas", password: "toni",     role: "mitglied", personId: "p3" },
  ];
  return { people: ppl, periods, strikes, votes, users, currentPeriodId: "per6" };
}

function load() {
  try { const raw = localStorage.getItem(STORE_KEY); if (raw) return JSON.parse(raw); } catch(e){}
  return seed();
}
function loadSession() { try { return localStorage.getItem(SESSION_KEY) || null; } catch(e){ return null; } }

// ---- Context ----------------------------------------------------------------
const StoreContext = createContext(null);

function StoreProvider({ children }) {
  const [db, setDb] = useState(load);
  const [sessionUserId, setSessionUserId] = useState(loadSession);

  useEffect(() => { try { localStorage.setItem(STORE_KEY, JSON.stringify(db)); } catch(e){} }, [db]);
  useEffect(() => { try { sessionUserId ? localStorage.setItem(SESSION_KEY, sessionUserId) : localStorage.removeItem(SESSION_KEY); } catch(e){} }, [sessionUserId]);

  const up = useCallback((fn) => setDb(prev => { const next = structuredClone(prev); fn(next); return next; }), []);

  const currentUser = db.users.find(u => u.id === sessionUserId) || null;
  const isLoggedIn = !!currentUser;
  const isAdmin = currentUser?.role === "admin";
  const myPersonId = currentUser?.personId || null;

  const actions = {
    resetDemo: () => { localStorage.removeItem(STORE_KEY); setDb(seed()); setSessionUserId(null); },
    // Auth
    login: (username, password) => {
      const u = db.users.find(x => x.username.toLowerCase() === String(username).toLowerCase().trim() && x.password === password);
      if (u) { setSessionUserId(u.id); return u; }
      return null;
    },
    logout: () => setSessionUserId(null),
    // Striche
    addStrike: (personId, periodId, reason) => up(d => {
      d.strikes.push({ id: uid(), personId, periodId, reason, createdAt: new Date().toISOString(), source: "direkt" });
    }),
    removeStrike: (id) => up(d => { d.strikes = d.strikes.filter(s => s.id !== id); }),
    // Votes
    startVote: (personId, periodId, reason, createdBy) => up(d => {
      d.votes.push({ id: uid(), personId, periodId, reason, createdBy, createdAt: new Date().toISOString(), status: "offen", ballots: {} });
    }),
    castVote: (voteId, userPersonId, choice) => up(d => {
      const v = d.votes.find(x => x.id === voteId); if (!v || v.status !== "offen" || !userPersonId) return;
      v.ballots[userPersonId] = choice;
    }),
    resolveVote: (voteId) => up(d => {
      const v = d.votes.find(x => x.id === voteId); if (!v) return;
      const ja = Object.values(v.ballots).filter(x => x === "ja").length;
      const nein = Object.values(v.ballots).filter(x => x === "nein").length;
      v.status = ja > nein ? "angenommen" : "abgelehnt";
      v.resolvedAt = new Date().toISOString();
      if (v.status === "angenommen") {
        d.strikes.push({ id: uid(), personId: v.personId, periodId: v.periodId, reason: v.reason, createdAt: new Date().toISOString(), source: "abstimmung" });
      }
    }),
    dismissVote: (voteId) => up(d => { d.votes = d.votes.filter(v => v.id !== voteId); }),
    // Personen
    addPerson: (name) => up(d => { d.people.push({ id: uid(), name, active: true, color: PALETTE[d.people.length % PALETTE.length] }); }),
    togglePerson: (id) => up(d => { const p = d.people.find(x=>x.id===id); if (p) p.active = !p.active; }),
    removePerson: (id) => up(d => { d.people = d.people.filter(p=>p.id!==id); d.strikes = d.strikes.filter(s=>s.personId!==id); d.users = d.users.filter(u=>u.personId!==id); }),
    renamePerson: (id, name) => up(d => { const p = d.people.find(x=>x.id===id); if (p) p.name = name; }),
    updatePerson: (id, patch) => up(d => { const p = d.people.find(x=>x.id===id); if (p) Object.assign(p, patch); }),
    // Benutzer / Login (an Person gekoppelt)
    addAccount: (personId, username, password, role) => up(d => { d.users.push({ id: uid(), username, password, role: role||"mitglied", personId }); }),
    updateUser: (id, patch) => up(d => { const u = d.users.find(x=>x.id===id); if (u) Object.assign(u, patch); }),
    removeUser: (id) => up(d => { d.users = d.users.filter(u=>u.id!==id); }),
    // Perioden
    addPeriod: (month, year) => up(d => { if (!d.periods.some(p=>p.type==="monat"&&p.month===month&&p.year===year)) d.periods.push({ id: uid(), type:"monat", month, year, active: true, ...monthBounds(month, year) }); }),
    addFreitext: (label, year, start, end) => up(d => { d.periods.push({ id: uid(), type:"freitext", label: label.trim(), year: Number(year)||new Date().getFullYear(), active: true, start: start||null, end: end||null }); }),
    updatePeriod: (id, patch) => up(d => { const p = d.periods.find(x=>x.id===id); if (p) Object.assign(p, patch); }),
    togglePeriod: (id) => up(d => { const p = d.periods.find(x=>x.id===id); if (p) p.active = !p.active; }),
    removePeriod: (id) => up(d => { d.periods = d.periods.filter(p=>p.id!==id); }),
    setCurrentPeriod: (id) => up(d => { d.currentPeriodId = id; }),
    // Erstellt bei Bedarf einen Freitext-Anlass und gibt dessen id zurück
    ensureFreitext: (label, year) => {
      const existing = db.periods.find(p => p.type==="freitext" && p.label.toLowerCase() === label.toLowerCase().trim());
      if (existing) return existing.id;
      const id = uid();
      up(d => { d.periods.push({ id, type:"freitext", label: label.trim(), year: Number(year)||new Date().getFullYear(), active: true }); });
      return id;
    },
  };

  // ---- Derived selectors ----
  // Sieger einer Periode = Person(en) mit den meisten Strichen (>0)
  const winnersOf = (periodId) => {
    const cs = db.people.filter(p=>p.active).map(p => ({ id:p.id, c: db.strikes.filter(s=>s.personId===p.id && s.periodId===periodId).length }));
    const max = Math.max(0, ...cs.map(x=>x.c));
    return max>0 ? cs.filter(x=>x.c===max).map(x=>x.id) : [];
  };
  // Monatssiege-Rangliste über eine Menge an Perioden
  const winsBoard = (periodsArr) => {
    const wins = {};
    periodsArr.forEach(per => { winnersOf(per.id).forEach(pid => { wins[pid]=(wins[pid]||0)+1; }); });
    return db.people.filter(p=>p.active).map(p=>({ person:p, count: wins[p.id]||0 })).sort((a,b)=> b.count-a.count || a.person.name.localeCompare(b.person.name));
  };
  // Jahressieger eines Jahres = wer die meisten Monate gewonnen hat
  const yearChampionsOf = (year) => {
    const board = winsBoard(db.periods.filter(p=>p.year===year));
    const max = board.length ? board[0].count : 0;
    return max>0 ? board.filter(r=>r.count===max).map(r=>r.person.id) : [];
  };
  const allYears = [...new Set(db.periods.map(p=>p.year))].sort((a,b)=>b-a);

  const sel = {
    activePeople: db.people.filter(p => p.active),
    currentPeriod: db.periods.find(p=>p.type==="monat" && isPeriodLive(p))
      || db.periods.find(p=>isPeriodLive(p))
      || [...db.periods].filter(p=>p.type==="monat").sort((a,b)=>b.year-a.year||b.month-a.month)[0]
      || db.periods[0],
    currentUser, isLoggedIn, isAdmin, myPersonId,
    person: (id) => db.people.find(p => p.id === id),
    user: (id) => db.users.find(u => u.id === id),
    accountFor: (personId) => db.users.find(u => u.personId === personId),
    monthPeriods: db.periods.filter(p=>p.type==="monat").sort((a,b)=> b.year-a.year || b.month-a.month),
    freitextPeriods: db.periods.filter(p=>p.type==="freitext").sort((a,b)=> b.year-a.year),
    countInYear: (personId, year) => {
      const pids = db.periods.filter(p => p.year === year).map(p=>p.id);
      return db.strikes.filter(s => s.personId===personId && pids.includes(s.periodId)).length;
    },
    personStrikes: (personId) => db.strikes.filter(s => s.personId===personId).sort((a,b)=> new Date(b.createdAt)-new Date(a.createdAt)),
    breakdownByPeriod: (personId) => {
      const groups = {};
      db.strikes.filter(s=>s.personId===personId).forEach(s => { (groups[s.periodId] ||= []).push(s); });
      return Object.entries(groups).map(([pid, list]) => ({
        period: db.periods.find(p=>p.id===pid),
        strikes: list.sort((a,b)=> new Date(b.createdAt)-new Date(a.createdAt)),
      })).sort((a,b)=> {
        const ay = a.period?.year||0, by = b.period?.year||0;
        if (by!==ay) return by-ay;
        return (b.period?.type==="monat"?b.period.month:99) - (a.period?.type==="monat"?a.period.month:99);
      });
    },
    leaderboard: (scope, opts={}) => {
      // scope: "periode" (opts.periodId) | "jahr" (opts.year) | "alle"
      const countFor = (pid) => {
        if (scope==="periode") return db.strikes.filter(s=>s.personId===pid && s.periodId===opts.periodId).length;
        if (scope==="jahr") { const pids = db.periods.filter(p=>p.year===opts.year).map(p=>p.id); return db.strikes.filter(s=>s.personId===pid && pids.includes(s.periodId)).length; }
        return db.strikes.filter(s=>s.personId===pid).length;
      };
      return db.people.filter(p=>p.active).map(p => ({ person: p, count: countFor(p.id) }))
        .sort((a,b)=> b.count - a.count || a.person.name.localeCompare(b.person.name));
    },
    // Sieg-Logik
    periodWinners: winnersOf,
    yearWins: (year) => winsBoard(db.periods.filter(p=>p.year===year)),   // Monatssiege im Jahr
    monthsWon: (personId, year) => db.periods.filter(p=> year? p.year===year : true).reduce((n,per)=> n + (winnersOf(per.id).includes(personId)?1:0), 0),
    yearTitles: () => {  // Jahressiege insgesamt (pro Person Anzahl gewonnener Jahre)
      const titles = {};
      allYears.forEach(y => yearChampionsOf(y).forEach(pid => { titles[pid]=(titles[pid]||0)+1; }));
      return db.people.filter(p=>p.active).map(p=>({ person:p, count: titles[p.id]||0 })).sort((a,b)=> b.count-a.count || a.person.name.localeCompare(b.person.name));
    },
    yearChampion: yearChampionsOf,
    livePeriods: () => {
      const live = db.periods.filter(p=>isPeriodLive(p)).sort((a,b)=> (a.type==="monat"?0:1)-(b.type==="monat"?0:1) || (a.start||"").localeCompare(b.start||""));
      if (live.length) return live;
      const cp = db.periods.find(p=>p.id===db.currentPeriodId);
      return cp ? [cp] : [];
    },
    feed: (periodId) => db.strikes.filter(s => s.periodId===periodId).sort((a,b)=> new Date(b.createdAt) - new Date(a.createdAt)),
    openVotes: db.votes.filter(v => v.status === "offen"),
    years: [...new Set(db.periods.map(p=>p.year))].sort((a,b)=>b-a),
  };

  return React.createElement(StoreContext.Provider, { value: { db, ...actions, sel } }, children);
}

function useStore() { return useContext(StoreContext); }

Object.assign(window, { StoreProvider, useStore, toRoman, periodLabel, periodRange, isPeriodLive, monthBounds, MONTHS_DE, PALETTE });
