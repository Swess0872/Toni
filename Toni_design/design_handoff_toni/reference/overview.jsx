// overview.jsx — Übersicht: rotierendes Podest (Jahr/Alle Jahre) + Live-Perioden + Aufschlüsselung
const { useState: useStateOV, useEffect: useEffectOV } = React;

function Podium({ rows, onPick }) {
  const top = rows.filter(r => r.count > 0).slice(0, 3);
  if (top.length === 0) return (
    <div className="podium podium--empty">Noch keine Siege vergeben — alles offen.</div>
  );
  const order = [top[1], top[0], top[2]].filter(Boolean);
  return (
    <div className="podium">
      {order.map((r) => {
        const rank = top.indexOf(r) + 1;
        return (
          <button type="button" key={r.person.id} className={`pod pod--${rank}`} onClick={()=>onPick(r.person)}>
            <div className="pod__person">
              <Avatar person={r.person} size={rank===1?64:52}/>
              <span className="pod__name">{r.person.name}</span>
              <Tally count={r.count} big={rank===1} color={rank===1?"var(--amber)":"var(--text)"} />
            </div>
            <div className="pod__block" style={{ height: rank===1?92:(rank===2?64:46) }}>
              <span className="pod__rank">{rank}</span>
            </div>
          </button>
        );
      })}
    </div>
  );
}

function WideBoard({ onPick }) {
  const store = useStore();
  const { sel } = store;
  const year = sel.currentPeriod?.year || new Date().getFullYear();
  const views = [
    { key: "jahr", title: `Jahr ${year}`, sub: "Monatssiege — wer führt die Saison an", rows: sel.yearWins(year) },
    { key: "alle", title: "Alle Jahre", sub: "Jahressiege — die ewige Hall of Shame", rows: sel.yearTitles() },
  ];
  const [idx, setIdx] = useStateOV(0);
  const [paused, setPaused] = useStateOV(false);
  useEffectOV(() => {
    if (paused) return;
    const t = setInterval(() => setIdx(i => (i+1) % views.length), 6000);
    return () => clearInterval(t);
  }, [paused, views.length]);
  const v = views[Math.min(idx, views.length-1)];
  const rest = v.rows.slice(3);
  const scope = v.key==="jahr" ? { type:"jahr", year } : { type:"alle" };
  const pick = (p) => onPick(p, scope);

  return (
    <section className="panel wideboard" onMouseEnter={()=>setPaused(true)} onMouseLeave={()=>setPaused(false)}>
      <div className="wideboard__head">
        <div>
          <h2 className="wideboard__title">{v.title}</h2>
          <span className="wideboard__sub">{v.sub}</span>
        </div>
        <div className="wideboard__dots">
          {views.map((vv,i)=>(
            <button key={vv.key} className={"wbdot"+(i===idx?" on":"")} onClick={()=>setIdx(i)} aria-label={vv.title}/>
          ))}
        </div>
      </div>
      <div key={v.key} className="wideboard__body">
        <Podium rows={v.rows} onPick={pick}/>
        {rest.length>0 && (
          <div className="wideboard__rest">
            {rest.map((r,i)=>(
              <button type="button" key={r.person.id} className="restchip" onClick={()=>pick(r.person)}>
                <span className="restchip__rank">{i+4}</span>
                <Avatar person={r.person} size={26}/>
                <span className="restchip__name">{r.person.name}</span>
                <Tally count={r.count}/>
              </button>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

function RankRow({ rank, person, count, max, onPick, crown }) {
  const pct = max>0 ? (count/max)*100 : 0;
  const medal = rank<=3 ? ` lrow__rank--${rank}` : "";
  return (
    <button type="button" className="lrow lrow--btn" onClick={()=>onPick(person)}>
      <span className={"lrow__rank"+medal}>{rank}</span>
      <Avatar person={person} size={34}/>
      <div className="lrow__main">
        <div className="lrow__top">
          <span className="lrow__name">{person.name}{crown && count>0 && <span className="crown" title="führt diese Periode">★</span>}</span>
          <Tally count={count}/>
        </div>
        <div className="lrow__bar"><i style={{ width: pct+"%", background: person.color }}/></div>
      </div>
      <Icon name="chevronR" size={15}/>
    </button>
  );
}

function RankList({ title, sub, live, rows, onPick, scope }) {
  const max = Math.max(1, ...rows.map(r=>r.count));
  const total = rows.reduce((s,r)=>s+r.count,0);
  const pick = (p) => onPick(p, scope);
  return (
    <section className="panel ranklist">
      <div className="ranklist__head">
        <div>
          <h2 className="ranklist__title">{title}{live && <span className="livetag"><span className="livedot livedot--sm"/>läuft</span>}</h2>
          {sub && <span className="ranklist__sub">{sub}</span>}
        </div>
        <span className="ranklist__total">{total}<em>Striche</em></span>
      </div>
      <div className="ltable">
        {rows.map((r, i) => <RankRow key={r.person.id} rank={i+1} person={r.person} count={r.count} max={max} onPick={pick} crown={i===0}/>)}
      </div>
    </section>
  );
}

function PersonDetail({ detail, onClose }) {
  const store = useStore();
  const { sel } = store;
  if (!detail) return null;
  const person = detail.person;
  const scope = detail.scope || { type:"alle" };
  const year = sel.currentPeriod?.year;
  const scopePeriod = scope.type==="periode" ? store.db.periods.find(p=>p.id===scope.periodId) : null;
  const scopeLabel = scope.type==="periode" ? periodLabel(scopePeriod)
                  : scope.type==="jahr" ? `Jahr ${scope.year}`
                  : "Alle Jahre";

  let groups = sel.breakdownByPeriod(person.id);
  if (scope.type==="periode") groups = groups.filter(g=>g.period?.id===scope.periodId);
  else if (scope.type==="jahr") groups = groups.filter(g=>g.period?.year===scope.year);
  const scopedTotal = groups.reduce((n,g)=>n+g.strikes.length, 0);

  const monthsWon = sel.monthsWon(person.id, year);
  const titles = (sel.yearTitles().find(r=>r.person.id===person.id)||{}).count || 0;
  const totalAll = sel.personStrikes(person.id).length;

  return (
    <Modal open={!!detail} onClose={onClose} title={"Aufschlüsselung · " + scopeLabel}>
      <div className="pdetail">
        <div className="pdetail__head">
          <Avatar person={person} size={56}/>
          <div>
            <h3 className="pdetail__name">{person.name}</h3>
            <span className="pdetail__sub">{scopedTotal} {scopedTotal===1?"Strich":"Striche"} · {scopeLabel}</span>
          </div>
          <div className="pdetail__big"><Tally count={scopedTotal} big color={person.color}/></div>
        </div>

        <div className="pdetail__stats">
          <div className="pstat"><span className="pstat__k">{scopeLabel}</span><span className="pstat__v">{scopedTotal}</span><span className="pstat__l">Striche</span></div>
          <div className="pstat"><span className="pstat__k">Monatssiege {year}</span><span className="pstat__v">{monthsWon}</span><span className="pstat__l">gewonnene Perioden</span></div>
          <div className="pstat"><span className="pstat__k">Jahressiege</span><span className="pstat__v">{titles}</span><span className="pstat__l">gewonnene Jahre</span></div>
        </div>

        {scopedTotal===0 ? (
          <div className="feed__empty">Keine Striche in diesem Zeitraum.</div>
        ) : (
          <div className="pdetail__groups">
            {groups.map(g => {
              const won = g.period && sel.periodWinners(g.period.id).includes(person.id);
              return (
                <div key={g.period?.id || "x"} className="pgroup">
                  <div className="pgroup__head">
                    <span className="pgroup__label">
                      {g.period?.type==="freitext" && <span className="ftdot"><Icon name="bolt" size={11}/></span>}
                      {periodLabel(g.period)}
                    </span>
                    {periodRange(g.period) && <span className="pgroup__range">{periodRange(g.period)}</span>}
                    {won && <span className="wonbadge">★ gewonnen</span>}
                    <span className="pgroup__count">{g.strikes.length}×</span>
                  </div>
                  <ul className="pgroup__list">
                    {g.strikes.map(s => (
                      <li key={s.id} className="pgline">
                        <span className="pgline__dot" style={{background: person.color}}/>
                        <span className="pgline__reason">{s.reason}</span>
                        {s.source==="abstimmung" && <span className="badge badge--vote">Abstimmung</span>}
                      </li>
                    ))}
                  </ul>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </Modal>
  );
}

function Overview({ onRequireLogin }) {
  const store = useStore();
  const { sel } = store;
  const [detail, setDetail] = useStateOV(null);
  const openVotes = sel.openVotes;
  const live = sel.livePeriods();

  return (
    <div className="overview">
      {openVotes.length > 0 ? (
        <div className="votezone">
          {openVotes.map(v => <VoteBanner key={v.id} vote={v} onRequireLogin={onRequireLogin}/>)}
        </div>
      ) : (
        <WideBoard onPick={(person,scope)=>setDetail({person, scope})}/>
      )}

      <div className="ranks">
        {live.map(p => (
          <RankList key={p.id}
            title={periodLabel(p)}
            sub={periodRange(p) || (p.type==="freitext"?"Anlass":"")}
            live={isPeriodLive(p)}
            rows={sel.leaderboard("periode", { periodId: p.id })}
            scope={{ type:"periode", periodId: p.id }}
            onPick={(person,scope)=>setDetail({person, scope})}/>
        ))}
      </div>
      <p className="ranks__hint">Tipp: Auf einen Namen tippen zeigt, woraus sich die Striche zusammensetzen.</p>
      <PersonDetail detail={detail} onClose={()=>setDetail(null)}/>
    </div>
  );
}

Object.assign(window, { Overview });
