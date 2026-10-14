/* Büro — bank statement review: quick sorting without page reloads */

const CAT_LABEL = { business: 'Geschäftlich', private: 'Privat', transfer: 'Umbuchung' };
const onlyOpen = new URLSearchParams(location.search).get('cat') !== null
  ? ['open', 'ai'].includes(new URLSearchParams(location.search).get('cat'))
  : true;   // the page defaults to "Ungeprüft"

async function post(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    alert(data.error || `Fehler ${res.status}`);
    throw new Error(data.error || res.status);
  }
  return data;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/* ── Selects are filled from one <template> instead of being repeated per row ── */

function fillSelects(root = document) {
  root.querySelectorAll('select[data-options]').forEach(sel => {
    if (sel.options.length) return;
    sel.innerHTML = document.getElementById(sel.dataset.options).innerHTML;
    const row = sel.closest('.tx-row');
    if (row && sel.classList.contains('tx-project')) sel.value = row.dataset.project || '';
    if (row && sel.classList.contains('tx-expcat')) sel.value = row.dataset.expcat || '';
  });
}

/* ── Single transaction ── */

function renderRow(row, tx) {
  row.className = row.className.replace(/\bcat-\S+/, '') + ` cat-${tx.cat || 'open'}`;
  row.querySelectorAll('.cat-btns button').forEach(b => b.classList.toggle('on', b.dataset.cat === tx.cat));
  row.dataset.project = tx.project_id || '';
  const p = row.querySelector('.tx-project');
  if (p) p.value = tx.project_id || '';
  if (tx.cat) row.querySelector('.ai-chip')?.remove();
  row.querySelector('.auto-tag')?.remove();
  if (tx.cat && onlyOpen) row.classList.add('done');
  if (!tx.cat) row.classList.remove('done');
}

async function updateTx(row, fields) {
  const { tx, same_open } = await post(`/api/bank/tx/${row.dataset.id}`, fields);
  renderRow(row, tx);
  offerSame(row, tx, same_open);
  return tx;
}

// After sorting one payment: offer the same for the merchant's other open payments
function offerSame(row, tx, n) {
  const bar = row.querySelector('.same-bar');
  if (!bar) return;
  if (!tx.cat || !n) { bar.hidden = true; return; }
  const what = CAT_LABEL[tx.cat] + (tx.project_id ? ' · ' + (row.querySelector('.tx-project')?.selectedOptions[0]?.textContent || '') : '');
  bar.innerHTML = `Noch <strong>${n}</strong> ungeprüfte von „${esc(tx.counterparty)}“:
    <button type="button" class="btn btn-xs btn-outline" data-act="same">alle ebenso (${esc(what)})</button>
    <button type="button" class="btn btn-xs btn-outline" data-act="rule">+ Regel: immer so</button>`;
  bar.hidden = false;
  bar.querySelector('[data-act=same]').onclick = () => applyToParty(tx, false).then(() => { bar.hidden = true; });
  bar.querySelector('[data-act=rule]').onclick = () => applyToParty(tx, true).then(() => { bar.hidden = true; });
}

async function applyToParty(tx, asRule) {
  const fields = { cat: tx.cat, project_id: tx.project_id || '' };
  let n;
  if (asRule) {
    ({ n } = await post('/api/bank/rule', { match: tx.counterparty, field: 'counterparty', ...fields,
                                             exp_category: tx.exp_category || '' }));
  } else {
    ({ n } = await post('/api/bank/bulk', { counterparty: tx.counterparty, ...fields }));
  }
  document.querySelectorAll('.tx-row').forEach(r => {
    if (r.dataset.party === tx.counterparty && !r.classList.contains('done') && r.dataset.id !== tx.id) {
      renderRow(r, { ...tx, id: r.dataset.id });
    }
  });
  toast(`${n} Umsätze von „${tx.counterparty}“ eingeordnet${asRule ? ' – Regel gespeichert' : ''}.`);
}

function nextRow(row, dir = 1) {
  let r = row;
  do { r = dir > 0 ? r.nextElementSibling : r.previousElementSibling; }
  while (r && (!r.classList.contains('tx-row') || (dir > 0 && r.classList.contains('done'))));
  if (r) { r.focus(); r.scrollIntoView({ block: 'nearest' }); }
}

async function setCat(row, cat) {
  await updateTx(row, { cat });
  if (onlyOpen && cat) nextRow(row);
}

function initRows() {
  const table = document.getElementById('tx-table');
  if (!table) return;

  table.addEventListener('click', async e => {
    const row = e.target.closest('.tx-row');
    if (!row) return;
    const btn = e.target.closest('button');
    if (btn?.dataset.cat) {
      setCat(row, btn.classList.contains('on') ? '' : btn.dataset.cat);
    } else if (btn?.classList.contains('inv-link')) {
      const { tx } = await post(`/api/bank/tx/${row.dataset.id}/invoice`, { invoice_id: btn.dataset.inv });
      renderRow(row, tx);
      row.querySelectorAll('.inv-link').forEach(b => b.remove());
      row.querySelector('.tx-links').insertAdjacentHTML('afterbegin',
        `<a href="/invoices/${encodeURIComponent(tx.invoice_id)}" class="link-tag ok">Rechnung ${esc(tx.invoice_id)} bezahlt ✓</a>`);
    } else if (btn?.classList.contains('exp-new') || btn?.classList.contains('exp-link')) {
      const { expense_id } = await post(`/api/bank/tx/${row.dataset.id}/expense`,
                                        btn.dataset.exp ? { expense_id: btn.dataset.exp } : {});
      row.querySelectorAll('.exp-new, .exp-link').forEach(b => b.remove());
      row.querySelector('.tx-links').insertAdjacentHTML('beforeend',
        `<a href="/expenses/${encodeURIComponent(expense_id)}" class="link-tag ok">Ausgabe ✓</a>`);
    } else if (e.target.classList.contains('tx-purpose')) {
      e.target.classList.toggle('expanded');
    }
  });

  table.addEventListener('change', e => {
    const row = e.target.closest('.tx-row');
    if (!row) return;
    if (e.target.classList.contains('tx-project')) updateTx(row, { project_id: e.target.value });
    if (e.target.classList.contains('tx-expcat')) updateTx(row, { exp_category: e.target.value });
    if (e.target.classList.contains('tx-sel')) syncBulk();
  });

  document.getElementById('sel-all')?.addEventListener('change', e => {
    document.querySelectorAll('.tx-sel').forEach(c => { c.checked = e.target.checked; });
    syncBulk();
  });

  table.addEventListener('keydown', e => {
    const row = e.target.closest('.tx-row');
    if (!row || e.target !== row || e.ctrlKey || e.metaKey || e.altKey) return;
    const keys = {
      j: () => nextRow(row, 1), ArrowDown: () => nextRow(row, 1),
      k: () => nextRow(row, -1), ArrowUp: () => nextRow(row, -1),
      g: () => setCat(row, 'business'), p: () => setCat(row, 'private'), u: () => setCat(row, 'transfer'),
      0: () => setCat(row, ''),
      o: () => row.querySelector('.tx-project')?.focus(),
      x: () => { const c = row.querySelector('.tx-sel'); c.checked = !c.checked; syncBulk(); },
      a: () => { if (row.dataset.ai) acceptAI({ ids: [row.dataset.id] }); },
      '.': () => row.querySelector('.same-bar [data-act=same]')?.click(),
    };
    if (keys[e.key]) { e.preventDefault(); keys[e.key](); }
  });

  document.querySelector('.tx-row:not(.done)')?.focus({ preventScroll: true });
}

/* ── Selection & bulk ── */

function selectedIds() {
  return [...document.querySelectorAll('.tx-sel:checked')].map(c => c.closest('.tx-row').dataset.id);
}

function syncBulk() {
  const n = selectedIds().length;
  const bar = document.getElementById('bulk-bar');
  if (!bar) return;
  bar.hidden = !n;
  document.getElementById('bulk-n').textContent = n;
}

async function bulk(fields) {
  const ids = selectedIds();
  if (!ids.length) return;
  await post('/api/bank/bulk', { ids, ...fields });
  location.reload();
}

/* ── Grouped by counterparty ── */

function initParties() {
  document.querySelectorAll('.party-row').forEach(row => {
    const party = row.dataset.party;
    const project = row.querySelector('.party-project');
    const apply = async fields => {
      const rule = row.querySelector('.party-rule')?.checked;
      const { n } = rule
        ? await post('/api/bank/rule', { match: party, field: 'counterparty', cat: fields.cat || 'business',
                                         project_id: project.value })
        : await post('/api/bank/bulk', { counterparty: party, ...fields, project_id: project.value });
      row.querySelectorAll('.cat-btns button').forEach(b => b.classList.toggle('on', b.dataset.cat === (fields.cat || 'business')));
      row.classList.add('done');
      toast(`${n} Umsätze von „${party}“ eingeordnet${rule ? ' – Regel gespeichert' : ''}.`);
    };
    row.querySelectorAll('.cat-btns button').forEach(b => b.addEventListener('click', () => apply({ cat: b.dataset.cat })));
    project.addEventListener('change', () => project.value && apply({}));
  });
}

/* ── LLM suggestions ── */

async function acceptAI(body) {
  const { n } = await post('/api/bank/ai/accept', body);
  toast(`${n} Vorschläge übernommen.`);
  setTimeout(() => location.reload(), 600);
}

async function runAI(year) {
  const btn = document.getElementById('ai-run');
  if (btn) btn.disabled = true;
  const st = await post('/api/bank/ai/run', { year });
  if (st.error && !st.running) { setStatus(`<span class="danger">${esc(st.error)}</span>`); return; }
  pollAI();
}

function setStatus(html) {
  const el = document.getElementById('ai-status');
  if (el) el.innerHTML = html;
}

async function pollAI() {
  const st = await (await fetch('/api/bank/ai/status')).json();
  if (st.running) {
    setStatus(`läuft… ${st.done}/${st.total} Umsätze`);
    setTimeout(pollAI, 2500);
  } else if (st.error) {
    setStatus(`<span class="danger">${esc(st.error)}</span>`);
    document.getElementById('ai-run')?.removeAttribute('disabled');
  } else {
    setStatus(`fertig: ${st.count} Vorschläge`);
    const u = new URL(location.href);
    u.searchParams.set('cat', 'ai');
    location.href = u;
  }
}

async function bookAll(year) {
  const { n } = await post('/api/bank/expenses-bulk', { year });
  toast(`${n} Ausgaben angelegt bzw. verknüpft.`);
  setTimeout(() => location.reload(), 800);
}

/* ── Toast ── */

function toast(msg) {
  const el = document.createElement('div');
  el.className = 'flash flash-success toast';
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => { el.style.opacity = '0'; setTimeout(() => el.remove(), 400); }, 3200);
}

document.addEventListener('DOMContentLoaded', () => {
  fillSelects();
  initRows();
  initParties();
  if (document.getElementById('ai-bar')?.dataset.running === '1') pollAI();
});
