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
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        yaml.dump(cfg, f, allow_unicode=True, default_flow_style=False)


# ── YAML data layer ───────────────────────────────────────────────────────────

def _load(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _save(path, data):
    with open(path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)


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
def all_expenses():
    exp = [_load(p) for p in EXPENSES_DIR.glob("*.yaml")]
    return sorted(exp, key=lambda e: e.get("date", ""), reverse=True)


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

def next_number(cfg, doc_type="invoice"):
    year = datetime.now().year
    prefix = {"quote": "A", "invoice": "", "receipt": "Q"}.get(doc_type, "")
    all_inv = all_invoices()
    year_docs = [
        i for i in all_inv
        if i.get("date", "").startswith(str(year))
        and i.get("type", "invoice") == doc_type
    ]
    seq = len(year_docs) + 1
    fmt = cfg["invoice"]["number_format"]
    raw = fmt.format(YEAR=year, SEQ=seq)
    return f"{prefix}{raw}" if prefix else raw


# ── Calculations ──────────────────────────────────────────────────────────────

def calc_totals(invoice, cfg):
    # "positions" is the canonical key; fall back to "items" for old YAML files
    items = invoice.get("positions") or invoice.get("items") or []
    subtotal = sum(
        float(i.get("quantity") or 0) * float(i.get("unit_price") or 0)
        for i in items
    )
    if cfg["tax"]["mode"] == "regelbesteuerung":
        rate = float(invoice.get("mwst_rate") or cfg["tax"]["mwst_rate"])
        mwst = round(subtotal * rate / 100, 2)
        total = round(subtotal + mwst, 2)
    else:
        rate, mwst = 0.0, 0.0
        total = round(subtotal, 2)
    return {"subtotal": round(subtotal, 2), "mwst_rate": rate,
            "mwst": mwst, "total": total}


def fmt_eur(v, sym="€"):
    try:
        s = f"{float(v):,.2f}"
        s = s.replace(",", "X").replace(".", ",").replace("X", ".")
        return f"{sym} {s}"
    except Exception:
        return str(v)


# ── Dashboard ─────────────────────────────────────────────────────────────────

def dashboard_stats(cfg):
    invoices = all_invoices()
    expenses = all_expenses()
    year = str(datetime.now().year)
    today = date.today()

    ytd_revenue = ytd_expenses = outstanding = 0.0
    overdue = unpaid = 0

    clients_map = {c["id"]: c for c in all_clients() if "id" in c}

    for inv in invoices:
        t = calc_totals(inv, cfg)
        status = inv.get("status", "draft")
        inv_date = inv.get("date", "")
        due_raw = inv.get("due_date", "")

        if status == "sent" and due_raw:
            try:
                if datetime.strptime(due_raw, "%Y-%m-%d").date() < today:
                    inv["status"] = status = "overdue"
            except ValueError:
                pass

        if inv.get("type", "invoice") in ("invoice",):
            if status == "paid" and inv_date.startswith(year):
                ytd_revenue += t["total"]
            if status in ("sent", "overdue"):
                outstanding += t["total"]
                unpaid += 1
            if status == "overdue":
                overdue += 1

        inv["_client"] = clients_map.get(inv.get("client_id", ""), {})
        inv["_totals"] = t

    for exp in expenses:
        if exp.get("date", "").startswith(year):
            ytd_expenses += float(exp.get("amount") or 0)

    return {
        "ytd_revenue": ytd_revenue,
        "ytd_expenses": ytd_expenses,
        "outstanding": outstanding,
        "overdue": overdue,
        "unpaid": unpaid,
        "recent": invoices[:8],
        "client_count": len(all_clients()),
        "invoice_count": len(invoices),
        "year": year,
    }


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


# ── PDF generation ────────────────────────────────────────────────────────────

def make_pdf(invoice, client, cfg, project=None):
    from jinja2 import Environment, FileSystemLoader
    totals   = calc_totals(invoice, cfg)
    logo_b64 = load_logo_b64(cfg)
    epc_qr   = make_epc_qr(cfg, invoice, totals) if invoice.get("type") == "invoice" else None
    inv_qr   = make_invoice_qr(invoice.get("id", ""))

    env = Environment(loader=FileSystemLoader(str(APP_DIR / "pdf_templates")))
    env.filters["eur"] = lambda v: fmt_eur(float(v or 0), cfg["invoice"]["currency_symbol"])
    env.filters["date_de"] = _date_de

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
    )

    if WEASYPRINT:
        pdf_bytes = WPHtml(string=html, base_url=str(APP_DIR)).write_pdf()
        return pdf_bytes, "application/pdf"
    else:
        return html.encode("utf-8"), "text/html"


# ── Template helpers ──────────────────────────────────────────────────────────

def _parse_date_input(s):
    """Accept DD.MM.YYYY or YYYY-MM-DD, normalise to YYYY-MM-DD for storage."""
    if not s:
        return ""
    s = s.strip()
    if len(s) == 10 and s[2] == "." and s[5] == ".":
        try:
            return datetime.strptime(s, "%d.%m.%Y").strftime("%Y-%m-%d")
        except ValueError:
            pass
    return s


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
    return {"cfg": load_config()}


# ── User-uploaded files (logo, receipts) served from writable DATA_DIR ───────

@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    from flask import send_from_directory
    return send_from_directory(UPLOADS_DIR, filename)


# ── Routes: dashboard ─────────────────────────────────────────────────────────

@app.route("/")
def dashboard():
    cfg = load_config()
    stats = dashboard_stats(cfg)
    return render_template("dashboard.html", stats=stats)


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
    inv = [i for i in all_invoices() if i.get("client_id") == cid]
    return render_template("clients/detail.html", client=client, invoices=inv)


@app.route("/clients/<cid>/edit", methods=["GET", "POST"])
def client_edit(cid):
    client = get_client(cid)
    if not client:
        abort(404)
    if request.method == "POST":
        data = request.form.to_dict()
        data["id"] = cid
        put_client(cid, data)
        flash("Kunde aktualisiert.", "success")
        return redirect(url_for("client_detail", cid=cid))
    return render_template("clients/form.html", client=client, edit=True)


@app.route("/clients/<cid>/delete", methods=["POST"])
def client_delete(cid):
    p = CLIENTS_DIR / f"{_safe(cid)}.yaml"
    if p.exists():
        p.unlink()
    flash("Kunde gelöscht.", "success")
    return redirect(url_for("clients_list"))


# ── Routes: invoices ──────────────────────────────────────────────────────────

@app.route("/invoices")
def invoices_list():
    cfg = load_config()
    clients_map = {c["id"]: c for c in all_clients() if "id" in c}
    today = date.today()
    invoices = []
    for inv in all_invoices():
        inv["_client"] = clients_map.get(inv.get("client_id", ""), {})
        inv["_totals"] = calc_totals(inv, cfg)
        if inv.get("status") == "sent" and inv.get("due_date"):
            try:
                if datetime.strptime(inv["due_date"], "%Y-%m-%d").date() < today:
                    inv["status"] = "overdue"
            except ValueError:
                pass
        invoices.append(inv)
    status_filter = request.args.get("status", "")
    if status_filter:
        invoices = [i for i in invoices if i.get("status") == status_filter]
    return render_template("invoices/list.html", invoices=invoices,
                           status_filter=status_filter)


@app.route("/invoices/new", methods=["GET", "POST"])
def invoice_new():
    cfg = load_config()
    clients = all_clients()
    projects = all_projects()
    doc_type = request.args.get("type", "invoice")

    if request.method == "POST":
        data = _parse_invoice_form(request.form, cfg)
        put_invoice(data["id"], data)
        flash(f'{tpl_type(data["type"])} {data["id"]} gespeichert.', "success")
        return redirect(url_for("invoice_detail", iid=data["id"]))

    today_s = datetime.now().strftime("%Y-%m-%d")
    due_s   = (datetime.now() + timedelta(days=cfg["invoice"]["payment_terms_days"])).strftime("%Y-%m-%d")
    client_id  = request.args.get("client_id", "")
    project_id = request.args.get("project_id", "")
    inv = {
        "id":                 next_number(cfg, doc_type),
        "type":               doc_type,
        "status":             "draft",
        "date":               today_s,
        "due_date":           due_s,
        "service_date":       today_s,
        "service_period_end": "",
        "client_id":          client_id,
        "project_id":         project_id,
        "positions": [{"description": "", "quantity": 1, "unit": "Std.", "unit_price": ""}],
        "notes":              cfg["invoice"]["default_notes"],
        "mwst_rate":          cfg["tax"]["mwst_rate"],
    }
    return render_template("invoices/form.html", invoice=inv, clients=clients,
                           projects=projects, edit=False)


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
    return render_template("invoices/detail.html", invoice=inv, client=client,
                           project=project, totals=totals,
                           kleinunternehmer=cfg["tax"]["mode"] == "kleinunternehmer")


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
        data = _parse_invoice_form(request.form, cfg)
        data["id"] = iid
        put_invoice(iid, data)
        flash("Rechnung aktualisiert.", "success")
        return redirect(url_for("invoice_detail", iid=iid))
    return render_template("invoices/form.html", invoice=inv,
                           clients=all_clients(), projects=all_projects(), edit=True)


@app.route("/invoices/<path:iid>/pdf")
def invoice_pdf(iid):
    cfg = load_config()
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    client  = get_client(inv.get("client_id", "")) or {}
    project = get_project(inv.get("project_id", "")) if inv.get("project_id") else None
    data, mimetype = make_pdf(inv, client, cfg, project=project)
    buf = BytesIO(data)
    ext = "pdf" if WEASYPRINT else "html"
    fname = f"{inv.get('type','invoice')}-{_safe(iid)}.{ext}"
    return send_file(buf, mimetype=mimetype, download_name=fname,
                     as_attachment=(ext == "pdf"))


@app.route("/invoices/<path:iid>/status", methods=["POST"])
def invoice_status(iid):
    inv = get_invoice(iid)
    if not inv:
        abort(404)
    new = request.form.get("status", "")
    if new in ("draft", "sent", "paid", "cancelled"):
        inv["status"] = new
        if new == "paid":
            inv["paid_date"] = datetime.now().strftime("%Y-%m-%d")
    put_invoice(iid, inv)
    flash(f"Status: {tpl_status(new)}", "success")
    return redirect(url_for("invoice_detail", iid=iid))


@app.route("/invoices/<path:iid>/delete", methods=["POST"])
def invoice_delete(iid):
    del_invoice(iid)
    flash("Gelöscht.", "success")
    return redirect(url_for("invoices_list"))


@app.route("/invoices/<path:iid>/to-invoice", methods=["POST"])
def quote_to_invoice(iid):
    cfg = load_config()
    quote = get_invoice(iid)
    if not quote:
        abort(404)
    new_id = next_number(cfg, "invoice")
    inv = deepcopy(quote)
    inv.update({
        "id": new_id,
        "type": "invoice",
        "status": "draft",
        "date": datetime.now().strftime("%Y-%m-%d"),
        "due_date": (datetime.now() + timedelta(days=cfg["invoice"]["payment_terms_days"])).strftime("%Y-%m-%d"),
        "quote_ref": iid,
    })
    put_invoice(new_id, inv)
    flash(f"Angebot in Rechnung {new_id} umgewandelt.", "success")
    return redirect(url_for("invoice_detail", iid=new_id))


def _parse_invoice_form(form, cfg):
    data = {
        "id":                 form.get("id") or next_number(cfg, form.get("type", "invoice")),
        "type":               form.get("type", "invoice"),
        "status":             form.get("status", "draft"),
        "date":               _parse_date_input(form.get("date", "")),
        "due_date":           _parse_date_input(form.get("due_date", "")),
        "service_date":       _parse_date_input(form.get("service_date", "")),
        "service_period_end": _parse_date_input(form.get("service_period_end", "")),
        "client_id":          form.get("client_id", ""),
        "project_id":         form.get("project_id", ""),
        "notes":              form.get("notes", ""),
        "payment_ref":        form.get("payment_ref", ""),
        "mwst_rate":          float(form.get("mwst_rate") or cfg["tax"]["mwst_rate"]),
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
        positions.append({
            "description": desc,
            "quantity":    qty,
            "unit":        form.get(f"positions[{i}][unit]", "Std."),
            "unit_price":  price,
        })
        i += 1
    data["positions"] = positions
    return data


# ── Routes: expenses ──────────────────────────────────────────────────────────

EXPENSE_CATS = [
    "Software", "Hardware", "Büromaterial", "Reise & Unterkunft",
    "Marketing", "Fremdleistungen", "Materialien", "Telekommunikation",
    "Versicherung", "Fortbildung", "Sonstiges",
]


@app.route("/expenses")
def expenses_list():
    return render_template("expenses/list.html", expenses=all_expenses())


@app.route("/expenses/new", methods=["GET", "POST"])
def expense_new():
    if request.method == "POST":
        data = request.form.to_dict()
        data["date"] = _parse_date_input(data.get("date", ""))
        eid = f"exp-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6]}"
        data["id"] = eid
        f = request.files.get("receipt")
        if f and f.filename:
            ext = Path(f.filename).suffix.lower()
            UPLOADS_DIR.mkdir(exist_ok=True)
            f.save(UPLOADS_DIR / f"receipt-{eid}{ext}")
            data["receipt_file"] = f"{eid}{ext}"
        put_expense(eid, data)
        flash("Ausgabe gespeichert.", "success")
        return redirect(url_for("expenses_list"))
    return render_template("expenses/form.html", expense={
        "date":       datetime.now().strftime("%Y-%m-%d"),
        "client_id":  request.args.get("client_id", ""),
        "project_id": request.args.get("project_id", ""),
    }, categories=EXPENSE_CATS, clients=all_clients(), projects=all_projects())


@app.route("/expenses/<eid>/delete", methods=["POST"])
def expense_delete(eid):
    del_expense(eid)
    flash("Ausgabe gelöscht.", "success")
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


@app.route("/projects/new", methods=["GET", "POST"])
def project_new():
    if request.method == "POST":
        data = request.form.to_dict()
        data["start_date"] = _parse_date_input(data.get("start_date", ""))
        data["end_date"]   = _parse_date_input(data.get("end_date", ""))
        pid = f"proj-{uuid.uuid4().hex[:8]}"
        data["id"]      = pid
        data["created"] = datetime.now().strftime("%Y-%m-%d")
        put_project(pid, data)
        flash("Projekt gespeichert.", "success")
        return redirect(url_for("project_detail", pid=pid))
    return render_template("projects/form.html",
                           project={"status": "active",
                                    "client_id": request.args.get("client_id", "")},
                           clients=all_clients(), edit=False)


@app.route("/projects/<pid>")
def project_detail(pid):
    project = get_project(pid)
    if not project:
        abort(404)
    cfg         = load_config()
    client      = get_client(project.get("client_id", "")) or {}
    clients_map = {c["id"]: c for c in all_clients() if "id" in c}
    invoices    = []
    expenses    = []
    for inv in all_invoices():
        if inv.get("project_id") == pid:
            inv["_client"] = clients_map.get(inv.get("client_id", ""), {})
            inv["_totals"] = calc_totals(inv, cfg)
            invoices.append(inv)
    for exp in all_expenses():
        if exp.get("project_id") == pid:
            exp["_client"] = clients_map.get(exp.get("client_id", ""), {})
            expenses.append(exp)
    total_invoiced = sum(i["_totals"]["total"] for i in invoices)
    total_expenses = sum(float(e.get("amount") or 0) for e in expenses)
    budget         = float(project.get("budget") or 0)
    budget_pct     = min(round(total_invoiced / budget * 100), 100) if budget else None
    return render_template("projects/detail.html", project=project, client=client,
                           invoices=invoices, expenses=expenses,
                           total_invoiced=total_invoiced,
                           total_expenses=total_expenses,
                           budget=budget,
                           budget_pct=budget_pct)


@app.route("/projects/<pid>/edit", methods=["GET", "POST"])
def project_edit(pid):
    project = get_project(pid)
    if not project:
        abort(404)
    if request.method == "POST":
        data = request.form.to_dict()
        data["start_date"] = _parse_date_input(data.get("start_date", ""))
        data["end_date"]   = _parse_date_input(data.get("end_date", ""))
        data["id"]      = pid
        data["created"] = project.get("created", "")
        put_project(pid, data)
        flash("Projekt aktualisiert.", "success")
        return redirect(url_for("project_detail", pid=pid))
    return render_template("projects/form.html", project=project,
                           clients=all_clients(), edit=True)


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
    q     = request.args.get("q", "")
    page  = int(request.args.get("page", 1))
    try:
        pl   = Paperless(cfg["paperless"]["base_url"], cfg["paperless"]["token"])
        docs = pl.documents(page=page, q=q or None)
    except Exception as e:
        error = str(e)
    return render_template("paperless.html", docs=docs, error=error, q=q, page=page)


@app.route("/paperless/import/<int:did>", methods=["POST"])
def paperless_import(did):
    cfg = load_config()
    try:
        pl  = Paperless(cfg["paperless"]["base_url"], cfg["paperless"]["token"])
        doc = pl.document(did)
        eid = f"exp-pl-{did}"
        expense = {
            "id": eid,
            "description": doc.get("title", f"Paperless #{did}"),
            "date": (doc.get("created") or datetime.now().strftime("%Y-%m-%d"))[:10],
            "amount": "",
            "category": "Sonstiges",
            "paperless_id": did,
            "paperless_url": f"{cfg['paperless']['base_url']}/documents/{did}/",
            "notes": f"Import aus Paperless Dokument #{did}",
        }
        put_expense(eid, expense)
        flash("Dokument als Ausgabe importiert. Bitte Betrag ergänzen.", "success")
    except Exception as e:
        flash(f"Import fehlgeschlagen: {e}", "error")
    return redirect(url_for("expenses_list"))


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
    items = body.get("items", [])
    subtotal = sum(float(i.get("quantity") or 0) * float(i.get("unit_price") or 0)
                   for i in items)
    mode = cfg["tax"]["mode"]
    rate = float(body.get("mwst_rate") or cfg["tax"]["mwst_rate"])
    if mode == "regelbesteuerung":
        mwst  = round(subtotal * rate / 100, 2)
        total = round(subtotal + mwst, 2)
    else:
        rate = mwst = 0.0
        total = round(subtotal, 2)
    sym = cfg["invoice"]["currency_symbol"]
    return jsonify({
        "subtotal": subtotal, "subtotal_fmt": fmt_eur(subtotal, sym),
        "mwst": mwst, "mwst_fmt": fmt_eur(mwst, sym), "mwst_rate": rate,
        "total": total, "total_fmt": fmt_eur(total, sym),
    })


if __name__ == "__main__":
    host  = os.environ.get("BUERO_HOST", os.environ.get("HOST", "0.0.0.0"))
    port  = int(os.environ.get("BUERO_PORT", os.environ.get("PORT", 5055)))
    debug = os.environ.get("DEBUG", "0") == "1"
    print(f"Büro running at http://{host}:{port}")
    app.run(host=host, port=port, debug=debug)
