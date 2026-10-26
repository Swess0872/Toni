// addstrike.jsx — Strich hinzufügen (Wann = beliebiger Zeitraum) + Vote-Banner
const { useState: useStateAS } = React;

function AddStrikeModal({ open, onClose }) {
  const store = useStore();
  const { sel } = store;
  // nur Zeiträume, die das heutige Datum einschliessen
  const live = store.db.periods.filter(p=>isPeriodLive(p)).sort((a,b)=> (a.type==="monat"?0:1)-(b.type==="monat"?0:1) || (a.start||"").localeCompare(b.start||""));
  const opts = live.length ? live : [sel.currentPeriod].filter(Boolean);
  const [personId, setPersonId] = useStateAS("");
  const [periodId, setPeriodId] = useStateAS(opts[0]?.id || "");
  const [reason, setReason] = useStateAS("");
  const [flash, setFlash] = useStateAS(null);

  React.useEffect(() => { if (open) { setPersonId(""); setPeriodId(opts[0]?.id || ""); setReason(""); setFlash(null); } }, [open]);

  const valid = personId && periodId && reason.trim().length > 2;
  const me = sel.myPersonId;

  function submitDirect() {
    if (!valid) return;
    store.addStrike(personId, periodId, reason.trim());
    finish("eingetragen");
  }
  function submitVote() {
    if (!valid) return;
    store.startVote(personId, periodId, reason.trim(), me);
    finish("abstimmung");
  }
  function finish(kind) { setFlash(kind); setTimeout(onClose, 950); }

  return (
    <Modal open={open} onClose={onClose} title="Neuer Toni-Strich">
      {flash ? (
        <div className="flash">
          <div className={"flash__mark " + (flash==="abstimmung"?"flash__mark--vote":"")}>
            <Icon name={flash==="abstimmung"?"bolt":"check"} size={34}/>
          </div>
          <p>{flash==="abstimmung" ? "Abstimmung gestartet — sie läuft jetzt auf der Übersicht." : "Strich eingetragen. Glückwunsch zur Schande."}</p>
        </div>
      ) : (
      <div className="addform">
        <div className="addform__step">
          <span className="stepno">1</span>
          <Field label="Wer hat Mist gebaut?">
            <div className="chipgrid">
              {sel.activePeople.map(p => (
                <button key={p.id} type="button" onClick={()=>setPersonId(p.id)}
                  className={"namechip" + (personId===p.id?" namechip--on":"")}
                  style={personId===p.id?{ borderColor: p.color, boxShadow:`0 0 0 1px ${p.color}` }:{}}>
                  <Avatar person={p} size={30}/>
                  <span>{p.name}</span>
                </button>
              ))}
            </div>
          </Field>
        </div>

        <div className="addform__step">
          <span className="stepno">2</span>
          <Field label="Wann?" hint="nur laufende Zeiträume">
            <div className="selectwrap" style={{width:"100%"}}>
              <select value={periodId} onChange={e=>setPeriodId(e.target.value)} className="select" style={{width:"100%"}}>
                {opts.map(p => <option key={p.id} value={p.id}>{periodLabel(p)}{periodRange(p)? " · "+periodRange(p):""}</option>)}
              </select>
              <Icon name="chevron" size={18}/>
            </div>
            {opts.length===0 && <span className="charcount">Aktuell läuft kein Zeitraum — im Admin anlegen.</span>}
          </Field>
        </div>

        <div className="addform__step">
          <span className="stepno">3</span>
          <Field label="Was ist passiert?" hint="ehrlich & gnadenlos">
            <textarea className="textarea" rows={3} value={reason} maxLength={140}
              onChange={e=>setReason(e.target.value)} placeholder="z.B. Hat den Abwasch 5 Tage stehen lassen…"/>
            <span className="charcount">{reason.length}/140</span>
          </Field>
        </div>

        <div className="addform__actions">
          <Btn variant="ghost" size="lg" full disabled={!valid} onClick={submitVote}>
            <Icon name="bolt" size={18}/> Abstimmung starten
          </Btn>
          <Btn variant="primary" size="lg" full disabled={!valid} onClick={submitDirect}>
            <Icon name="check" size={18}/> Direkt eintragen
          </Btn>
        </div>
        <p className="addform__note">Bei <strong>Abstimmung</strong> entscheidet ihr per einfacher Mehrheit (mehr Ja als Nein).</p>
      </div>
      )}
    </Modal>
  );
}

// ---- Live-Abstimmung Banner auf der Übersicht --------------------------------
function VoteBanner({ vote, onRequireLogin }) {
  const store = useStore();
  const { sel } = store;
  const target = sel.person(vote.personId);
  const author = sel.person(vote.createdBy);
  const me = sel.myPersonId;
  const period = store.db.periods.find(p=>p.id===vote.periodId);
  const ja = Object.values(vote.ballots).filter(x=>x==="ja").length;
  const nein = Object.values(vote.ballots).filter(x=>x==="nein").length;
  const myVote = me ? vote.ballots[me] : null;
  const totalActive = sel.activePeople.length;
  const voted = Object.keys(vote.ballots).length;
  const leading = ja>nein ? "ja" : (nein>ja ? "nein" : "tie");

  function vote_(choice) { if (!sel.isLoggedIn) { onRequireLogin?.(); return; } store.castVote(vote.id, me, choice); }

  return (
    <div className="votebanner" style={{ "--vb": target?.color || "var(--magenta)" }}>
      <div className="votebanner__glow"/>
      <div className="votebanner__head">
        <span className="votebanner__tag"><span className="livedot"/> Abstimmung läuft</span>
        <span className="votebanner__meta">{voted}/{totalActive} abgestimmt · {timeAgo(vote.createdAt)}</span>
      </div>
      <div className="votebanner__body">
        <Avatar person={target} size={52}/>
        <div className="votebanner__text">
          <h3>Strich für <strong style={{color: target?.color}}>{target?.name}</strong>?</h3>
          <div className="votebanner__chips">
            {period && <span className="vchip">{periodLabel(period)}</span>}
            <span className="vchip vchip--by">vorgeschlagen von {author?.name || "—"}</span>
          </div>
          <p>„{vote.reason}"</p>
        </div>
      </div>
      <div className="votebar">
        <div className="votebar__ja" style={{ flex: Math.max(ja, 0.001) }}/>
        <div className="votebar__nein" style={{ flex: Math.max(nein, 0.001) }}/>
        {ja===0&&nein===0 && <div className="votebar__empty">noch keine Stimmen</div>}
      </div>
      <div className="votebar__legend">
        <span className="tag-ja">Ja {ja}</span>
        <span className={"lead "+leading}>{leading==="tie"?"Unentschieden":(leading==="ja"?"Strich führt":"Freispruch führt")}</span>
        <span className="tag-nein">Nein {nein}</span>
      </div>
      {sel.isLoggedIn ? (
        <div className="votebanner__actions">
          <Btn variant={myVote==="nein"?"nein-on":"nein"} full onClick={()=>vote_("nein")}>
            <Icon name="close" size={18}/> Freispruch
          </Btn>
          <Btn variant={myVote==="ja"?"ja-on":"ja"} full onClick={()=>vote_("ja")}>
            <Icon name="bolt" size={18}/> Strich!
          </Btn>
        </div>
      ) : (
        <button className="votebanner__locked" onClick={onRequireLogin}>
          <Icon name="lock" size={16}/> Zum Abstimmen anmelden
        </button>
      )}
      {sel.isLoggedIn && (
        <button className="votebanner__resolve" onClick={()=>store.resolveVote(vote.id)} disabled={voted===0}>
          Abstimmung auswerten →
        </button>
      )}
    </div>
  );
}

Object.assign(window, { AddStrikeModal, VoteBanner });
