/* Büro — plain JS for invoice form interactivity */

/* ── Line items ──────────────────────────────────────────────────────────── */

let itemCount = document.querySelectorAll('.item-row').length;

function defaultUnit() {
  return document.getElementById('invoice-form')?.dataset.defaultUnit || 'Stück';
}

function addLineItem() {
  const tbody = document.getElementById('items-body');
  const idx   = itemCount++;
  const unit  = defaultUnit();
  const row   = document.createElement('tr');
  row.className = 'item-row';
  row.innerHTML = `
    <td><input type="text" name="positions[${idx}][description]" placeholder="Leistungsbeschreibung"></td>
    <td><input type="number" name="positions[${idx}][quantity]" value="1" step="any" min="0" class="item-qty" oninput="recalc()"></td>
    <td><input type="text" name="positions[${idx}][unit]" value="${unit}" list="unit-list" class="item-unit" placeholder="${unit}"></td>
    <td><input type="number" name="positions[${idx}][unit_price]" step="any" min="0" class="item-price" oninput="recalc()"></td>
    <td class="num item-total">—</td>
    <td><button type="button" class="btn-icon" onclick="removeRow(this)" title="Entfernen">✕</button></td>
  `;
  tbody.appendChild(row);
  row.querySelector('input').focus();
  renumberItems();
}

function removeRow(btn) {
  const row = btn.closest('tr');
  row.remove();
  renumberItems();
  recalc();
}

function renumberItems() {
  document.querySelectorAll('.item-row').forEach((row, i) => {
    row.querySelectorAll('input').forEach(inp => {
      inp.name = inp.name.replace(/positions\[\d+\]/, `positions[${i}]`);
    });
  });
}

/* ── Live totals ─────────────────────────────────────────────────────────── */

async function recalc() {
  const rows  = document.querySelectorAll('.item-row');
  const items = [];
  rows.forEach(row => {
    const qty   = parseFloat(row.querySelector('.item-qty')?.value)   || 0;
    const price = parseFloat(row.querySelector('.item-price')?.value) || 0;
    items.push({ quantity: qty, unit_price: price });

    const totalCell = row.querySelector('.item-total');
    if (totalCell) totalCell.textContent = fmtEur(qty * price);
  });

  const mwstSel  = document.querySelector('[name=mwst_rate]');
  const mwstRate = mwstSel ? parseFloat(mwstSel.value) || 0 : 0;

  try {
    const res  = await fetch('/api/totals', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items, mwst_rate: mwstRate }),
    });
    const data = await res.json();
    setEl('t-subtotal', data.subtotal_fmt);
    setEl('t-mwst',     data.mwst_fmt);
    setEl('t-total',    data.total_fmt);
  } catch (_) {}
}

function setEl(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function fmtEur(n) {
  return '€ ' + n.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/* ── Dates (TT.MM.JJJJ) ──────────────────────────────────────────────────── */

function parseDe(s) {
  s = (s || '').trim();
  let m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})$/);
  if (m) {
    const y = m[3].length === 2 ? 2000 + +m[3] : +m[3];
    const d = new Date(y, +m[2] - 1, +m[1]);
    return d.getMonth() === +m[2] - 1 ? d : null;  // rejects 31.02.
  }
  m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null;
}

function fmtDe(d) {
  const p = n => String(n).padStart(2, '0');
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()}`;
}

function addDays(d, n) {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

// Tidy "1.9.26" into "01.09.2026" on blur, and block submitting nonsense
function initDateInputs() {
  document.querySelectorAll('.date-input').forEach(inp => {
    inp.addEventListener('blur', () => {
      if (!inp.value.trim()) { inp.setCustomValidity(''); return; }
      const d = parseDe(inp.value);
      if (d) {
        inp.value = fmtDe(d);
        inp.setCustomValidity('');
      } else {
        inp.setCustomValidity('Bitte ein Datum im Format TT.MM.JJJJ eingeben');
        inp.reportValidity();
      }
    });
  });
}

/* ── Client ↔ project ────────────────────────────────────────────────────── */

// Picking a project picks its client; picking a client hides other clients' projects
function initClientProject() {
  const client  = document.getElementById('client-select');
  const project = document.getElementById('project-select');
  if (!client || !project) return;

  const filterProjects = () => {
    for (const opt of project.options) {
      const owner = opt.dataset.client;
      opt.hidden = !!(client.value && owner && owner !== client.value);
    }
    if (project.selectedOptions[0]?.hidden) project.value = '';
  };

  project.addEventListener('change', () => {
    const owner = project.selectedOptions[0]?.dataset.client;
    if (owner && owner !== client.value) {
      client.value = owner;
      client.dispatchEvent(new Event('change'));
    }
  });
  client.addEventListener('change', filterProjects);
  filterProjects();
}

/* ── New invoice: defaults that follow the client ────────────────────────── */

function initNewInvoice(form) {
  const typeSel  = document.getElementById('type-select');
  const number   = document.getElementById('number-input');
  const dateIn   = document.getElementById('date-input');
  const dueIn    = document.getElementById('due-date-input');
  const svcIn    = document.getElementById('service-date-input');
  const langSel  = document.getElementById('language-select');
  const titleIn  = document.getElementById('position-title');
  const client   = document.getElementById('client-select');
  const project  = document.getElementById('project-select');

  // Fields follow their defaults until the user types in them
  const touched = new Set();
  for (const el of [dueIn, svcIn, titleIn, langSel]) {
    el?.addEventListener('input', () => touched.add(el));
  }

  const syncDates = () => {
    const d = parseDe(dateIn.value);
    if (!d) return;
    if (dueIn && !touched.has(dueIn)) dueIn.value = fmtDe(addDays(d, +form.dataset.terms || 14));
    if (svcIn && !touched.has(svcIn)) svcIn.value = fmtDe(d);
  };
  dateIn?.addEventListener('change', syncDates);
  dateIn?.addEventListener('blur', syncDates);

  // Changing the type must not submit the form; just show that type's next number
  typeSel?.addEventListener('change', async () => {
    const res = await fetch(`/api/next-number?type=${encodeURIComponent(typeSel.value)}`);
    const { id } = await res.json();
    if (number.value === number.dataset.auto) number.value = id;
    number.dataset.auto = id;
    const h1 = document.querySelector('.page-header h1');
    if (h1) h1.textContent = 'Neue ' + typeSel.selectedOptions[0].textContent.trim();
  });

  const applyDefaults = async () => {
    const q = new URLSearchParams({ client_id: client.value, project_id: project?.value || '' });
    const d = await (await fetch(`/api/invoice-defaults?${q}`)).json();

    form.dataset.terms = d.payment_terms_days;
    setEl('due-hint', `${d.payment_terms_days} Tage nach Rechnungsdatum`);
    syncDates();

    if (langSel && !touched.has(langSel)) langSel.value = d.language;
    if (titleIn && !touched.has(titleIn)) titleIn.value = d.position_title;

    // Untouched rows switch to the client's usual unit
    const oldUnit = form.dataset.defaultUnit;
    form.dataset.defaultUnit = d.unit;
    document.querySelectorAll('.item-row').forEach(row => {
      const unit = row.querySelector('.item-unit');
      if (unit && (unit.value === oldUnit || !unit.value)) unit.value = d.unit;
      if (unit) unit.placeholder = d.unit;
    });
  };
  client?.addEventListener('change', applyDefaults);
  project?.addEventListener('change', applyDefaults);
}

/* ── Init ────────────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('items-body')) recalc();

  initDateInputs();
  initClientProject();
  const form = document.getElementById('invoice-form');
  if (form && form.dataset.edit === '0') initNewInvoice(form);

  // Success messages fade; errors and warnings stay until read
  document.querySelectorAll('.flash-success').forEach(el => {
    setTimeout(() => {
      el.style.transition = 'opacity .4s';
      el.style.opacity    = '0';
      setTimeout(() => el.remove(), 400);
    }, 4000);
  });
});
