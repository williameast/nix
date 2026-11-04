"""
Receipt processing for Paperless with the local models on orr.

For every document without the marker tag:
  1. OCR: scans and photos are re-read by a vision model (Tesseract struggles
     with thermal-paper receipts); PDFs with a real text layer keep theirs.
  2. Extraction: a text model fills in title, payee (→ correspondent), payer,
     date, total, VAT, invoice number, payment method, expense category and
     business/private, written back as Paperless metadata, custom fields and tags.
  3. Merge check: scans added minutes apart are compared; if they look like
     pages of one document, a merge is *suggested* (applied only on approval).

Every change is snapshotted first, so it can be undone from the Büro tab.
Everything runs through milo's wake-on-demand proxy; nothing leaves the house.
"""

import base64
import json
import re
import subprocess
import tempfile
import threading
from datetime import date, datetime, timedelta
from pathlib import Path

import requests

MARKER = "KI-verarbeitet"
REVIEW = "KI-prüfen"
BIZ_TAGS = {"geschäftlich": "geschäftlich", "privat": "privat"}
FIELDS = {   # Paperless custom field name → data type
    "Betrag": "monetary",
    "MwSt": "monetary",
    "Zahler": "string",
    "Rechnungsnummer": "string",
    "Zahlungsart": "string",
}
PAYMENT = ["Karte", "Bar", "Überweisung", "Lastschrift", "PayPal", "unbekannt"]
KINDS = ["receipt", "invoice", "credit_note", "contract", "letter", "other"]
MERGE_WINDOW = timedelta(minutes=15)
MAX_PAGES = 4          # vision OCR reads at most this many pages per document
REVIEW_BELOW = 70      # confidence under this gets the review tag
TIMEOUT = 900          # the first call may wait for orr to boot and load a model

OCR_PROMPT = (
    "Transkribiere den gesamten Text auf diesem Beleg exakt, Zeile für Zeile, in der "
    "Originalsprache. Übernimm Zahlen, Beträge, Datumsangaben, Steuernummern und "
    "Rechnungsnummern genau. Keine Erklärungen, keine Zusammenfassung, nur der Text."
)

EXTRACT_SYSTEM = """You file receipts and invoices for a freelancer in Berlin who runs a \
one-person studio ({business}) building props, set pieces and custom objects for film, music \
video and advertising productions. Documents are mostly German. Business and private receipts \
are mixed.

From the OCR text of one document, return:
- title: short German title, "<Händler/Aussteller> – <worum es geht>", e.g. "Bauhaus – Schrauben und Holz".
- kind: receipt (Kassenbon/Quittung), invoice (Rechnung), credit_note (Gutschrift), contract, letter, other.
- payee: who receives the money / issued the document (shop or company name, cleaned up, \
no legal-form noise unless needed to identify it). Reuse an existing correspondent name from the \
list when it is the same company.
- payer: who pays, i.e. the addressee of an invoice ("Rechnung an"). "" on a plain till receipt \
that names no customer.
- date: the document date as YYYY-MM-DD, "" if none is readable.
- total: the gross total actually paid or due, as a number; null if unreadable.
- vat: the VAT/MwSt amount as a number; null if not stated.
- currency: ISO code, usually EUR.
- invoice_number: the invoice/receipt number, "" if none.
- payment_method: one of {payment}.
- category: the best expense category from {categories}, or "" if it is not an expense.
- business: "geschäftlich", "privat" or "unklar" (materials, tools, hardware stores, model-making, \
software, transport for jobs → geschäftlich; groceries, restaurants, household → usually privat).
- confidence: 0-100, how sure you are of payee, date and total together. OCR garbage → low.
- note: one short German sentence on anything doubtful, else "".
Never invent numbers: if the total is not clearly readable, use null and lower the confidence."""

MERGE_SYSTEM = """Two scanned documents were added to the archive a few minutes apart. Decide whether \
document B is a further page of the same document as A (e.g. page 2 of the same invoice, the back \
of the same receipt, an attachment that belongs to it), or a separate document (e.g. another receipt \
scanned right after). Same shop alone is not enough; look for page numbers, continuing tables, \
carried-over totals, the same invoice number. Reason briefly in German."""


def _schema_extract(categories):
    return {
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "kind": {"type": "string", "enum": KINDS},
            "payee": {"type": "string"},
            "payer": {"type": "string"},
            "date": {"type": "string"},
            "total": {"type": ["number", "null"]},
            "vat": {"type": ["number", "null"]},
            "currency": {"type": "string"},
            "invoice_number": {"type": "string"},
            "payment_method": {"type": "string", "enum": PAYMENT},
            "category": {"type": "string", "enum": [*categories, ""]},
            "business": {"type": "string", "enum": ["geschäftlich", "privat", "unklar"]},
            "confidence": {"type": "integer"},
            "note": {"type": "string"},
        },
        "required": ["title", "kind", "payee", "payer", "date", "total", "vat", "currency",
                     "invoice_number", "payment_method", "category", "business", "confidence", "note"],
    }


MERGE_SCHEMA = {
    "type": "object",
    "properties": {
        "same_document": {"type": "boolean"},
        "confidence": {"type": "integer"},
        "reason": {"type": "string"},
    },
    "required": ["same_document", "confidence", "reason"],
}


def word_share(text):
    """Share of tokens that look like words; low means OCR garbage."""
    tokens = (text or "").split()
    if not tokens:
        return 0.0
    return sum(1 for t in tokens if re.search(r"[A-Za-zÄÖÜäöüß]{3,}", t)) / len(tokens)


def needs_vision(doc):
    name = (doc.get("original_file_name") or "").lower()
    content = doc.get("content") or ""
    return ((doc.get("mime_type") or "").startswith("image/") or name.startswith("scan-")
            or len(content) < 80 or word_share(content) < 0.5)


# ── Paperless ─────────────────────────────────────────────────────────────────

class PaperlessAPI:
    def __init__(self, base, token):
        self.base = base.rstrip("/")
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"Token {token}"

    def _url(self, path):
        # Paperless (Django) only redirects GETs to the trailing-slash URL; a POST
        # to e.g. /api/tags fails with a non-JSON response
        return f"{self.base}/api/{path.strip('/')}/"

    def get(self, path, **params):
        r = self.s.get(self._url(path), params=params, timeout=30)
        r.raise_for_status()
        return r.json()

    def post(self, path, data):
        r = self.s.post(self._url(path), json=data, timeout=60)
        r.raise_for_status()
        return r.json() if r.content else {}

    def patch(self, path, data):
        r = self.s.patch(self._url(path), json=data, timeout=60)
        r.raise_for_status()
        return r.json()

    def all(self, path, **params):
        out, page = [], 1
        while True:
            data = self.get(path, page=page, page_size=100, **params)
            out.extend(data.get("results", []))
            if not data.get("next"):
                return out
            page += 1

    def original(self, did):
        r = self.s.get(self._url(f"documents/{did}/download/"), params={"original": "true"}, timeout=120)
        r.raise_for_status()
        return r.content, r.headers.get("Content-Type", "").split(";")[0].strip()

    def thumb(self, did):
        r = self.s.get(self._url(f"documents/{did}/thumb/"), timeout=30)
        r.raise_for_status()
        return r.content, r.headers.get("Content-Type", "image/webp")


def _named(api, path, create):
    """{name: id} for tags/correspondents/custom_fields, creating missing ones in `create`."""
    have = {x["name"]: x["id"] for x in api.all(path)}
    for name, extra in create.items():
        if name not in have:
            have[name] = api.post(path, {"name": name, **extra})["id"]
    return have


def _match_correspondent(payee, correspondents):
    """Existing correspondent id for a payee name (case/punctuation-insensitive), else None."""
    norm = lambda s: re.sub(r"[^a-z0-9äöüß]+", "", s.lower())
    p = norm(payee)
    if not p:
        return None
    for name, cid in correspondents.items():
        n = norm(name)
        if n == p or (len(n) >= 5 and (n in p or p in n)):
            return cid
    return None


# ── Ollama ────────────────────────────────────────────────────────────────────

def _chat(url, model, messages, fmt=None, num_ctx=16384):
    body = {"model": model, "stream": False, "think": False, "messages": messages,
            "options": {"num_ctx": num_ctx, "temperature": 0.1}}
    if fmt:
        body["format"] = fmt
    try:
        r = requests.post(f"{url.rstrip('/')}/api/chat", json=body, timeout=TIMEOUT)
    except requests.ConnectionError:
        raise RuntimeError("Lokales Modell nicht erreichbar – läuft der orr-llm-proxy auf milo?")
    except requests.Timeout:
        raise RuntimeError("Lokales Modell antwortet nicht – orr aufgewacht?")
    if r.status_code == 503:
        raise RuntimeError("orr ist nicht rechtzeitig aufgewacht.")
    if not r.ok:
        raise RuntimeError(f"Ollama-Fehler {r.status_code}: {r.text[:200]}")
    return r.json()["message"]["content"]


def page_images(data, mime):
    """Original file → list of PNG bytes, one per page (at most MAX_PAGES)."""
    if mime.startswith("image/"):
        return [data]
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "doc.pdf"
        src.write_bytes(data)
        # 200 dpi keeps small thermal-paper print legible for the vision model
        subprocess.run(["pdftoppm", "-r", "200", "-png", "-l", str(MAX_PAGES), str(src),
                        str(Path(tmp) / "p")], check=True, capture_output=True, timeout=120)
        return [p.read_bytes() for p in sorted(Path(tmp).glob("p-*.png"))]


def vision_ocr(url, model, images):
    pages = []
    for i, img in enumerate(images, 1):
        text = _chat(url, model, [{"role": "user", "content": OCR_PROMPT,
                                   "images": [base64.b64encode(img).decode()]}], num_ctx=12288)
        pages.append(text.strip() if len(images) == 1 else f"--- Seite {i} ---\n{text.strip()}")
    return "\n\n".join(pages)


# ── State ─────────────────────────────────────────────────────────────────────

class Store:
    """JSON state in Büro's data dir: per-document results + snapshots, merge suggestions, runs."""

    def __init__(self, path):
        self.path = Path(path)
        self.lock = threading.Lock()

    def read(self):
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return {"docs": {}, "merges": [], "runs": []}

    def update(self, fn):
        with self.lock:
            data = self.read()
            result = fn(data)
            tmp = self.path.with_name(f".{self.path.name}.tmp")
            tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
            tmp.replace(self.path)
            return result


# ── The run ───────────────────────────────────────────────────────────────────

class Processor:
    def __init__(self, store, settings):
        """settings: base_url, token, ai_url, text_model, vision_model, business, categories."""
        self.store = store
        self.cfg = settings
        self.state = {"running": False, "phase": "", "done": 0, "total": 0, "error": "",
                      "finished": "", "summary": ""}

    def api(self):
        return PaperlessAPI(self.cfg["base_url"], self.cfg["token"])

    def start(self, trigger="manual", limit=200):
        if self.state["running"]:
            return False
        self.state.update(running=True, phase="Vorbereiten", done=0, total=0, error="", summary="")
        threading.Thread(target=self._run, args=(trigger, limit), daemon=True).start()
        return True

    def _progress(self, phase, done, total):
        self.state.update(phase=phase, done=done, total=total)

    def _run(self, trigger, limit):
        started = datetime.now()
        stats = {"processed": 0, "vision": 0, "review": 0, "errors": 0, "merges": 0}
        try:
            api = self.api()
            tags = _named(api, "tags", {MARKER: {"matching_algorithm": 0, "color": "#6b7280"},
                                        REVIEW: {"matching_algorithm": 0, "color": "#dc2626"},
                                        **{t: {"matching_algorithm": 0} for t in BIZ_TAGS},
                                        **{c: {"matching_algorithm": 0} for c in self.cfg["categories"]}})
            fields = _named(api, "custom_fields", {n: {"data_type": t} for n, t in FIELDS.items()})
            todo = api.all("documents", tags__id__none=tags[MARKER], ordering="added")[:limit]

            # 1. Vision OCR first, for all documents, so the vision model is loaded once
            ocr = [d for d in todo if needs_vision(d)]
            for i, doc in enumerate(ocr):
                self._progress("Texterkennung (Bild)", i, len(ocr))
                try:
                    text = vision_ocr(self.cfg["ai_url"], self.cfg["vision_model"],
                                      page_images(*api.original(doc["id"])))
                    if word_share(text) >= word_share(doc.get("content")) and len(text) > 20:
                        self._snapshot(doc)
                        api.patch(f"documents/{doc['id']}/", {"content": text})
                        doc["content"] = text
                        doc["_ocr"] = "vision"
                        stats["vision"] += 1
                except Exception as e:
                    self._record(doc["id"], status="error", error=f"OCR: {e}")
                    stats["errors"] += 1
                    if "nicht erreichbar" in str(e) or "aufgewacht" in str(e):
                        raise

            # 2. Extraction and write-back
            correspondents = {c["name"]: c["id"] for c in api.all("correspondents")}
            doc_types = {t["name"].lower(): t["id"] for t in api.all("document_types")}
            for i, doc in enumerate(todo):
                self._progress("Auswertung", i, len(todo))
                try:
                    ex = self._extract(doc, correspondents)
                    self._apply(api, doc, ex, tags, fields, correspondents, doc_types)
                    stats["processed"] += 1
                    stats["review"] += ex["_review"]
                except Exception as e:
                    self._record(doc["id"], status="error", error=str(e)[:300])
                    stats["errors"] += 1
                    if "nicht erreichbar" in str(e) or "aufgewacht" in str(e):
                        raise

            # 3. Merge suggestions among scans
            stats["merges"] = self._find_merges(api)
        except Exception as e:
            self.state["error"] = str(e)
        finally:
            summary = (f"{stats['processed']} ausgewertet, {stats['vision']} neu erkannt, "
                       f"{stats['review']} zu prüfen, {stats['merges']} Zusammenführungs-Vorschläge"
                       + (f", {stats['errors']} Fehler" if stats["errors"] else ""))
            def log_run(s):
                s["runs"].insert(0, {"start": started.isoformat(timespec="seconds"),
                                     "end": datetime.now().isoformat(timespec="seconds"),
                                     "trigger": trigger, "error": self.state["error"], **stats})
                del s["runs"][30:]
            self.store.update(log_run)
            self.state.update(running=False, phase="", summary=summary,
                              finished=datetime.now().strftime("%d.%m. %H:%M"))

    def _snapshot(self, doc):
        """Remember the document as it was before the first change, for undo."""
        def fn(s):
            entry = s["docs"].setdefault(str(doc["id"]), {})
            if "before" not in entry:
                entry["before"] = {k: doc.get(k) for k in
                                   ("title", "correspondent", "created", "document_type",
                                    "tags", "custom_fields", "content")}
        self.store.update(fn)

    def _record(self, did, **kw):
        self.store.update(lambda s: s["docs"].setdefault(str(did), {}).update(
            at=datetime.now().isoformat(timespec="seconds"), **kw))

    def _extract(self, doc, correspondents):
        system = EXTRACT_SYSTEM.format(business=self.cfg["business"] or "the studio",
                                       payment=", ".join(PAYMENT),
                                       categories=", ".join(self.cfg["categories"]))
        user = ("Existing correspondents: " + json.dumps(sorted(correspondents)[:300], ensure_ascii=False)
                + f"\n\nOriginal file name: {doc.get('original_file_name', '')}"
                + f"\n\nOCR text:\n{(doc.get('content') or '')[:12000]}")
        ex = json.loads(_chat(self.cfg["ai_url"], self.cfg["text_model"],
                              [{"role": "system", "content": system}, {"role": "user", "content": user}],
                              fmt=_schema_extract(self.cfg["categories"])))
        ex["confidence"] = max(0, min(100, int(ex.get("confidence") or 0)))
        ex["_review"] = bool(ex["confidence"] < REVIEW_BELOW or not ex.get("payee")
                             or ex.get("total") is None or ex.get("business") == "unklar")
        return ex

    def _apply(self, api, doc, ex, tags, fields, correspondents, doc_types):
        self._snapshot(doc)
        patch = {}
        if ex.get("title"):
            patch["title"] = ex["title"][:120]
        if ex.get("payee") and not doc.get("correspondent"):
            cid = _match_correspondent(ex["payee"], correspondents)
            if cid is None:
                cid = api.post("correspondents", {"name": ex["payee"][:120], "matching_algorithm": 0})["id"]
                correspondents[ex["payee"][:120]] = cid
            patch["correspondent"] = cid
        try:
            d = date.fromisoformat(ex.get("date") or "")
            if ex["confidence"] >= 60 and date(2000, 1, 1) <= d <= date.today() + timedelta(days=30):
                patch["created"] = d.isoformat()
        except ValueError:
            pass
        if not doc.get("document_type") and ex.get("kind") in ("receipt", "invoice", "credit_note"):
            patch["document_type"] = doc_types.get("expense")

        new_tags = set(doc.get("tags") or []) | {tags[MARKER]}
        if ex.get("category") in tags:
            new_tags.add(tags[ex["category"]])
        if ex.get("business") in BIZ_TAGS:
            new_tags.add(tags[ex["business"]])
        if ex["_review"]:
            new_tags.add(tags[REVIEW])
        patch["tags"] = sorted(new_tags)

        cur = ex.get("currency") or "EUR"
        values = {
            "Betrag": f"{cur}{ex['total']:.2f}" if isinstance(ex.get("total"), (int, float)) else None,
            "MwSt": f"{cur}{ex['vat']:.2f}" if isinstance(ex.get("vat"), (int, float)) else None,
            "Zahler": ex.get("payer") or None,
            "Rechnungsnummer": ex.get("invoice_number") or None,
            "Zahlungsart": ex.get("payment_method") if ex.get("payment_method") != "unbekannt" else None,
        }
        # PATCH replaces the whole custom field list: keep the document's other fields
        cf = {c["field"]: c.get("value") for c in doc.get("custom_fields") or []}
        for name, v in values.items():
            if v is not None:
                cf[fields[name]] = v
        patch["custom_fields"] = [{"field": f, "value": v} for f, v in cf.items()]

        api.patch(f"documents/{doc['id']}/", {k: v for k, v in patch.items() if v is not None})
        self._record(doc["id"], status="review" if ex["_review"] else "done",
                     ocr=doc.get("_ocr", "tesseract"), error="",
                     extracted={k: v for k, v in ex.items() if not k.startswith("_")})

    def _find_merges(self, api):
        scans = [d for d in api.all("documents", ordering="added")
                 if needs_vision(d) or (d.get("original_file_name") or "").startswith("scan-")]
        known = {(m["a"], m["b"]) for m in self.store.read()["merges"]}
        pairs = [(a, b) for a, b in zip(scans, scans[1:])
                 if (a["id"], b["id"]) not in known
                 and datetime.fromisoformat(b["added"]) - datetime.fromisoformat(a["added"]) <= MERGE_WINDOW]
        found = 0
        for i, (a, b) in enumerate(pairs):
            self._progress("Zusammengehörige Scans", i, len(pairs))
            user = (f"Document A (added {a['added'][:16]}, {a.get('page_count') or '?'} page(s)):\n"
                    f"{(a.get('content') or '')[:4000]}\n\n"
                    f"Document B (added {b['added'][:16]}, {b.get('page_count') or '?'} page(s)):\n"
                    f"{(b.get('content') or '')[:4000]}")
            res = json.loads(_chat(self.cfg["ai_url"], self.cfg["text_model"],
                                   [{"role": "system", "content": MERGE_SYSTEM},
                                    {"role": "user", "content": user}], fmt=MERGE_SCHEMA))
            suggest = bool(res.get("same_document")) and int(res.get("confidence") or 0) >= 60
            found += suggest
            self.store.update(lambda s: s["merges"].append({
                "a": a["id"], "b": b["id"], "confidence": int(res.get("confidence") or 0),
                "reason": str(res.get("reason", ""))[:300],
                "status": "open" if suggest else "no", "at": date.today().isoformat()}))
        return found

    # ── Actions from the Büro tab ─────────────────────────────────────────────

    def undo(self, did):
        """Restore a document's metadata and text, and drop it from the processed set."""
        before = self.store.read()["docs"].get(str(did), {}).get("before")
        if not before:
            raise RuntimeError("Kein gespeicherter Ursprungszustand.")
        self.api().patch(f"documents/{did}/", {k: v for k, v in before.items() if k != "custom_fields"}
                         | {"custom_fields": [{"field": c["field"], "value": c.get("value")}
                                              for c in before.get("custom_fields") or []]})
        self.store.update(lambda s: s["docs"].pop(str(did), None))

    def accept(self, did):
        """Reviewed and fine: remove the review tag."""
        api = self.api()
        review = {t["name"]: t["id"] for t in api.all("tags")}.get(REVIEW)
        doc = api.get(f"documents/{did}/")
        api.patch(f"documents/{did}/", {"tags": [t for t in doc["tags"] if t != review]})
        self.store.update(lambda s: s["docs"].setdefault(str(did), {}).update(status="done"))

    def merge(self, a, b, approve=True):
        def mark(status):
            def fn(s):
                for m in s["merges"]:
                    if m["a"] == a and m["b"] == b:
                        m["status"] = status
                    elif status == "merged" and m["status"] == "open" and {m["a"], m["b"]} & {a, b}:
                        m["status"] = "stale"   # one of its documents no longer exists
            return fn
        if not approve:
            self.store.update(mark("rejected"))
            return
        api = self.api()
        marker = {t["name"]: t["id"] for t in api.all("tags")}.get(MARKER)
        doc = api.get(f"documents/{a}/")
        # The merged document copies A's metadata; without the marker the next run processes it whole
        api.patch(f"documents/{a}/", {"tags": [t for t in doc["tags"] if t != marker]})
        api.post("documents/merge/", {"documents": [a, b], "metadata_document_id": a,
                                      "delete_originals": True})
        self.store.update(mark("merged"))
        self.store.update(lambda s: [s["docs"].pop(str(x), None) for x in (a, b)])
