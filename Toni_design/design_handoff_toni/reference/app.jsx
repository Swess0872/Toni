// app.jsx — Top-Level: Header, Routing, Auth, Tweaks, Mount
const { useState: useStateApp, useEffect: useEffectApp } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "lime",
  "strichMode": "roman",
  "fontHead": "Space Grotesk",
  "density": "regular"
}/*EDITMODE-END*/;

const ACCENTS = {
  lime:    { acid: "#a3e635", amber: "#f59e0b", magenta: "#f472b6" },
  cyan:    { acid: "#22d3ee", amber: "#fbbf24", magenta: "#f472b6" },
  magenta: { acid: "#f472b6", amber: "#f59e0b", magenta: "#a3e635" },
  violet:  { acid: "#c084fc", amber: "#fbbf24", magenta: "#22d3ee" },
};

// ---- Login-Modal -------------------------------------------------------------
function LoginModal({ open, onClose, reason }) {
  const store = useStore();
  const [u, setU] = useStateApp("");
  const [pw, setPw] = useStateApp("");
  const [err, setErr] = useStateApp(false);
  useEffectApp(() => { if (open) { setU(""); setPw(""); setErr(false); } }, [open]);
  function submit(e){ e.preventDefault(); const user = store.login(u, pw); if (user) onClose(); else setErr(true); }
  const demos = store.db.users.slice(0,3);
  return (
    <Modal open={open} onClose={onClose} title="Anmelden">
      <form className="loginform" onSubmit={submit}>
        <div className="login__lock"><Icon name="lock" size={24}/></div>
        {reason && <p className="loginform__reason">{reason}</p>}
        <Field label="Benutzername">
          <input className="input" value={u} onChange={e=>{setU(e.target.value);setErr(false);}} placeholder="z.B. max" autoFocus/>
        </Field>
        <Field label="Passwort">
          <input className="input" type="password" value={pw} onChange={e=>{setPw(e.target.value);setErr(false);}} placeholder="••••••••"/>
        </Field>
        {err && <div className="login__err">Falscher Benutzername oder Passwort.</div>}
        <Btn variant="primary" size="lg" full type="submit">Anmelden</Btn>
        <div className="demohint">
          <span>Demo-Zugänge:</span>
          <div className="demohint__chips">
            {demos.map(d => (
              <button key={d.id} type="button" className="demochip" onClick={()=>{ setU(d.username); setPw(d.password); }}>
                {d.username}{d.role==="admin"?" ★":""}
              </button>
            ))}
          </div>
        </div>
      </form>
    </Modal>
  );
}

function Header({ route, setRoute, onAdd, onLogin, onProfile }) {
  const store = useStore();
  const { sel } = store;
  const me = sel.currentUser;
  const mePerson = me?.personId ? sel.person(me.personId) : null;
  return (
    <header className="appbar">
      <div className="appbar__inner">
        <button className="brand" onClick={()=>setRoute("overview")}>
          <span className="brand__mark">T</span>
          <span className="brand__name">TONI<span className="brand__sub">strich</span></span>
        </button>
        <nav className="appbar__nav">
          <button className={"navlink"+(route==="overview"?" on":"")} onClick={()=>setRoute("overview")}>Übersicht</button>
          <button className={"navlink"+(route==="admin"?" on":"")} onClick={()=>setRoute("admin")}>
            {sel.isAdmin ? "Admin" : <><Icon name="lock" size={14}/> Admin</>}
          </button>
        </nav>
        <div className="appbar__right">
          {sel.isLoggedIn ? (
            <>
              <Btn variant="primary" size="sm" onClick={onAdd}><Icon name="plus" size={16}/> <span className="hide-sm">Strich</span></Btn>
              <button className="whoami whoami--btn" onClick={onProfile} title="Mein Profil">
                {mePerson ? <Avatar person={mePerson} size={32}/> : <div className="userav"><Icon name="user" size={16}/></div>}
                <div className="whoami__menu">
                  <span className="whoami__name">{me.username}{sel.isAdmin?" · Admin":""}</span>
                  <span className="whoami__edit">Profil bearbeiten</span>
                </div>
              </button>
              <button className="iconbtn" onClick={store.logout} title="Abmelden"><Icon name="power" size={17}/></button>
            </>
          ) : (
            <Btn variant="ghost" size="sm" onClick={onLogin}><Icon name="user" size={16}/> Anmelden</Btn>
          )}
        </div>
      </div>
    </header>
  );
}

function App() {
  const [route, setRoute] = useStateApp("overview");
  const [addOpen, setAddOpen] = useStateApp(false);
  const [login, setLogin] = useStateApp({ open:false, reason:null });
  const [profileOpen, setProfileOpen] = useStateApp(false);
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const store = useStore();
  const { sel } = store;

  useEffectApp(() => {
    const a = ACCENTS[t.accent] || ACCENTS.lime;
    const r = document.documentElement;
    r.style.setProperty("--acid", a.acid);
    r.style.setProperty("--amber", a.amber);
    r.style.setProperty("--magenta", a.magenta);
    r.style.setProperty("--font-head", `"${t.fontHead}", "Space Grotesk", sans-serif`);
    window.__toniStrichMode = t.strichMode;
    r.dataset.density = t.density;
  }, [t]);

  function requireLogin(reason) { setLogin({ open:true, reason: reason || "Bitte melde dich an, um fortzufahren." }); }
  function handleAdd() { if (sel.isLoggedIn) setAddOpen(true); else requireLogin("Nur angemeldete Mitglieder können Striche eintragen."); }

  return (
    <div className="app">
      <Header route={route} setRoute={setRoute} onAdd={handleAdd} onLogin={()=>setLogin({open:true, reason:null})} onProfile={()=>setProfileOpen(true)}/>
      <main className="main">
        {route==="overview" && <Overview onRequireLogin={()=>requireLogin("Nur angemeldete Mitglieder können abstimmen.")}/>}
        {route==="admin" && (
          sel.isAdmin ? <AdminDashboard/> :
          <div className="gate">
            <div className="gate__lock"><Icon name="lock" size={28}/></div>
            <h2>Admin-Bereich</h2>
            <p>{sel.isLoggedIn ? "Dein Zugang hat keine Admin-Rechte. Frag einen Admin, dich freizuschalten." : "Bitte melde dich mit einem Admin-Zugang an."}</p>
            {sel.isLoggedIn
              ? <Btn variant="ghost" size="lg" onClick={()=>setRoute("overview")}>← zurück zur Übersicht</Btn>
              : <Btn variant="primary" size="lg" onClick={()=>requireLogin("Melde dich mit einem Admin-Zugang an (Demo: max).")}>Anmelden</Btn>}
          </div>
        )}
      </main>

      {route==="overview" && sel.isLoggedIn && (
        <button className="fab" onClick={handleAdd} aria-label="Strich hinzufügen"><Icon name="plus" size={26}/></button>
      )}

      <AddStrikeModal open={addOpen} onClose={()=>setAddOpen(false)}/>
      <LoginModal open={login.open} reason={login.reason} onClose={()=>setLogin({open:false, reason:null})}/>
      <ProfileModal open={profileOpen} onClose={()=>setProfileOpen(false)}/>

      <TweaksPanel>
        <TweakSection label="Optik"/>
        <TweakColor label="Akzent" value={t.accent==="lime"?"#a3e635":t.accent==="cyan"?"#22d3ee":t.accent==="magenta"?"#f472b6":"#c084fc"}
          options={["#a3e635","#22d3ee","#f472b6","#c084fc"]}
          onChange={(v)=>{ const map={"#a3e635":"lime","#22d3ee":"cyan","#f472b6":"magenta","#c084fc":"violet"}; setTweak("accent", map[v]||"lime"); }}/>
        <TweakSelect label="Headline-Schrift" value={t.fontHead}
          options={["Space Grotesk","Archivo Black","Syne","Bricolage Grotesque"]}
          onChange={(v)=>setTweak("fontHead", v)}/>
        <TweakRadio label="Dichte" value={t.density} options={["compact","regular"]} onChange={(v)=>setTweak("density", v)}/>
        <TweakSection label="Striche"/>
        <TweakSelect label="Darstellung" value={t.strichMode}
          options={["roman","zahl","striche"]}
          onChange={(v)=>setTweak("strichMode", v)}/>
        <TweakSection label="Sonstiges"/>
        <TweakButton label="Demo zurücksetzen" onClick={()=>{ if(confirm("Alle Daten auf Ausgangszustand zurücksetzen?")) store.resetDemo(); }}>Zurücksetzen</TweakButton>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <StoreProvider><App/></StoreProvider>
);
