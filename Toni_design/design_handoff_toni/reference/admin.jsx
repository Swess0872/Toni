// admin.jsx — Admin-Dashboard: Personen+Login (eine Kategorie), Perioden, Aktionen
const { useState: useStateAD } = React;

function RoleToggle({ value, onChange }) {
  return (
    <div className="seg seg--mini roletoggle">
      <button type="button" className={value!=="admin"?"on":""} onClick={()=>onChange("mitglied")}>Mitglied</button>
      <button type="button" className={value==="admin"?"on admin":""} onClick={()=>onChange("admin")}>Admin</button>
    </div>
  );
}

function AdminSection({ title, desc, action, children }) {
  return (
    <section className="adsec">
      <div className="adsec__head">
        <div><h3>{title}</h3>{desc && <p>{desc}</p>}</div>
        {action}
      </div>
      {children}
    </section>
  );
}

// ---- Personen + Login zusammen ----------------------------------------------
function PersonCard({ person }) {
  const store = useStore();
  const { sel } = store;
  const acc = sel.accountFor(person.id);
  const [showPw, setShowPw] = useStateAD(false);
  const [adding, setAdding] = useStateAD(false);
  const [nu, setNu] = useStateAD({ username:"", password:"", role:"mitglied" });

  function createLogin(e){ e.preventDefault(); if(!nu.username.trim()||!nu.password) return;
    store.addAccount(person.id, nu.username.trim(), nu.password, nu.role); setAdding(false); setNu({username:"",password:"",role:"mitglied"}); }

  return (
    <div className={"percard" + (person.active?"":" percard--off")}>
      <div className="percard__top">
        <Avatar person={person} size={40}/>
        <input className="percard__name" defaultValue={person.name} onBlur={e=>store.renamePerson(person.id, e.target.value.trim()||person.name)}/>
        <span className="percard__count">{sel.countInYear(person.id, sel.currentPeriod?.year)} Striche {sel.currentPeriod?.year}</span>
        <button className="iconbtn" title={person.active?"Deaktivieren":"Aktivieren"} onClick={()=>store.togglePerson(person.id)}><Icon name="power" size={17}/></button>
        <button className="iconbtn iconbtn--danger" title="Person löschen" onClick={()=>{ if(confirm(`${person.name}, alle Striche und Login löschen?`)) store.removePerson(person.id); }}><Icon name="trash" size={17}/></button>
      </div>

      <div className="percard__login">
        {acc ? (
          <div className="loginrow">
            <span className={"rolebadge rolebadge--"+acc.role}><Icon name={acc.role==="admin"?"lock":"user"} size={12}/> {acc.role==="admin"?"Admin":"Mitglied"}</span>
            <div className="loginrow__field">
              <span className="loginrow__lbl">Benutzer</span>
              <input className="input input--sm" value={acc.username} onChange={e=>store.updateUser(acc.id,{username:e.target.value})}/>
            </div>
            <div className="loginrow__field">
              <span className="loginrow__lbl">Passwort</span>
              <div className="pwfield">
                <input className="input input--sm input--pw" type={showPw?"text":"password"} value={acc.password} onChange={e=>store.updateUser(acc.id,{password:e.target.value})}/>
                <button className="iconbtn iconbtn--sm" onClick={()=>setShowPw(s=>!s)}><Icon name={showPw?"eyeOff":"eye"} size={15}/></button>
              </div>
            </div>
            <div className="loginrow__field">
              <span className="loginrow__lbl">Rolle</span>
              <RoleToggle value={acc.role} onChange={r=>store.updateUser(acc.id,{role:r})}/>
            </div>
            <button className="iconbtn iconbtn--sm iconbtn--danger" title="Login entfernen" onClick={()=>{ if(confirm(`Login von ${person.name} entfernen?`)) store.removeUser(acc.id); }}><Icon name="trash" size={15}/></button>
          </div>
        ) : adding ? (
          <form className="loginrow loginrow--new" onSubmit={createLogin}>
            <input className="input input--sm" placeholder="Benutzername" value={nu.username} onChange={e=>setNu({...nu, username:e.target.value})} autoFocus/>
            <input className="input input--sm" placeholder="Passwort" value={nu.password} onChange={e=>setNu({...nu, password:e.target.value})}/>
            <RoleToggle value={nu.role} onChange={r=>setNu({...nu, role:r})}/>
            <Btn variant="primary" size="sm" type="submit">Login anlegen</Btn>
            <button type="button" className="iconbtn iconbtn--sm" onClick={()=>setAdding(false)}><Icon name="close" size={15}/></button>
          </form>
        ) : (
          <button className="addlogin" onClick={()=>setAdding(true)}><Icon name="plus" size={14}/> Login für {person.name} anlegen</button>
        )}
      </div>
    </div>
  );
}

function PeopleAdmin() {
  const store = useStore();
  const [name, setName] = useStateAD("");
  return (
    <AdminSection title="Personen & Logins" desc="Wer Striche bekommt — und wer sich anmelden darf." action={
      <form className="inlineadd" onSubmit={e=>{e.preventDefault(); if(name.trim()){store.addPerson(name.trim()); setName("");}}}>
        <input className="input input--sm" value={name} onChange={e=>setName(e.target.value)} placeholder="Neue Person…"/>
        <Btn variant="primary" size="sm" type="submit"><Icon name="plus" size={16}/> Person</Btn>
      </form>
    }>
      <div className="percards">
        {store.db.people.map(p => <PersonCard key={p.id} person={p}/>)}
      </div>
    </AdminSection>
  );
}

// ---- Perioden: Monate + Freitext --------------------------------------------
function PeriodsAdmin() {
  const store = useStore();
  const [pmode, setPmode] = useStateAD("monat");
  const [month, setMonth] = useStateAD(new Date().getMonth());
  const [year, setYear] = useStateAD(2026);
  const [label, setLabel] = useStateAD("");
  const [start, setStart] = useStateAD("");
  const [end, setEnd] = useStateAD("");
  const periods = [...store.db.periods].sort((a,b)=> b.year-a.year || ((b.type==="monat"?b.month:99)-(a.type==="monat"?a.month:99)));

  function add(e){ e.preventDefault();
    if (pmode==="monat") store.addPeriod(Number(month), Number(year));
    else if (label.trim()) { store.addFreitext(label.trim(), year, start||null, end||null); setLabel(""); setStart(""); setEnd(""); }
  }

  return (
    <AdminSection title="Perioden & Anlässe" desc="Zeiträume, in denen Striche zählen — jeweils mit Start- und Enddatum." action={
      <form className="inlineadd inlineadd--period" onSubmit={add}>
        <div className="seg seg--mini">
          <button type="button" className={pmode==="monat"?"on":""} onClick={()=>setPmode("monat")}>Monat</button>
          <button type="button" className={pmode==="freitext"?"on":""} onClick={()=>setPmode("freitext")}>Anlass</button>
        </div>
        {pmode==="monat" ? (
          <>
            <select className="select select--sm" value={month} onChange={e=>setMonth(e.target.value)}>
              {MONTHS_DE.map((m,i)=><option key={i} value={i}>{m}</option>)}
            </select>
            <input className="input input--sm input--year" type="number" value={year} onChange={e=>setYear(e.target.value)}/>
          </>
        ) : (
          <>
            <input className="input input--sm" placeholder="Anlass-Name…" value={label} onChange={e=>setLabel(e.target.value)}/>
            <input className="input input--sm input--date" type="date" value={start} onChange={e=>setStart(e.target.value)} title="von"/>
            <input className="input input--sm input--date" type="date" value={end} onChange={e=>setEnd(e.target.value)} title="bis"/>
          </>
        )}
        <Btn variant="primary" size="sm" type="submit"><Icon name="plus" size={16}/></Btn>
      </form>
    }>
      <div className="periodrows">
        {periods.map(p => {
          const live = isPeriodLive(p);
          return (
            <div key={p.id} className={"periodrow" + (p.type==="freitext"?" periodrow--ft":"") + (live?" periodrow--cur":"")}>
              <div className="periodrow__set">
                {p.type==="freitext" && <span className="ftdot"><Icon name="bolt" size={12}/></span>}
                <span className="periodrow__label">{periodLabel(p)}</span>
                {live && <span className="livetag"><span className="livedot livedot--sm"/>läuft</span>}
              </div>
              <div className="periodrow__dates">
                <input className="input input--sm input--date" type="date" value={p.start||""} onChange={e=>store.updatePeriod(p.id,{start:e.target.value})}/>
                <span className="periodrow__dash">–</span>
                <input className="input input--sm input--date" type="date" value={p.end||""} onChange={e=>store.updatePeriod(p.id,{end:e.target.value})}/>
              </div>
              <div className="periodchip__btns">
                <button className="iconbtn iconbtn--sm iconbtn--danger" onClick={()=>store.removePeriod(p.id)} title="Löschen"><Icon name="trash" size={14}/></button>
              </div>
            </div>
          );
        })}
      </div>
    </AdminSection>
  );
}

// ---- Aktionen ---------------------------------------------------------------
function ActionsAdmin() {
  const store = useStore();
  const { sel } = store;
  const [filter, setFilter] = useStateAD("all");
  let strikes = [...store.db.strikes].sort((a,b)=> new Date(b.createdAt)-new Date(a.createdAt));
  if (filter !== "all") strikes = strikes.filter(s=>s.periodId===filter);
  const periods = [...store.db.periods].sort((a,b)=> b.year-a.year || ((b.type==="monat"?b.month:99)-(a.type==="monat"?a.month:99)));
  return (
    <AdminSection title="Aktionen" desc="Alle eingetragenen Striche — bearbeiten oder entfernen." action={
      <div className="selectwrap selectwrap--sm">
        <select className="select select--sm" value={filter} onChange={e=>setFilter(e.target.value)}>
          <option value="all">Alle Zeiträume</option>
          {periods.map(p=><option key={p.id} value={p.id}>{periodLabel(p)}</option>)}
        </select>
        <Icon name="chevron" size={16}/>
      </div>
    }>
      <div className="adlist adlist--scroll">
        {strikes.length===0 && <div className="feed__empty">Keine Striche in diesem Filter.</div>}
        {strikes.map(s => {
          const p = sel.person(s.personId); const per = store.db.periods.find(x=>x.id===s.periodId);
          return (
            <div key={s.id} className="adrow adrow--action">
              <Avatar person={p} size={32}/>
              <div className="adrow__action">
                <div className="adrow__atop"><span style={{color:p?.color, fontWeight:600}}>{p?.name}</span>
                  <span className="adrow__per">{per?periodLabel(per):"—"}</span>
                  {s.source==="abstimmung" && <span className="badge badge--vote">Abstimmung</span>}
                </div>
                <span className="adrow__reason">{s.reason}</span>
              </div>
              <button className="iconbtn iconbtn--danger" title="Strich entfernen" onClick={()=>store.removeStrike(s.id)}><Icon name="trash" size={16}/></button>
            </div>
          );
        })}
      </div>
    </AdminSection>
  );
}

function AdminDashboard() {
  const tabs = [["personen","Personen & Logins"],["perioden","Perioden"],["aktionen","Aktionen"]];
  const [tab, setTab] = useStateAD("personen");
  return (
    <div className="admin">
      <div className="admin__tabs">
        {tabs.map(([k,l])=>(
          <button key={k} className={"admin__tab"+(tab===k?" on":"")} onClick={()=>setTab(k)}>{l}</button>
        ))}
      </div>
      <div className="admin__content">
        {tab==="personen" && <PeopleAdmin/>}
        {tab==="perioden" && <PeriodsAdmin/>}
        {tab==="aktionen" && <ActionsAdmin/>}
      </div>
    </div>
  );
}

Object.assign(window, { AdminDashboard });
