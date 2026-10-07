#!/usr/bin/env python3
"""
Büro — self-hosted freelance management for German Einzelunternehmer
Python/Flask + YAML backend, Plain HTML/JS frontend
"""

import os
import uuid
from copy import deepcopy
from datetime import datetime, timedelta, date
from io import BytesIO
from pathlib import Path
import base64
from collections import Counter

import yaml
import requests as req_lib
from flask import (Flask, render_template, request, redirect, url_for,
                   flash, jsonify, send_file, abort)

try:
    from weasyprint import HTML as WPHtml
    WEASYPRINT = True
except Exception:
    WEASYPRINT = False

try:
    import qrcode as _qrcode
    import qrcode.constants as _qrc
    QRCODE = True
except Exception:
    QRCODE = False

try:
    import pypdf as _pypdf
    PYPDF = True
except Exception:
    PYPDF = False

# APP_DIR  = read-only source tree (nix store when deployed, __file__ dir otherwise)
# DATA_DIR = writable persistent storage (/mnt/vault-new/buero when deployed)
APP_DIR  = Path(os.environ.get("BUERO_APP_DIR",  Path(__file__).parent))
DATA_DIR = Path(os.environ.get("BUERO_DATA_DIR", Path(__file__).parent))

app = Flask(
    __name__,
    template_folder=str(APP_DIR / "templates"),
    static_folder=str(APP_DIR / "static"),
)
app.secret_key = os.environ.get("SECRET_KEY", "buero-change-me")

CONFIG_FILE  = DATA_DIR / "config.yaml"
UPLOADS_DIR  = DATA_DIR / "uploads"      # logo, receipts (writable)

CLIENTS_DIR  = DATA_DIR / "data" / "clients"
INVOICES_DIR = DATA_DIR / "data" / "invoices"
EXPENSES_DIR = DATA_DIR / "data" / "expenses"
PROJECTS_DIR = DATA_DIR / "data" / "projects"

for _d in [CLIENTS_DIR, INVOICES_DIR, EXPENSES_DIR, PROJECTS_DIR, UPLOADS_DIR]:
    _d.mkdir(parents=True, exist_ok=True)

# ── Default config ────────────────────────────────────────────────────────────

DEFAULTS = {
    "business": {
        "name": "Vorname Nachname",
        "legal_name": "Vorname Nachname",
        "profession": "Einzelunternehmer",
        "address_line1": "Musterstraße 1",
        "address_line2": "10115 Berlin",
        "country": "Deutschland",
        "email": "",
        "phone": "",
        "website": "",
    },
    "tax": {
        "mode": "kleinunternehmer",
        "steuernummer": "",
        "ust_idnr": "",
        "mwst_rate": 19,
        "mwst_rate_reduced": 7,
    },
    "invoice": {
        "number_format": "{YEAR}-{SEQ:04d}",
        "payment_terms_days": 14,
        "currency": "EUR",
        "currency_symbol": "€",
        "bank_name": "",
        "iban": "",
        "bic": "",
        "default_notes": "Vielen Dank für Ihren Auftrag.",
    },
    "paperless": {
        "enabled": False,
        "base_url": "http://localhost:8000",
        "token": "",
    },
    "design": {
        "accent_color": "#1400FF",
        "logo_path": "",
    },
}


def deep_merge(base, over):
    result = deepcopy(base)
    for k, v in over.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_config():
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        return deep_merge(DEFAULTS, data)
    return deepcopy(DEFAULTS)


def save_config(cfg):
    _save(CONFIG_FILE, cfg)


# ── Form validation ───────────────────────────────────────────────────────────

class FormError(ValueError):
    """Invalid user input; the message is shown to the user as-is."""


def _parse_date_input(s, field=""):
    """Accept D.M.YYYY, D.M.YY or YYYY-MM-DD; normalise to YYYY-MM-DD for storage."""
    if not s:
        return ""
    s = str(s).strip()
    for fmt in ("%d.%m.%Y", "%d.%m.%y", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d")
        except ValueError:
            pass
    label = f" ({field})" if field else ""
    raise FormError(f"Ungültiges Datum{label}: „{s}“ – bitte TT.MM.JJJJ eingeben.")


DATE_FIELDS = ("date", "due_date", "service_date", "service_period_end",
               "paid_date", "start_date", "end_date")


def _normalize_dates(data):
    """Repair dates stored before input was validated (e.g. '1.09.2026')."""
    for k in DATE_FIELDS:
        if data.get(k):
            try:
                data[k] = _parse_date_input(data[k])
            except FormError:
                pass
    return data


# ── YAML data layer ───────────────────────────────────────────────────────────

def _load(path):
    with open(path, encoding="utf-8") as f:
        return _normalize_dates(yaml.safe_load(f) or {})


def _save(path, data):
    # Write to a temp file and rename, so a crash never leaves a half-written record
    tmp = path.with_name(f".{path.name}.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def _safe(id_str):
    return id_str.replace("/", "-").replace("\\", "-").replace("..", "")


# Clients
def all_clients():
    return sorted(
        [_load(p) for p in CLIENTS_DIR.glob("*.yaml")],
        key=lambda c: c.get("name", ""),
    )


def get_client(cid):
    p = CLIENTS_DIR / f"{_safe(cid)}.yaml"
    return _load(p) if p.exists() else None


def put_client(cid, data):
    _save(CLIENTS_DIR / f"{_safe(cid)}.yaml", data)


# Invoices
def all_invoices():
    inv = [_load(p) for p in INVOICES_DIR.glob("*.yaml")]
    return sorted(inv, key=lambda i: i.get("date", ""), reverse=True)


def get_invoice(iid):
    p = INVOICES_DIR / f"{_safe(iid)}.yaml"
    return _load(p) if p.exists() else None


def put_invoice(iid, data):
    _save(INVOICES_DIR / f"{_safe(iid)}.yaml", data)


def del_invoice(iid):
    p = INVOICES_DIR / f"{_safe(iid)}.yaml"
    if p.exists():
        p.unlink()


# Expenses
def _load_expense(path):
    exp = _load(path)
    exp.setdefault("id", path.stem)
    # Older edits dropped paperless_id; the id still encodes it
    if not exp.get("paperless_id") and exp["id"].startswith("exp-pl-"):
        try:
            exp["paperless_id"] = int(exp["id"].removeprefix("exp-pl-"))
        except ValueError:
            pass
    return exp


def all_expenses():
    exp = [_load_expense(p) for p in EXPENSES_DIR.glob("*.yaml")]
    return sorted(exp, key=lambda e: e.get("date", ""), reverse=True)


def get_expense(eid):
    p = EXPENSES_DIR / f"{_safe(eid)}.yaml"
    return _load_expense(p) if p.exists() else None


def put_expense(eid, data):
    _save(EXPENSES_DIR / f"{_safe(eid)}.yaml", data)


def del_expense(eid):
    p = EXPENSES_DIR / f"{_safe(eid)}.yaml"
    if p.exists():
        p.unlink()


# Projects
def all_projects():
    return sorted(
        [_load(p) for p in PROJECTS_DIR.glob("*.yaml")],
        key=lambda p: p.get("name", ""),
    )


def get_project(pid):
    p = PROJECTS_DIR / f"{_safe(pid)}.yaml"
    return _load(p) if p.exists() else None


def put_project(pid, data):
    _save(PROJECTS_DIR / f"{_safe(pid)}.yaml", data)


def del_project(pid):
    p = PROJECTS_DIR / f"{_safe(pid)}.yaml"
    if p.exists():
        p.unlink()


# ── Invoice numbering ─────────────────────────────────────────────────────────

COUNTERS_FILE = DATA_DIR / "counters.yaml"


def _number_candidate(cfg, doc_type):
    """Next free number for doc_type, plus the counter state that would claim it."""
    year = datetime.now().year
    prefix = {"quote": "A", "invoice": "", "receipt": "Q"}.get(doc_type, "")
    fmt    = cfg["invoice"]["number_format"]

    counters = _load(COUNTERS_FILE) if COUNTERS_FILE.exists() else {}
    key      = f"{doc_type}_{year}"
    seq      = int(counters.get(key, 0)) + 1

    # Skip over any IDs that already exist on disk (migration safety)
    while True:
        raw       = fmt.format(YEAR=year, SEQ=seq)
        candidate = f"{prefix}{raw}" if prefix else raw
        if not (INVOICES_DIR / f"{_safe(candidate)}.yaml").exists():
            break
        seq += 1

    counters[key] = seq
    return candidate, counters


def peek_number(cfg, doc_type="invoice"):
    """The number the next saved document will get, without using it up."""
    return _number_candidate(cfg, doc_type)[0]


def next_number(cfg, doc_type="invoice"):
    """Claim the next invoice/quote/receipt number.

    Uses a persistent counter (counters.yaml) to guarantee strictly
    sequential numbering as required by §14 UStG — safe across deletions.
    Only call this when a document is actually saved, or numbers get skipped.
    """
    candidate, counters = _number_candidate(cfg, doc_type)
    _save(COUNTERS_FILE, counters)
    return candidate


# ── Calculations ──────────────────────────────────────────────────────────────

def _line_total(p):
    return float(p.get("quantity") or 0) * float(p.get("unit_price") or 0)


def calc_totals(invoice, cfg):
    # "positions" is the canonical key; fall back to "items" for old YAML files
    items    = invoice.get("positions") or invoice.get("items") or []
    services = sum(_line_total(i) for i in items if not i.get("auslagenersatz"))
    auslagen = sum(_line_total(i) for i in items if i.get("auslagenersatz"))
    subtotal = services + auslagen
    if cfg["tax"]["mode"] == "regelbesteuerung":
        rate = invoice.get("mwst_rate")
        rate = float(cfg["tax"]["mwst_rate"] if rate in (None, "") else rate)  # 0 % is valid
        mwst = round(subtotal * rate / 100, 2)
        total = round(subtotal + mwst, 2)
    else:
        rate, mwst = 0.0, 0.0
        total = round(subtotal, 2)
    return {"services": round(services, 2), "auslagen": round(auslagen, 2),
            "subtotal": round(subtotal, 2), "mwst_rate": rate,
            "mwst": mwst, "total": total}


# ── Invoice status & bookkeeping helpers ──────────────────────────────────────

REVENUE_TYPES = ("invoice", "receipt")  # quotes never count


def effective_status(inv, today=None):
    """Stored status, except a sent invoice past its due date is 'overdue'."""
    status = inv.get("status", "draft")
    today  = (today or date.today()).isoformat()
    if status == "sent" and inv.get("due_date") and inv["due_date"] < today:
        return "overdue"
    return status


def is_billed(inv):
    """Issued to the client: counts as invoiced (sent, overdue or paid)."""
    return (inv.get("type", "invoice") in REVENUE_TYPES
            and inv.get("status") in ("sent", "paid"))


def income_date(inv):
    """EÜR cash basis (§11 EStG): income belongs to the day the money arrived."""
    return inv.get("paid_date") or inv.get("date", "")


def is_income_in(inv, year):
    return (inv.get("type", "invoice") in REVENUE_TYPES and inv.get("status") == "paid"
            and income_date(inv).startswith(str(year)))


def decorate_invoices(invoices, cfg):
    """Attach _client, _totals and the effective (overdue-aware) status for display."""
    clients_map = {c["id"]: c for c in all_clients() if "id" in c}
    today = date.today()
    for inv in invoices:
        inv["_client"] = clients_map.get(inv.get("client_id", ""), {})
        inv["_totals"] = calc_totals(inv, cfg)
        inv["status"]  = effective_status(inv, today)
    return invoices


# Kleinunternehmer limits since 2025 (§19 UStG): previous year ≤ 25.000 €,
# current year ≤ 100.000 € — the latter takes effect immediately when crossed.
KU_LIMIT_PREV = 25_000
KU_LIMIT_CURR = 100_000


def year_stats(cfg, year):
    invoices = decorate_invoices(all_invoices(), cfg)
    expenses = all_expenses()
    year = int(year)

    months = [{"month": m, "income": 0.0, "expenses": 0.0} for m in range(1, 13)]
    income = prev_income = 0.0
    for inv in invoices:
        if is_income_in(inv, year):
            income += inv["_totals"]["total"]
            months[int(income_date(inv)[5:7]) - 1]["income"] += inv["_totals"]["total"]
        elif is_income_in(inv, year - 1):
            prev_income += inv["_totals"]["total"]

    exp_total = 0.0
    by_cat = Counter()
    for e in expenses:
        if e.get("date", "").startswith(str(year)):
            amt = float(e.get("amount") or 0)
            exp_total += amt
            by_cat[e.get("category") or "Sonstiges"] += amt
            months[int(e["date"][5:7]) - 1]["expenses"] += amt

    open_invoices = [i for i in invoices if i["status"] in ("sent", "overdue")]
    peak = max([m["income"] for m in months] + [m["expenses"] for m in months] + [1])
    return {
        "year":          year,
        "income":        income,
        "expenses":      exp_total,
        "profit":        income - exp_total,
        "prev_income":   prev_income,
        "by_category":   by_cat.most_common(),
        "months":        months,
        "month_peak":    peak,
        "outstanding":   sum(i["_totals"]["total"] for i in open_invoices),
        "unpaid":        len(open_invoices),
        "overdue":       sum(1 for i in open_invoices if i["status"] == "overdue"),
        "recent":        invoices[:8],
        "client_count":  len(all_clients()),
        "ku_limit_prev": KU_LIMIT_PREV,
        "ku_limit_curr": KU_LIMIT_CURR,
        "years":         sorted({str(date.today().year)}
                                | {income_date(i)[:4] for i in invoices if income_date(i)}
                                | {e["date"][:4] for e in expenses if e.get("date")},
                                reverse=True),
    }


def fmt_eur(v, sym="€"):
    try:
        s = f"{float(v):,.2f}"
        s = s.replace(",", "X").replace(".", ",").replace("X", ".")
        return f"{sym} {s}"
    except Exception:
        return str(v)


# ── Paperless-ngx client ──────────────────────────────────────────────────────

class Paperless:
    def __init__(self, base, token):
        self.base = base.rstrip("/")
        self.h = {"Authorization": f"Token {token}"}

    def documents(self, page=1, q=None):
        params = {"page": page}
        if q:
            params["query"] = q
        r = req_lib.get(f"{self.base}/api/documents/", headers=self.h,
                        params=params, timeout=10)
        r.raise_for_status()
        return r.json()

    def document(self, did):
        r = req_lib.get(f"{self.base}/api/documents/{did}/", headers=self.h, timeout=10)
        r.raise_for_status()
        return r.json()

    def correspondents(self):
        """{id: name} — the documents API only returns correspondent ids."""
        r = req_lib.get(f"{self.base}/api/correspondents/", headers=self.h,
                        params={"page_size": 1000}, timeout=10)
        r.raise_for_status()
        return {c["id"]: c["name"] for c in r.json().get("results", [])}

    def thumb(self, did):
        return f"{self.base}/api/documents/{did}/thumb/"

    def download(self, did):
        return f"{self.base}/api/documents/{did}/download/"


# ── PDF helpers ───────────────────────────────────────────────────────────────

def load_logo_b64(cfg):
    """Return logo as a base64 data URI, or None if not available."""
    try:
        logo_path = cfg["design"].get("logo_path", "")
        if not logo_path:
            return None
        p = UPLOADS_DIR / logo_path
        if not p.exists():
            return None
        ext = p.suffix.lower().lstrip(".")
        mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                "svg": "image/svg+xml", "gif": "image/gif"}.get(ext, "image/png")
        data = base64.b64encode(p.read_bytes()).decode()
        return f"data:{mime};base64,{data}"
    except Exception:
        return None


def make_epc_qr(cfg, invoice, totals):
    """Generate EPC/GiroCode QR for SEPA bank transfer (base64 PNG string)."""
    if not QRCODE:
        return None
    try:
        iban = (cfg["invoice"].get("iban") or "").replace(" ", "").replace("-", "")
        if not iban:
            return None
        bic  = (cfg["invoice"].get("bic") or "").strip()
        name = (cfg["business"].get("name") or "")[:70]
        amount = f"EUR{totals['total']:.2f}"
        ref = (invoice.get("payment_ref") or invoice.get("id") or "")[:140]
        # EPC QR / GiroCode standard (SEPA Credit Transfer)
        data = "\n".join(["BCD", "002", "1", "SCT", bic, name, iban,
                          amount, "", "", ref])
        qr = _qrcode.QRCode(
            error_correction=_qrc.ERROR_CORRECT_M,
            box_size=6, border=2,
        )
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buf = BytesIO()
        img.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode()
    except Exception:
        return None


def make_invoice_qr(invoice_id):
    """Generate small QR with invoice ID for footer micrographic (base64 PNG)."""
    if not QRCODE:
        return None
    try:
        qr = _qrcode.QRCode(
            error_correction=_qrc.ERROR_CORRECT_M,
            box_size=4, border=2,
        )
        qr.add_data(str(invoice_id))
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buf = BytesIO()
        img.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode()
    except Exception:
        return None


# ── Receipt → PDF helper ──────────────────────────────────────────────────────

def receipt_to_pdf_bytes(source, label="", mime_hint=""):
    """Convert a receipt to PDF bytes ready for pypdf merging.

    source may be a filesystem Path, or raw bytes (in which case mime_hint
    should be the Content-Type, e.g. 'application/pdf' or 'image/jpeg').
    """
    if isinstance(source, (str, Path)):
        path = Path(source)
        ext  = path.suffix.lower()
        if ext == ".pdf":
            return path.read_bytes()
        raw  = path.read_bytes()
        mime = "image/jpeg" if ext in (".jpg", ".jpeg") else "image/png"
    else:
        raw  = source
        mime = mime_hint or "application/pdf"

    if mime == "application/pdf":
        return raw

    if WEASYPRINT and mime.startswith("image/"):
        try:
            b64  = base64.b64encode(raw).decode()
            html = f"""<!DOCTYPE html><html><head><style>
@page {{ size: A4; margin: 15mm; }}
body {{ margin:0; font-family: sans-serif; }}
.lbl {{ font-size:8pt; color:#888; margin-bottom:6mm; }}
img {{ max-width:100%; max-height:255mm; display:block; }}
</style></head><body>
<div class="lbl">Beleg: {label}</div>
<img src="data:{mime};base64,{b64}">
</body></html>"""
            return WPHtml(string=html).write_pdf()
        except Exception:
            return None
    return None


def fetch_paperless_receipt_bytes(exp, cfg):
    """Download the original file for a Paperless-imported expense.
    Returns (raw_bytes, mime_type) or (None, None) on failure.
    """
    pid = exp.get("paperless_id")
    if not pid or not cfg.get("paperless", {}).get("enabled"):
        return None, None
    try:
        pl = Paperless(cfg["paperless"]["base_url"], cfg["paperless"]["token"])
        r  = req_lib.get(pl.download(pid), headers=pl.h, timeout=30)
        r.raise_for_status()
        mime = r.headers.get("Content-Type", "application/pdf").split(";")[0].strip()
        return r.content, mime
    except Exception as e:
        app.logger.warning("Paperless receipt fetch failed for id=%s: %s", pid, e)
        return None, None


def append_receipts_to_writer(writer, invoice, cfg=None):
    """Append receipt PDFs for all Auslagenersatz positions in the invoice."""
    if not PYPDF:
        return
    for pos in (invoice.get("positions") or []):
        if not pos.get("auslagenersatz"):
            continue
        eid = pos.get("expense_id")
        if not eid:
            continue
        exp = get_expense(eid)
        if not exp:
            continue

        pdf_bytes = None
        label     = exp.get("description", eid)

        if exp.get("receipt_file"):
            receipt_path = UPLOADS_DIR / exp["receipt_file"]
            if not receipt_path.exists():
                # Legacy: expense_new stored filename without "receipt-" prefix
                # but actually saved the file with it. Try the prefixed name.
                alt = UPLOADS_DIR / f"receipt-{exp['receipt_file']}"
                if alt.exists():
                    receipt_path = alt
            if receipt_path.exists():
                pdf_bytes = receipt_to_pdf_bytes(receipt_path, label=label)
            else:
                app.logger.warning("Receipt file not found for expense %s: %s", eid, exp["receipt_file"])
        elif exp.get("paperless_id") and cfg:
            raw, mime = fetch_paperless_receipt_bytes(exp, cfg)
            if raw:
                pdf_bytes = receipt_to_pdf_bytes(raw, label=label, mime_hint=mime)

        if pdf_bytes:
            try:
                for page in _pypdf.PdfReader(BytesIO(pdf_bytes)).pages:
                    writer.add_page(page)
            except Exception:
                pass


# ── Translations ──────────────────────────────────────────────────────────────

_TRANSLATIONS = {
    "de": {
        "invoice": "Rechnung", "quote": "Angebot", "receipt": "Quittung",
        "from_lbl": "Von", "to_lbl": "An",
        "doc_nr_lbl": "Rechnungsnummer",
        "date": "Datum", "service_period": "Leistungszeitraum",
        "service_date": "Leistungsdatum", "project": "Projekt",
        "order_nr": "Bestell-Nr.", "position": "Position", "ref": "Verwendungszweck",
        "pos": "Pos.", "description": "Beschreibung / Leistung",
        "qty": "Menge", "unit": "Einheit",
        "unit_price": "Einzelpreis", "total_col": "Gesamt",
        "expense_reimb": "Auslagenersatz", "desc_short": "Beschreibung",
        "amount": "Betrag",
        "net": "Nettobetrag", "vat": "MwSt.", "total_amount": "Gesamtbetrag",
        "ku_note": "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
        "notes_lbl": "Anmerkungen",
        "payment_received": "Zahlungseingang",
        "payment_body": lambda amt, date, ref: (
            f"Betrag von <strong>{amt}</strong> wurde beglichen."
            + (f"<br>Zahlungsdatum: <strong>{date}</strong>" if date else "")
            + f"<br>Verwendungszweck: {ref}"
        ),
        "paid_badge": "✓ BEZAHLT", "paid_watermark": "BEZAHLT",
        "payment_info": "Zahlungsinformationen",
        "please_pay": lambda amt, due: f"Bitte überweisen Sie <strong>{amt}</strong> bis zum <strong>{due}</strong>.",
        "usage": "Verwendungszweck", "girocode": "GiroCode", "sepa": "SEPA-Überweisung",
        "address": "Adresse", "contact": "Kontakt", "tax": "Steuer", "bank": "Bank",
        "subtotal_services": "Zwischensumme Leistungen", "subtotal_expenses": "Zwischensumme Auslagen",
        "receipts_attached": "Die Belege sind dieser Rechnung angehängt.",
    },
    "en": {
        "invoice": "Invoice", "quote": "Quote", "receipt": "Receipt",
        "from_lbl": "From", "to_lbl": "To",
        "doc_nr_lbl": "Invoice Number",
        "date": "Date", "service_period": "Service Period",
        "service_date": "Service Date", "project": "Project",
        "order_nr": "Order No.", "position": "Role", "ref": "Reference",
        "pos": "Item", "description": "Description / Service",
        "qty": "Qty", "unit": "Unit",
        "unit_price": "Unit Price", "total_col": "Total",
        "expense_reimb": "Expense Reimbursement", "desc_short": "Description",
        "amount": "Amount",
        "net": "Net Amount", "vat": "VAT", "total_amount": "Total Amount",
        "ku_note": "Pursuant to § 19 UStG (German VAT Act), no value-added tax is charged.",
        "notes_lbl": "Notes",
        "payment_received": "Payment Received",
        "payment_body": lambda amt, date, ref: (
            f"Payment of <strong>{amt}</strong> has been received."
            + (f"<br>Payment Date: <strong>{date}</strong>" if date else "")
            + f"<br>Reference: {ref}"
        ),
        "paid_badge": "✓ PAID", "paid_watermark": "PAID",
        "payment_info": "Payment Information",
        "please_pay": lambda amt, due: f"Please transfer <strong>{amt}</strong> by <strong>{due}</strong>.",
        "usage": "Reference", "girocode": "GiroCode", "sepa": "SEPA Transfer",
        "address": "Address", "contact": "Contact", "tax": "Tax", "bank": "Bank",
        "subtotal_services": "Subtotal services", "subtotal_expenses": "Subtotal expenses",
        "receipts_attached": "Receipts are attached to this invoice.",
    },
}


# ── PDF generation ────────────────────────────────────────────────────────────

def make_pdf(invoice, client, cfg, project=None):
    from jinja2 import Environment, FileSystemLoader
    totals   = calc_totals(invoice, cfg)
    logo_b64 = load_logo_b64(cfg)
    epc_qr   = make_epc_qr(cfg, invoice, totals) if invoice.get("type") == "invoice" else None
    inv_qr   = make_invoice_qr(invoice.get("id", ""))
    lang     = invoice.get("language", "de")
    t        = _TRANSLATIONS.get(lang, _TRANSLATIONS["de"])

    env = Environment(loader=FileSystemLoader(str(APP_DIR / "pdf_templates")))
    env.filters["eur"] = lambda v: fmt_eur(float(v or 0), cfg["invoice"]["currency_symbol"])
    env.filters["date_de"] = _date_de

    # Pre-render the callable strings so the template stays simple
    paid_date_fmt = _date_de(invoice.get("paid_date", ""))
    total_fmt     = fmt_eur(totals["total"], cfg["invoice"]["currency_symbol"])
    due_fmt       = _date_de(invoice.get("due_date", ""))
    t_rendered    = dict(t)
    t_rendered["payment_body_html"] = t["payment_body"](
        total_fmt, paid_date_fmt, invoice.get("payment_ref") or invoice.get("id", "")
    )
    t_rendered["please_pay_html"] = t["please_pay"](total_fmt, due_fmt)

    tmpl = env.get_template("invoice.html")
    html = tmpl.render(
        invoice=invoice,
        client=client,
        cfg=cfg,
        totals=totals,
        project=project,
        logo_b64=logo_b64,
        epc_qr=epc_qr,
        inv_qr=inv_qr,
        kleinunternehmer=cfg["tax"]["mode"] == "kleinunternehmer",
        now=datetime.now(),
        t=t_rendered,
        lang=lang,
    )

    if WEASYPRINT:
        pdf_bytes = WPHtml(string=html, base_url=str(APP_DIR)).write_pdf()
        return pdf_bytes, "application/pdf"
    else:
        return html.encode("utf-8"), "text/html"


# ── Template helpers ──────────────────────────────────────────────────────────

def _date_de(v):
    if not v:
        return ""
    try:
        return datetime.strptime(str(v), "%Y-%m-%d").strftime("%d.%m.%Y")
    except ValueError:
        return str(v)


@app.template_filter("eur")
def tpl_eur(v):
    cfg = load_config()
    return fmt_eur(float(v or 0), cfg["invoice"]["currency_symbol"])


@app.template_filter("date_de")
def tpl_date(v):
    return _date_de(v)


@app.template_filter("status_de")
def tpl_status(s):
    return {
        "draft": "Entwurf", "sent": "Versendet",
        "paid": "Bezahlt", "overdue": "Überfällig",
        "cancelled": "Storniert",
    }.get(s, s or "—")


@app.template_filter("type_de")
def tpl_type(t):
    return {"invoice": "Rechnung", "quote": "Angebot",
            "receipt": "Quittung"}.get(t, t or "Rechnung")


@app.context_processor
def inject_cfg():
    cfg = load_config()
    base = cfg["paperless"]["base_url"].rstrip("/")
    return {"cfg": cfg,
            "paperless_doc_url": lambda did: f"{base}/documents/{did}/",
            "url_with": url_with}


def url_with(endpoint, args, **changes):
    """url_for with the current filters, some changed; empty values are dropped."""
    return url_for(endpoint, **{k: v for k, v in {**args, **changes}.items() if v})


# ── User-uploaded files (logo, receipts) served from writable DATA_DIR ───────

@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    from flask import send_from_directory
    return send_from_directory(UPLOADS_DIR, filename)


# ── Routes: dashboard ─────────────────────────────────────────────────────────

@app.route("/")
def dashboard():
    year = request.args.get("year", "")
    year = int(year) if year.isdigit() else date.today().year
    return render_template("dashboard.html", stats=year_stats(load_config(), year))


# ── Routes: clients ───────────────────────────────────────────────────────────

@app.route("/clients")
def clients_list():
    return render_template("clients/list.html", clients=all_clients())


@app.route("/clients/new", methods=["GET", "POST"])
def client_new():
    if request.method == "POST":
        data = request.form.to_dict()
        cid = data.get("id") or f"client-{uuid.uuid4().hex[:8]}"
        data["id"] = cid
        data.setdefault("created", datetime.now().strftime("%Y-%m-%d"))
        put_client(cid, data)
        flash("Kunde gespeichert.", "success")
        return redirect(url_for("client_detail", cid=cid))
    return render_template("clients/form.html", client={}, edit=False)


@app.route("/clients/<cid>")
def client_detail(cid):
    client = get_client(cid)
    if not client:
        abort(404)
    cfg = load_config()
    inv = decorate_invoices([i for i in all_invoices() if i.get("client_id") == cid], cfg)
    billed = [i for i in inv if is_billed(i)]
    unbilled = [e for e in all_expenses() if e.get("client_id") == cid and not e.get("invoice_id")]
    summary = {
        "billed":      sum(i["_totals"]["total"] for i in billed),
        "paid":        sum(i["_totals"]["total"] for i in billed if i["status"] == "paid"),
        "outstanding": sum(i["_totals"]["total"] for i in billed if i["status"] in ("sent", "overdue")),
        "unbilled_expenses": sum(float(e.get("amount") or 0) for e in unbilled),
        "unbilled_count":    len(unbilled),
    }
    return render_template("clients/detail.html", client=client, invoices=inv, summary=summary)


@app.route("/clients/<cid>/edit", methods=["GET", "POST"])
def client_edit(cid):
    client = get_client(cid)
    if not client:
        abort(404)
    if request.method == "POST":
        data = {**client, **request.form.to_dict(), "id": cid}  # keeps "created"
        put_client(cid, data)
        flash("Kunde aktualisiert.", "success")
        return redirect(url_for("client_detail", cid=cid))
    return render_template("clients/form.html", client=client, edit=True)


@app.route("/clients/<cid>/delete", methods=["POST"])
def client_delete(cid):
    n_inv = sum(1 for i in all_invoices() if i.get("client_id") == cid)
    if n_inv:
        # Their invoices would lose name and address on every future PDF
        flash(f"Kunde hat {n_inv} Rechnung(en)/Angebot(e) und kann nicht gelöscht werden.", "error")
        return redirect(url_for("client_detail", cid=cid))
    p = CLIENTS_DIR / f"{_safe(cid)}.yaml"
    if p.exists():
        p.unlink()
    flash("Kunde gelöscht.", "success")
    return redirect(url_for("clients_list"))


# ── Routes: invoices ──────────────────────────────────────────────────────────

@app.route("/invoices")
def invoices_list():
    cfg = load_config()
    invoices = decorate_invoices(all_invoices(), cfg)
    years = sorted({i.get("date", "")[:4] for i in invoices if i.get("date")}, reverse=True)

    year_filter   = request.args.get("year", "")
    status_filter = request.args.get("status", "")
    if year_filter:
        invoices = [i for i in invoices if i.get("date", "").startswith(year_filter)]

    # Per-status count and sum for the filter chips (within the chosen year)
    chips = {}
    for i in invoices:
        c = chips.setdefault(i["status"], {"count": 0, "sum": 0.0})
        c["count"] += 1
        c["sum"]   += i["_totals"]["total"]

    if status_filter:
        invoices = [i for i in invoices if i["status"] == status_filter]
    # Quotes and cancelled documents aren't money owed or earned
    total = sum(i["_totals"]["total"] for i in invoices if is_billed(i))
    return render_template("invoices/list.html", invoices=invoices, chips=chips,
                           total=total, years=years, year_filter=year_filter,
                           status_filter=status_filter)


UNITS = ["Stück", "Tag", "Std.", "Pauschale", "Woche"]


def invoice_defaults(cfg, client_id="", project_id=""):
    """Defaults for a new invoice: the client's own settings, else whatever was
    used on the last document for this project/client, else the global config."""
    project = get_project(project_id) if project_id else None
    if project and not client_id:
        client_id = project.get("client_id", "")
    client = (get_client(client_id) if client_id else None) or {}

    history = all_invoices()  # newest first
    last = (next((i for i in history if project_id and i.get("project_id") == project_id), None)
            or next((i for i in history if client_id and i.get("client_id") == client_id), None)
            or {})
    last_units = [p["unit"] for p in last.get("positions") or []
                  if p.get("unit") and not p.get("auslagenersatz")]

    try:
        terms = int(client.get("payment_terms_days") or cfg["invoice"]["payment_terms_days"])
    except ValueError:
        terms = int(cfg["invoice"]["payment_terms_days"])

    return {
        "client_id":          client_id,
        "language":           client.get("language") or last.get("language") or "de",
        "payment_terms_days": terms,
        "position_title":     last.get("position_title") or "",
        "unit":               last_units[0] if last_units else UNITS[0],
    }


def _render_invoice_form(inv, edit, status=200):
    cfg = load_config()
    defaults = invoice_defaults(cfg, inv.get("client_id", ""), inv.get("project_id", ""))
    return render_template("invoices/form.html", invoice=inv, edit=edit,
                           clients=all_clients(), projects=all_projects(),
                           units=UNITS, defaults=defaults), status


@app.route("/invoices/new", methods=["GET", "POST"])
def invoice_new():
    cfg = load_config()
    doc_type = request.args.get("type", "invoice")

    if request.method == "POST":
        data, errors = _parse_invoice_form(request.form, cfg)
        requested = data["id"]
        if not errors:
            if not requested or requested == peek_number(cfg, data["type"]):
                data["id"] = next_number(cfg, data["type"])
            elif get_invoice(requested) is not None:
                errors.append(f"Die Nummer {requested} ist bereits vergeben.")
        if errors:
            for e in errors:
                flash(e, "error")
            return _render_invoice_form(data, edit=False, status=400)
        _apply_status(data, data["status"], data.pop("paid_date", ""))
        put_invoice(data["id"], data)
        flash(f'{tpl_type(data["type"])} {data["id"]} gespeichert.', "success")
        return redirect(url_for("invoice_detail", iid=data["id"]))

    d = invoice_defaults(cfg, request.args.get("client_id", ""),
                         request.args.get("project_id", ""))
    today = datetime.now()
    inv = {
        "id":                 peek_number(cfg, doc_type),
        "type":               doc_type,
        "status":             "draft",
        "date":               today.strftime("%Y-%m-%d"),
        "due_date":           (today + timedelta(days=d["payment_terms_days"])).strftime("%Y-%m-%d"),
        "service_date":       today.strftime("%Y-%m-%d"),
        "service_period_end": "",
        "client_id":          d["client_id"],
        "project_id":         request.args.get("project_id", ""),
        "positions": [{"description": "", "quantity": 1, "unit": d["unit"], "unit_price": ""}],
        "notes":              cfg["invoice"]["default_notes"],
        "mwst_rate":          cfg["tax"]["mwst_rate"],
        "language":           d["language"],
        "position_title":     d["position_title"],
    }
    return _render_invoice_form(inv, edit=False)


@app.route("/invoices/<path:iid>", methods=["GET"])
def invoice_detail(iid):
    cfg = load_config()
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    # migrate old "items" key
    if "items" in inv and "positions" not in inv:
        inv["positions"] = inv.pop("items")
    client  = get_client(inv.get("client_id", "")) or {}
    project = get_project(inv.get("project_id", "")) if inv.get("project_id") else None
    totals  = calc_totals(inv, cfg)

    # Unbilled expenses of this client; on a project invoice, other projects' are left out
    available_auslagen = [
        e for e in all_expenses()
        if not e.get("invoice_id")
        and inv.get("client_id") and e.get("client_id") == inv["client_id"]
        and (not inv.get("project_id") or e.get("project_id") in ("", None, inv["project_id"]))
    ]
    n_receipts = sum(1 for p in inv.get("positions") or [] if p.get("auslagenersatz"))

    return render_template("invoices/detail.html", invoice=inv, client=client,
                           project=project, totals=totals,
                           kleinunternehmer=cfg["tax"]["mode"] == "kleinunternehmer",
                           available_auslagen=available_auslagen,
                           n_receipts=n_receipts,
                           today=date.today().isoformat(),
                           cfg=cfg)


@app.route("/invoices/<path:iid>/edit", methods=["GET", "POST"])
def invoice_edit(iid):
    cfg = load_config()
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    # migrate old "items" key on load
    if "items" in inv and "positions" not in inv:
        inv["positions"] = inv.pop("items")
    if request.method == "POST":
        parsed, errors = _parse_invoice_form(request.form, cfg)
        # Keep fields the form doesn't carry (paid_date, quote_ref, …).
        # The type is fixed once saved: a quote becomes an invoice via "umwandeln".
        data = {**inv, **parsed, "id": iid, "type": inv.get("type", "invoice")}
        data.pop("items", None)
        if errors:
            for e in errors:
                flash(e, "error")
            return _render_invoice_form(data, edit=True, status=400)
        _apply_status(data, data["status"], data.pop("paid_date", "") or inv.get("paid_date", ""))
        put_invoice(iid, data)
        flash(f'{tpl_type(data["type"])} aktualisiert.', "success")
        return redirect(url_for("invoice_detail", iid=iid))
    return _render_invoice_form(inv, edit=True)


@app.route("/invoices/<path:iid>/pdf")
def invoice_pdf(iid):
    """The invoice, followed by the receipt of every Auslagenersatz line (?receipts=0 to skip)."""
    cfg = load_config()
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    client  = get_client(inv.get("client_id", "")) or {}
    project = get_project(inv.get("project_id", "")) if inv.get("project_id") else None
    data, mimetype = make_pdf(inv, client, cfg, project=project)
    if not WEASYPRINT:
        return send_file(BytesIO(data), mimetype=mimetype, download_name=f"{_safe(iid)}.html")

    fname = f"{tpl_type(inv.get('type', 'invoice'))}-{_safe(iid)}.pdf"
    if PYPDF and request.args.get("receipts", "1") != "0":
        writer = _pypdf.PdfWriter()
        for page in _pypdf.PdfReader(BytesIO(data)).pages:
            writer.add_page(page)
        append_receipts_to_writer(writer, inv, cfg)
        out = BytesIO()
        writer.write(out)
        data = out.getvalue()
    return send_file(BytesIO(data), mimetype="application/pdf", download_name=fname, as_attachment=True)


def _expense_position(exp):
    desc = exp.get("description") or "Ausgabe"
    if exp.get("vendor"):
        desc += f" ({exp['vendor']})"
    if exp.get("date"):
        desc += f" – {_date_de(exp['date'])}"
    return {
        "description":    desc,
        "quantity":       1.0,
        "unit":           "Pauschale",
        "unit_price":     float(exp.get("amount") or 0),
        "auslagenersatz": True,
        "expense_id":     exp["id"],
    }


def _attach_expenses(inv, expenses):
    for exp in sorted(expenses, key=lambda e: e.get("date", "")):
        inv.setdefault("positions", []).append(_expense_position(exp))
        exp["invoice_id"] = inv["id"]
        exp["client_id"]  = exp.get("client_id") or inv.get("client_id", "")
        put_expense(exp["id"], exp)


@app.route("/invoices/<path:iid>/add-auslagen", methods=["POST"])
def invoice_add_auslagen(iid):
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    expenses = [e for e in map(get_expense, request.form.getlist("expense_ids"))
                if e and not e.get("invoice_id")]
    _attach_expenses(inv, expenses)
    put_invoice(iid, inv)
    flash(f"{len(expenses)} Auslagen hinzugefügt.", "success")
    return redirect(url_for("invoice_detail", iid=iid))


REIMBURSEMENT_NOTES = {
    "de": "Erstattung verauslagter Kosten.",
    "en": "Reimbursement of expenses paid on your behalf.",
}


@app.route("/invoices/from-expenses", methods=["POST"])
def invoice_from_expenses():
    """A draft invoice containing nothing but Auslagenersatz for the chosen expenses."""
    cfg = load_config()
    expenses = [e for e in map(get_expense, request.form.getlist("expense_ids"))
                if e and not e.get("invoice_id")]
    back = request.form.get("next") or url_for("expenses_list")
    if not expenses:
        flash("Keine offenen Ausgaben ausgewählt.", "error")
        return redirect(back)

    client_id = request.form.get("client_id", "")
    owners = {e["client_id"] for e in expenses if e.get("client_id")}
    if not client_id and len(owners) == 1:
        client_id = next(iter(owners))
    if not client_id:
        flash("Bitte den Kunden wählen, der die Auslagen erstattet.", "error")
        return redirect(back)
    if owners - {client_id}:
        flash("Die gewählten Ausgaben gehören zu verschiedenen Kunden.", "error")
        return redirect(back)

    projects   = {e.get("project_id") or "" for e in expenses}
    project_id = next(iter(projects)) if len(projects) == 1 else ""
    d     = invoice_defaults(cfg, client_id, project_id)
    dates = sorted(e["date"] for e in expenses if e.get("date"))
    today = date.today()
    iid   = next_number(cfg, "invoice")
    inv = {
        "id":                 iid,
        "type":               "invoice",
        "status":             "draft",
        "date":               today.isoformat(),
        "due_date":           (today + timedelta(days=d["payment_terms_days"])).isoformat(),
        "service_date":       dates[0] if dates else today.isoformat(),
        "service_period_end": dates[-1] if len(set(dates)) > 1 else "",
        "client_id":          client_id,
        "project_id":         project_id,
        "positions":          [],
        "notes":              REIMBURSEMENT_NOTES.get(d["language"], REIMBURSEMENT_NOTES["de"]),
        "mwst_rate":          cfg["tax"]["mwst_rate"],
        "language":           d["language"],
        "position_title":     d["position_title"],
        "payment_ref":        iid,
    }
    _attach_expenses(inv, expenses)
    put_invoice(iid, inv)
    flash(f"Erstattungsrechnung {iid} mit {len(expenses)} Beleg(en) erstellt.", "success")
    return redirect(url_for("invoice_detail", iid=iid))


@app.route("/invoices/<path:iid>/status", methods=["POST"])
def invoice_status(iid):
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    new = request.form.get("status", "")
    if new not in ("draft", "sent", "paid", "cancelled"):
        abort(400)
    try:
        paid_date = _parse_date_input(request.form.get("paid_date", ""), "Zahlungsdatum")
    except FormError as e:
        flash(str(e), "error")
        return redirect(url_for("invoice_detail", iid=iid))
    _apply_status(inv, new, paid_date)
    put_invoice(iid, inv)
    msg = f"Status: {tpl_status(new)}"
    if new == "paid":
        msg += f" am {_date_de(inv['paid_date'])}"
    flash(msg, "success")
    return redirect(url_for("invoice_detail", iid=iid))


def _apply_status(inv, status, paid_date=""):
    """Set status and keep the dates that go with it consistent."""
    today = date.today().isoformat()
    inv["status"] = status
    if status == "paid":
        # The date the money arrived decides the tax year (§11 EStG), not the click
        inv["paid_date"] = paid_date or inv.get("paid_date") or today
    else:
        inv.pop("paid_date", None)
    if status in ("sent", "paid"):
        inv.setdefault("sent_date", today)


@app.route("/invoices/<path:iid>/delete", methods=["POST"])
def invoice_delete(iid):
    # Free any expenses that were attached to this invoice
    inv = get_invoice(iid)
    if inv:
        for pos in (inv.get("positions") or []):
            eid = pos.get("expense_id")
            if eid:
                exp = get_expense(eid)
                if exp and exp.get("invoice_id") == iid:
                    exp.pop("invoice_id", None)
                    put_expense(eid, exp)
    del_invoice(iid)
    flash("Gelöscht.", "success")
    return redirect(url_for("invoices_list"))


@app.route("/expenses/<eid>/unassign", methods=["POST"])
def expense_unassign(eid):
    """Remove invoice_id from an expense so it can be attached to another invoice."""
    exp = get_expense(eid)
    if not exp:
        abort(404)
    iid = exp.pop("invoice_id", None)
    # Also remove the corresponding position from the invoice, if it still exists
    if iid:
        inv = get_invoice(iid)
        if inv:
            inv["positions"] = [p for p in (inv.get("positions") or []) if p.get("expense_id") != eid]
            put_invoice(iid, inv)
    put_expense(eid, exp)
    flash("Ausgabe aus Rechnung entfernt.", "success")
    return redirect(url_for("expense_detail", eid=eid))


@app.route("/invoices/<path:iid>/to-invoice", methods=["POST"])
def quote_to_invoice(iid):
    cfg = load_config()
    quote = get_invoice(iid)
    if not quote:
        abort(404)
    new_id = next_number(cfg, "invoice")
    today  = date.today()
    terms  = invoice_defaults(cfg, quote.get("client_id", ""))["payment_terms_days"]
    inv = deepcopy(quote)
    for k in ("paid_date", "sent_date"):
        inv.pop(k, None)
    inv.update({
        "id": new_id,
        "type": "invoice",
        "status": "draft",
        "date": today.isoformat(),
        "due_date": (today + timedelta(days=terms)).isoformat(),
        "service_date": today.isoformat(),  # the quote's date isn't when the work happened
        "payment_ref": new_id,
        "quote_ref": iid,
        # Expense lines stay with their own invoices; add them on the new one if needed
        "positions": [p for p in quote.get("positions") or [] if not p.get("auslagenersatz")],
    })
    put_invoice(new_id, inv)
    flash(f"Angebot in Rechnung {new_id} umgewandelt – bitte Leistungsdatum prüfen.", "success")
    return redirect(url_for("invoice_detail", iid=new_id))


def _parse_invoice_form(form, cfg):
    """Returns (data, errors). On errors, data keeps the raw input for re-display."""
    errors = []

    def date_field(name, label):
        raw = form.get(name, "")
        try:
            return _parse_date_input(raw, label)
        except FormError as e:
            errors.append(str(e))
            return raw

    data = {
        "id":                 form.get("id", "").strip(),
        "type":               form.get("type", "invoice"),
        "status":             form.get("status", "draft"),
        "date":               date_field("date", "Rechnungsdatum"),
        "due_date":           date_field("due_date", "Fälligkeitsdatum"),
        "service_date":       date_field("service_date", "Leistungsdatum"),
        "service_period_end": date_field("service_period_end", "Leistungszeitraum bis"),
        "paid_date":          date_field("paid_date", "Bezahlt am"),
        "client_id":          form.get("client_id", ""),
        "project_id":         form.get("project_id", ""),
        "notes":              form.get("notes", ""),
        "payment_ref":        form.get("payment_ref", ""),
        "mwst_rate":          float(form.get("mwst_rate") or cfg["tax"]["mwst_rate"]),
        "position_title":     form.get("position_title", ""),
        "language":           form.get("language", "de"),
    }
    positions, i = [], 0
    while True:
        desc = form.get(f"positions[{i}][description]")
        if desc is None:
            break
        try:
            qty   = float(form.get(f"positions[{i}][quantity]") or 1)
            price = float(form.get(f"positions[{i}][unit_price]") or 0)
        except ValueError:
            qty, price = 1.0, 0.0
        if desc.strip():  # skip blank rows
            pos = {
                "description": desc,
                "quantity":    qty,
                "unit":        form.get(f"positions[{i}][unit]", "Std."),
                "unit_price":  price,
            }
            # Preserve Auslagenersatz metadata so receipt links survive edits
            if form.get(f"positions[{i}][auslagenersatz]"):
                pos["auslagenersatz"] = True
                pos["expense_id"]     = form.get(f"positions[{i}][expense_id]", "")
            positions.append(pos)
        i += 1
    data["positions"] = positions
    if not data["client_id"]:
        errors.append("Bitte einen Kunden wählen.")
    return data, errors


# ── Routes: expenses ──────────────────────────────────────────────────────────

EXPENSE_CATS = [
    "Software", "Hardware", "Büromaterial", "Reise & Unterkunft",
    "Marketing", "Fremdleistungen", "Materialien", "Telekommunikation",
    "Versicherung", "Fortbildung", "Sonstiges",
]


def expense_state(e):
    """billed: on an invoice; open: a client's cost not yet billed; own: business cost."""
    if e.get("invoice_id"):
        return "billed"
    return "open" if e.get("client_id") else "own"


@app.route("/expenses")
def expenses_list():
    expenses = all_expenses()
    clients  = all_clients()
    names    = {c["id"]: c.get("name", "") for c in clients if "id" in c}
    years    = sorted({e["date"][:4] for e in expenses if e.get("date")}, reverse=True)

    f = {k: request.args.get(k, "") for k in ("year", "category", "state", "client_id")}
    if f["year"]:
        expenses = [e for e in expenses if e.get("date", "").startswith(f["year"])]
    if f["category"]:
        expenses = [e for e in expenses if (e.get("category") or "Sonstiges") == f["category"]]
    if f["client_id"]:
        expenses = [e for e in expenses if e.get("client_id") == f["client_id"]]
    # State counts reflect the other filters, so the chips show what's there
    state_counts = Counter(expense_state(e) for e in expenses)
    if f["state"]:
        expenses = [e for e in expenses if expense_state(e) == f["state"]]

    for e in expenses:
        e["_state"]  = expense_state(e)
        e["_client"] = names.get(e.get("client_id", ""), "")
    by_cat = Counter()
    for e in expenses:
        by_cat[e.get("category") or "Sonstiges"] += float(e.get("amount") or 0)

    return render_template("expenses/list.html", expenses=expenses, years=years,
                           filters=f, state_counts=state_counts, clients=clients,
                           by_category=by_cat.most_common(), categories=EXPENSE_CATS,
                           total=sum(by_cat.values()))


@app.route("/expenses/<eid>")
def expense_detail(eid):
    exp = get_expense(eid)
    if not exp:
        abort(404)
    exp.setdefault("id", eid)   # Paperless imports may omit id from YAML
    receipt_url = None
    receipt_is_pdf = False
    if exp.get("receipt_file"):
        receipt_url    = url_for("uploaded_file", filename=exp["receipt_file"])
        receipt_is_pdf = exp["receipt_file"].lower().endswith(".pdf")
    elif exp.get("paperless_id"):
        # Proxy through our own route so auth is handled server-side
        receipt_url    = url_for("expense_paperless_receipt", eid=eid)
        receipt_is_pdf = True
    return render_template("expenses/detail.html", expense=exp,
                           receipt_url=receipt_url, receipt_is_pdf=receipt_is_pdf)


@app.route("/expenses/<eid>/paperless-receipt")
def expense_paperless_receipt(eid):
    """Proxy the Paperless document download so the browser can display it."""
    cfg = load_config()
    exp = get_expense(eid)
    if not exp or not exp.get("paperless_id"):
        abort(404)
    raw, mime = fetch_paperless_receipt_bytes(exp, cfg)
    if not raw:
        abort(502)  # Paperless unreachable or disabled
    return send_file(BytesIO(raw), mimetype=mime)


def _default_category(expenses):
    """Most common category among the last 10 expenses (ties: the most recent)."""
    recent = Counter(e["category"] for e in expenses[:10] if e.get("category") in EXPENSE_CATS)
    return recent.most_common(1)[0][0] if recent else "Sonstiges"


def _render_expense_form(exp, edit, status=200):
    expenses = all_expenses()
    vendors  = sorted({e["vendor"] for e in expenses if e.get("vendor")}, key=str.casefold)
    return render_template("expenses/form.html", expense=exp, edit=edit,
                           categories=EXPENSE_CATS, vendors=vendors,
                           clients=all_clients(), projects=all_projects()), status


def _parse_expense_form(form, base):
    """Merge the form into base (so fields the form lacks survive). Returns (data, errors)."""
    data, errors = {**base, **form.to_dict()}, []
    try:
        data["date"] = _parse_date_input(data.get("date", ""), "Datum")
    except FormError as e:
        errors.append(str(e))
    # An expense booked to a project belongs to that project's client
    if data.get("project_id") and not data.get("client_id"):
        data["client_id"] = (get_project(data["project_id"]) or {}).get("client_id", "")
    return data, errors


def _save_receipt_upload(eid, data):
    f = request.files.get("receipt")
    if not (f and f.filename):
        return
    name = f"receipt-{eid}{Path(f.filename).suffix.lower()}"
    UPLOADS_DIR.mkdir(exist_ok=True)
    f.save(UPLOADS_DIR / name)
    old = data.get("receipt_file")
    if old and old != name:
        _remove_receipt(eid, old)
    data["receipt_file"] = name


def _remove_receipt(eid, name):
    # Only ever delete files this expense owns (receipt-<eid>.*)
    if name and name.startswith(f"receipt-{eid}"):
        (UPLOADS_DIR / name).unlink(missing_ok=True)


def _sync_expense_to_invoice(old, new):
    """Keep the Auslagenersatz line on a draft invoice in step with the expense amount."""
    iid = new.get("invoice_id")
    if not iid or float(old.get("amount") or 0) == float(new.get("amount") or 0):
        return
    inv = get_invoice(iid)
    if not inv:
        return
    if inv.get("status") != "draft":
        flash(f"Rechnung {iid} ist bereits {tpl_status(inv.get('status'))} – "
              "der Betrag dort wurde nicht geändert.", "warning")
        return
    for p in inv.get("positions") or []:
        if p.get("expense_id") == new["id"]:
            p["unit_price"] = float(new.get("amount") or 0)
    put_invoice(iid, inv)
    flash(f"Betrag auch in Rechnung {iid} aktualisiert.", "success")


@app.route("/expenses/new", methods=["GET", "POST"])
def expense_new():
    if request.method == "POST":
        eid = f"exp-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6]}"
        data, errors = _parse_expense_form(request.form, {"id": eid})
        if errors:
            for e in errors:
                flash(e, "error")
            return _render_expense_form(data, edit=False, status=400)
        _save_receipt_upload(eid, data)
        put_expense(eid, data)
        flash("Ausgabe gespeichert.", "success")
        return redirect(url_for("expenses_list"))

    project_id = request.args.get("project_id", "")
    client_id  = request.args.get("client_id", "")
    if project_id and not client_id:
        client_id = (get_project(project_id) or {}).get("client_id", "")
    return _render_expense_form({
        "date":       datetime.now().strftime("%Y-%m-%d"),
        "client_id":  client_id,
        "project_id": project_id,
        "category":   _default_category(all_expenses()),
    }, edit=False)


@app.route("/expenses/<eid>/edit", methods=["GET", "POST"])
def expense_edit(eid):
    exp = get_expense(eid)
    if not exp:
        abort(404)
    if request.method == "POST":
        data, errors = _parse_expense_form(request.form, exp)
        data["id"] = eid
        if errors:
            for e in errors:
                flash(e, "error")
            return _render_expense_form(data, edit=True, status=400)
        _save_receipt_upload(eid, data)
        put_expense(eid, data)
        flash("Ausgabe aktualisiert.", "success")
        _sync_expense_to_invoice(exp, data)
        return redirect(url_for("expense_detail", eid=eid))
    return _render_expense_form(exp, edit=True)


@app.route("/expenses/<eid>/delete", methods=["POST"])
def expense_delete(eid):
    exp = get_expense(eid)
    if not exp:
        abort(404)
    iid = exp.get("invoice_id")
    inv = get_invoice(iid) if iid else None
    if inv and inv.get("status") != "draft":
        flash(f"Diese Ausgabe ist in Rechnung {iid} ({tpl_status(inv.get('status'))}) "
              "abgerechnet und kann nicht gelöscht werden.", "error")
        return redirect(url_for("expense_detail", eid=eid))
    if inv:
        inv["positions"] = [p for p in inv.get("positions") or [] if p.get("expense_id") != eid]
        put_invoice(iid, inv)
    _remove_receipt(eid, exp.get("receipt_file"))
    del_expense(eid)
    flash("Ausgabe gelöscht." + (f" Position aus Rechnung {iid} entfernt." if inv else ""), "success")
    return redirect(url_for("expenses_list"))


# ── Routes: projects ─────────────────────────────────────────────────────────

@app.route("/projects")
def projects_list():
    cfg = load_config()
    clients_map = {c["id"]: c for c in all_clients() if "id" in c}
    projects = all_projects()
    for p in projects:
        p["_client"] = clients_map.get(p.get("client_id", ""), {})
    return render_template("projects/list.html", projects=projects)


def _parse_project_form(form, base):
    data, errors = {**base, **form.to_dict()}, []
    for k, label in (("start_date", "Startdatum"), ("end_date", "Enddatum")):
        try:
            data[k] = _parse_date_input(data.get(k, ""), label)
        except FormError as e:
            errors.append(str(e))
    return data, errors


def _render_project_form(project, edit, errors=()):
    for e in errors:
        flash(e, "error")
    return render_template("projects/form.html", project=project,
                           clients=all_clients(), edit=edit), 400 if errors else 200


@app.route("/projects/new", methods=["GET", "POST"])
def project_new():
    if request.method == "POST":
        pid = f"proj-{uuid.uuid4().hex[:8]}"
        data, errors = _parse_project_form(
            request.form, {"id": pid, "created": datetime.now().strftime("%Y-%m-%d")})
        if errors:
            return _render_project_form(data, edit=False, errors=errors)
        put_project(pid, data)
        flash("Projekt gespeichert.", "success")
        return redirect(url_for("project_detail", pid=pid))
    return _render_project_form({"status": "active",
                                 "start_date": datetime.now().strftime("%Y-%m-%d"),
                                 "client_id": request.args.get("client_id", "")}, edit=False)


@app.route("/projects/<pid>")
def project_detail(pid):
    project = get_project(pid)
    if not project:
        abort(404)
    cfg      = load_config()
    client   = get_client(project.get("client_id", "")) or {}
    invoices = decorate_invoices([i for i in all_invoices() if i.get("project_id") == pid], cfg)
    expenses = [e for e in all_expenses() if e.get("project_id") == pid]
    for e in expenses:
        e["_state"] = expense_state(e)

    # Only issued invoices count: quotes, drafts and cancelled ones aren't billed
    billed         = [i for i in invoices if is_billed(i)]
    total_invoiced = sum(i["_totals"]["total"] for i in billed)
    billed_fees    = sum(i["_totals"]["services"] for i in billed)  # budget is for fees, not reimbursements
    total_expenses = sum(float(e.get("amount") or 0) for e in expenses)
    unbilled       = [e for e in expenses if e["_state"] == "open"]
    budget         = float(project.get("budget") or 0)
    budget_pct     = min(round(billed_fees / budget * 100), 100) if budget else None
    return render_template("projects/detail.html", project=project, client=client,
                           invoices=invoices, expenses=expenses,
                           total_invoiced=total_invoiced,
                           total_expenses=total_expenses,
                           billed_fees=billed_fees,
                           unbilled=unbilled,
                           unbilled_total=sum(float(e.get("amount") or 0) for e in unbilled),
                           budget=budget,
                           budget_pct=budget_pct)


@app.route("/projects/<pid>/edit", methods=["GET", "POST"])
def project_edit(pid):
    project = get_project(pid)
    if not project:
        abort(404)
    if request.method == "POST":
        data, errors = _parse_project_form(request.form, project)
        data["id"] = pid
        if errors:
            return _render_project_form(data, edit=True, errors=errors)
        put_project(pid, data)
        flash("Projekt aktualisiert.", "success")
        return redirect(url_for("project_detail", pid=pid))
    return _render_project_form(project, edit=True)


@app.route("/projects/<pid>/delete", methods=["POST"])
def project_delete(pid):
    del_project(pid)
    flash("Projekt gelöscht.", "success")
    return redirect(url_for("projects_list"))


# ── Routes: Paperless-ngx ─────────────────────────────────────────────────────

@app.route("/paperless")
def paperless_browser():
    cfg = load_config()
    if not cfg["paperless"]["enabled"]:
        flash("Paperless-ngx ist nicht aktiviert. Bitte in den Einstellungen konfigurieren.", "warning")
        return redirect(url_for("settings"))
    docs = error = None
    correspondents = {}
    q     = request.args.get("q", "")
    page  = int(request.args.get("page", 1))
    try:
        pl   = Paperless(cfg["paperless"]["base_url"], cfg["paperless"]["token"])
        docs = pl.documents(page=page, q=q or None)
        correspondents = pl.correspondents()
    except Exception as e:
        error = str(e)
    imported = {e["paperless_id"]: e["id"] for e in all_expenses() if e.get("paperless_id")}
    return render_template("paperless.html", docs=docs, error=error, q=q, page=page,
                           correspondents=correspondents, imported=imported)


@app.route("/paperless/import/<int:did>", methods=["POST"])
def paperless_import(did):
    existing = next((e for e in all_expenses() if e.get("paperless_id") == did), None)
    if existing:
        # Re-importing used to overwrite the expense, wiping its amount and invoice link
        flash("Dieses Dokument ist bereits als Ausgabe erfasst.", "warning")
        return redirect(url_for("expense_detail", eid=existing["id"]))

    cfg = load_config()
    eid = f"exp-pl-{did}"
    try:
        pl  = Paperless(cfg["paperless"]["base_url"], cfg["paperless"]["token"])
        doc = pl.document(did)
        vendor = ""
        if doc.get("correspondent"):
            try:
                vendor = pl.correspondents().get(doc["correspondent"], "")
            except Exception:
                pass
        expense = {
            "id":           eid,
            "description":  doc.get("title", f"Paperless #{did}"),
            "date":         (doc.get("created") or datetime.now().strftime("%Y-%m-%d"))[:10],
            "amount":       "",
            "category":     _default_category(all_expenses()),
            "vendor":       vendor,
            "paperless_id": did,
            "notes":        f"Import aus Paperless Dokument #{did}",
        }
        put_expense(eid, expense)

        # Cache the receipt locally so it stays available if Paperless is unreachable
        try:
            r = req_lib.get(pl.download(did), headers=pl.h, timeout=30)
            r.raise_for_status()
            mime = r.headers.get("Content-Type", "application/pdf").split(";")[0].strip()
            fname = f"receipt-{eid}{'.pdf' if 'pdf' in mime else '.jpg'}"
            (UPLOADS_DIR / fname).write_bytes(r.content)
            expense["receipt_file"] = fname
            put_expense(eid, expense)
        except Exception as dl_err:
            app.logger.warning("Could not cache Paperless receipt for %s: %s", eid, dl_err)
    except Exception as e:
        flash(f"Import fehlgeschlagen: {e}", "error")
        return redirect(url_for("paperless_browser"))

    # Straight to the form: the amount is the one thing Paperless can't supply
    flash("Aus Paperless importiert – bitte Betrag ergänzen.", "success")
    return redirect(url_for("expense_edit", eid=eid))


# ── Routes: settings ─────────────────────────────────────────────────────────

@app.route("/settings", methods=["GET", "POST"])
def settings():
    cfg = load_config()
    if request.method == "POST":
        f = request.form
        new_cfg = {
            "business": {
                "name":          f.get("b_name", ""),
                "legal_name":    f.get("b_legal_name", ""),
                "profession":    f.get("b_profession", ""),
                "address_line1": f.get("b_addr1", ""),
                "address_line2": f.get("b_addr2", ""),
                "country":       f.get("b_country", "Deutschland"),
                "email":         f.get("b_email", ""),
                "phone":         f.get("b_phone", ""),
                "website":       f.get("b_website", ""),
            },
            "tax": {
                "mode":              f.get("t_mode", "kleinunternehmer"),
                "steuernummer":      f.get("t_steuernr", ""),
                "ust_idnr":          f.get("t_ust_idnr", ""),
                "mwst_rate":         int(f.get("t_mwst", 19) or 19),
                "mwst_rate_reduced": int(f.get("t_mwst7", 7) or 7),
            },
            "invoice": {
                "number_format":      f.get("i_numfmt", "{YEAR}-{SEQ:04d}"),
                "payment_terms_days": int(f.get("i_terms", 14) or 14),
                "currency":           f.get("i_currency", "EUR"),
                "currency_symbol":    f.get("i_symbol", "€"),
                "bank_name":          f.get("i_bank", ""),
                "iban":               f.get("i_iban", ""),
                "bic":                f.get("i_bic", ""),
                "default_notes":      f.get("i_notes", ""),
            },
            "paperless": {
                "enabled":  f.get("pl_enabled") == "on",
                "base_url": f.get("pl_url", ""),
                "token":    f.get("pl_token", ""),
            },
            "design": {
                "accent_color": f.get("d_color", "#1400FF"),
                "logo_path":    cfg["design"].get("logo_path", ""),
            },
        }
        logo_file = request.files.get("logo_file")
        if logo_file and logo_file.filename:
            UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
            ext = Path(logo_file.filename).suffix.lower()
            logo_file.save(UPLOADS_DIR / f"logo{ext}")
            new_cfg["design"]["logo_path"] = f"logo{ext}"

        save_config(new_cfg)
        flash("Einstellungen gespeichert.", "success")
        return redirect(url_for("settings"))
    return render_template("settings.html", cfg=cfg)


# ── JSON API ──────────────────────────────────────────────────────────────────

@app.route("/api/clients")
def api_clients():
    return jsonify(all_clients())


@app.route("/api/totals", methods=["POST"])
def api_totals():
    cfg = load_config()
    body = request.get_json(force=True) or {}
    t = calc_totals({"positions": body.get("items", []),
                     "mwst_rate": body.get("mwst_rate")}, cfg)
    sym = cfg["invoice"]["currency_symbol"]
    return jsonify({
        **t,
        "subtotal_fmt": fmt_eur(t["subtotal"], sym),
        "mwst_fmt":     fmt_eur(t["mwst"], sym),
        "total_fmt":    fmt_eur(t["total"], sym),
    })


@app.route("/api/next-number")
def api_next_number():
    return jsonify({"id": peek_number(load_config(), request.args.get("type", "invoice"))})


@app.route("/api/invoice-defaults")
def api_invoice_defaults():
    return jsonify(invoice_defaults(load_config(),
                                    request.args.get("client_id", ""),
                                    request.args.get("project_id", "")))


if __name__ == "__main__":
    host  = os.environ.get("BUERO_HOST", os.environ.get("HOST", "0.0.0.0"))
    port  = int(os.environ.get("BUERO_PORT", os.environ.get("PORT", 5055)))
    debug = os.environ.get("DEBUG", "0") == "1"
    print(f"Büro running at http://{host}:{port}")
    app.run(host=host, port=port, debug=debug)
