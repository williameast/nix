/* Büro — plain JS for invoice form interactivity */

/* ── Line items ──────────────────────────────────────────────────────────── */

let itemCount = document.querySelectorAll('.item-row').length;

function addLineItem() {
  const tbody = document.getElementById('items-body');
  const idx   = itemCount++;
  const row   = document.createElement('tr');
  row.className = 'item-row';
  row.innerHTML = `
    <td><input type="text" name="positions[${idx}][description]" required placeholder="Leistungsbeschreibung"></td>
    <td><input type="number" name="positions[${idx}][quantity]" value="1" step="0.01" min="0" class="item-qty" oninput="recalc()"></td>
    <td><input type="text" name="positions[${idx}][unit]" value="Std." placeholder="Std."></td>
    <td><input type="number" name="positions[${idx}][unit_price]" step="0.01" min="0" class="item-price" oninput="recalc()"></td>
    <td class="num item-total">—</td>
    <td><button type="button" class="btn-icon" onclick="removeRow(this)" title="Entfernen">✕</button></td>
  `;
  tbody.appendChild(row);
  row.querySelector('input').focus();
  renumberItems();
}

function removeRow(btn) {
  const row = btn.closest('tr');
  if (document.querySelectorAll('.item-row').length <= 1) return;
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

/* ── Init ────────────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('items-body')) recalc();

  document.querySelectorAll('.flash').forEach(el => {
    setTimeout(() => {
      el.style.transition = 'opacity .4s';
      el.style.opacity    = '0';
      setTimeout(() => el.remove(), 400);
    }, 4000);
  });
});
