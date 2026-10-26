// profile.jsx — Eigenes Profil: Farbe, Profilbild, Passwort ändern
const { useState: useStatePr, useEffect: useEffectPr, useRef: useRefPr } = React;

function fileToAvatar(file, cb) {
  const reader = new FileReader();
  reader.onload = () => {
    const img = new Image();
    img.onload = () => {
      const size = 256;
      const c = document.createElement("canvas");
      c.width = size; c.height = size;
      const ctx = c.getContext("2d");
      const scale = Math.max(size/img.width, size/img.height);
      const w = img.width*scale, h = img.height*scale;
      ctx.drawImage(img, (size-w)/2, (size-h)/2, w, h);
      cb(c.toDataURL("image/jpeg", 0.85));
    };
    img.src = reader.result;
  };
  reader.readAsDataURL(file);
}

function ProfileModal({ open, onClose }) {
  const store = useStore();
  const { sel } = store;
  const me = sel.currentUser;
  const person = me?.personId ? sel.person(me.personId) : null;
  const [pw, setPw] = useStatePr("");
  const [pw2, setPw2] = useStatePr("");
  const [msg, setMsg] = useStatePr(null);
  const fileRef = useRefPr();
  useEffectPr(() => { if (open) { setPw(""); setPw2(""); setMsg(null); } }, [open]);
  if (!me) return null;

  function pickColor(c) { if (person) store.updatePerson(person.id, { color: c }); }
  function onFile(e) { const f = e.target.files[0]; if (!f || !person) return; fileToAvatar(f, url => store.updatePerson(person.id, { avatar: url })); }
  function removeAvatar() { if (person) store.updatePerson(person.id, { avatar: null }); }
  function savePw(e) {
    e.preventDefault();
    if (pw.length < 2) { setMsg({ t:"err", m:"Passwort ist zu kurz." }); return; }
    if (pw !== pw2) { setMsg({ t:"err", m:"Die Passwörter stimmen nicht überein." }); return; }
    store.updateUser(me.id, { password: pw });
    setPw(""); setPw2(""); setMsg({ t:"ok", m:"Passwort geändert ✓" });
  }

  return (
    <Modal open={open} onClose={onClose} title="Mein Profil">
      <div className="profile">
        <div className="profile__top">
          <Avatar person={person} size={72}/>
          <div>
            <h3 className="profile__name">{person?.name || me.username}</h3>
            <span className="profile__role">{sel.isAdmin?"Admin":"Mitglied"} · @{me.username}</span>
          </div>
        </div>

        {person ? (
          <>
            <Field label="Profilbild">
              <div className="profile__avactions">
                <input ref={fileRef} type="file" accept="image/*" onChange={onFile} style={{display:"none"}}/>
                <Btn variant="ghost" size="sm" onClick={()=>fileRef.current && fileRef.current.click()}><Icon name="user" size={15}/> Bild hochladen</Btn>
                {person.avatar && <Btn variant="ghost" size="sm" onClick={removeAvatar}><Icon name="trash" size={15}/> Entfernen</Btn>}
              </div>
            </Field>
            <Field label="Deine Farbe">
              <div className="swatches">
                {PALETTE.map(c => (
                  <button key={c} type="button" className={"swatch"+(person.color===c?" swatch--on":"")} style={{background:c}} onClick={()=>pickColor(c)} aria-label={c}>
                    {person.color===c && <Icon name="check" size={15}/>}
                  </button>
                ))}
              </div>
            </Field>
          </>
        ) : (
          <p className="profile__hint">Dieser Zugang ist keiner Person zugeordnet — Farbe und Bild kann nur eine zugeordnete Person setzen.</p>
        )}

        <form className="profile__pw" onSubmit={savePw}>
          <Field label="Passwort ändern" hint="auch ohne Admin-Rechte">
            <input className="input" type="password" value={pw} onChange={e=>{setPw(e.target.value);setMsg(null);}} placeholder="Neues Passwort"/>
          </Field>
          <input className="input" type="password" value={pw2} onChange={e=>{setPw2(e.target.value);setMsg(null);}} placeholder="Wiederholen" style={{marginBottom:12}}/>
          {msg && <div className={msg.t==="ok"?"profile__ok":"login__err"}>{msg.m}</div>}
          <Btn variant="primary" size="md" full type="submit">Passwort speichern</Btn>
        </form>
      </div>
    </Modal>
  );
}

Object.assign(window, { ProfileModal });
