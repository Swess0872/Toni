// ui.jsx — gemeinsame UI-Bausteine
const { useState: useStateUI, useEffect: useEffectUI, useRef } = React;

// ---- Simple line icons (nur einfache Pfade) ----
function Icon({ name, size = 20, stroke = 2 }) {
  const common = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: stroke, strokeLinecap: "round", strokeLinejoin: "round" };
  const paths = {
    plus: <><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></>,
    close: <><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></>,
    check: <polyline points="20 6 9 17 4 12"/>,
    chevron: <polyline points="6 9 12 15 18 9"/>,
    chevronR: <polyline points="9 6 15 12 9 18"/>,
    lock: <><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></>,
    trash: <><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></>,
    user: <><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/></>,
    bolt: <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>,
    back: <polyline points="15 18 9 12 15 6"/>,
    eye: <><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></>,
    eyeOff: <><path d="M3 3l18 18"/><path d="M10.6 10.6a3 3 0 0 0 4.2 4.2"/><path d="M9.9 4.6A10.9 10.9 0 0 1 12 5c6.5 0 10 7 10 7a16 16 0 0 1-3.3 4.2M6.6 6.6A16 16 0 0 0 2 12s3.5 7 10 7a10.9 10.9 0 0 0 3.4-.5"/></>,
    power: <><path d="M12 3v9"/><path d="M6.4 6.4a8 8 0 1 0 11.2 0"/></>,
    edit: <><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/></>,
    flame: <path d="M12 2s4 4 4 8a4 4 0 0 1-8 0c0-1 .5-2 .5-2S7 11 7 13a5 5 0 0 0 10 0c0-5-5-11-5-11z"/>,
  };
  return <svg {...common}>{paths[name]}</svg>;
}

function Avatar({ person, size = 40 }) {
  if (!person) return null;
  const initials = person.name.slice(0,2).toUpperCase();
  if (person.avatar) {
    return <div className="avatar avatar--img" style={{ width: size, height: size, backgroundImage: `url(${person.avatar})`, borderColor: `color-mix(in oklab, ${person.color} 55%, transparent)` }}/>;
  }
  return (
    <div className="avatar" style={{ width: size, height: size, fontSize: size*0.36, background: `color-mix(in oklab, ${person.color} 24%, transparent)`, color: person.color, borderColor: `color-mix(in oklab, ${person.color} 45%, transparent)` }}>
      {initials}
    </div>
  );
}

// Tally: römische Strichliste (Standard), Zahl oder echte Striche
function Tally({ count, color = "var(--amber)", big = false }) {
  const mode = window.__toniStrichMode || "roman";
  if (count === 0) return <span className="tally tally--zero" style={{ fontSize: big? 22:15 }}>sauber</span>;
  return (
    <span className={"tally" + (big? " tally--big":"")} style={{ color }}>
      {mode === "striche" ? <StrichMarks count={count} />
        : mode === "zahl" ? <span className="tally__roman">{count}</span>
        : <span className="tally__roman">{window.toRoman(count)}</span>}
    </span>
  );
}

// Echte Strichliste |||| mit Durchstrich pro 5er-Gruppe
function StrichMarks({ count }) {
  const groups = []; let rest = count;
  while (rest > 0) { groups.push(Math.min(5, rest)); rest -= 5; }
  return (
    <span className="strichmarks">
      {groups.map((g,i)=>(
        <span key={i} className={"strichgroup" + (g===5? " strichgroup--full":"")}>
          {Array.from({length: Math.min(g,4)}).map((_,j)=><i key={j} className="strich"/>)}
          {g===5 && <i className="strich strich--cross"/>}
        </span>
      ))}
    </span>
  );
}

function Btn({ children, variant = "primary", size = "md", onClick, type = "button", disabled, full, style }) {
  return <button type={type} disabled={disabled} onClick={onClick}
    className={`btn btn--${variant} btn--${size}${full? " btn--full":""}`} style={style}>{children}</button>;
}

function Modal({ open, onClose, children, title, wide }) {
  useEffectUI(() => {
    if (!open) return;
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => { document.removeEventListener("keydown", onKey); document.body.style.overflow = ""; };
  }, [open]);
  if (!open) return null;
  return (
    <div className="modal__scrim" onMouseDown={onClose}>
      <div className={"modal" + (wide? " modal--wide":"")} onMouseDown={e=>e.stopPropagation()}>
        <div className="modal__head">
          <h3>{title}</h3>
          <button className="iconbtn" onClick={onClose} aria-label="Schliessen"><Icon name="close" size={20}/></button>
        </div>
        <div className="modal__body">{children}</div>
      </div>
    </div>
  );
}

function Field({ label, hint, children }) {
  return (
    <label className="field">
      <span className="field__label">{label}{hint && <em className="field__hint">{hint}</em>}</span>
      {children}
    </label>
  );
}

function Pill({ children, tone = "neutral", onClick, active }) {
  return <button type="button" className={`pill pill--${tone}${active? " pill--active":""}`} onClick={onClick}>{children}</button>;
}

function timeAgo(iso) {
  const d = (Date.now() - new Date(iso)) / 1000;
  if (d < 60) return "gerade eben";
  if (d < 3600) return `vor ${Math.floor(d/60)} Min`;
  if (d < 86400) return `vor ${Math.floor(d/3600)} Std`;
  const days = Math.floor(d/86400);
  if (days < 30) return `vor ${days} ${days===1?"Tag":"Tagen"}`;
  return new Date(iso).toLocaleDateString("de-DE", { day:"2-digit", month:"short" });
}

Object.assign(window, { Icon, Avatar, Tally, StrichMarks, Btn, Modal, Field, Pill, timeAgo });
