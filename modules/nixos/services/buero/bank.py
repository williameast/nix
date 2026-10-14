"""
Bank statements: CSV import, storage, rules and matching.

Supported exports (detected from the header row, not the file name):
  - DKB Girokonto   "Buchungsdatum";"Wertstellung";"Status";"Zahlungspflichtige*r";…
  - DKB Kreditkarte "Belegdatum";"Wertstellung";"Status";"Beschreibung";…
  - HVB / UniCredit Kontonummer;Buchungsdatum;Valuta;Verwendungszweck;Betrag;Waehrung (UTF-16)
Anything else with recognisable German column names goes through the same
generic column mapping.

Each transaction gets a stable id from its content, so uploading overlapping
exports again only adds what is new. Review state lives on the transaction:
  cat         ""  (unreviewed) | business | private | transfer
  project_id, exp_category, invoice_id, expense_id, note
  ai          last suggestion from the LLM (see bank_ai.py)
"""

import csv
import hashlib
import io
import json
import os
import re
import threading
from datetime import datetime, timedelta
from pathlib import Path

CATS = ("business", "private", "transfer")
CAT_LABELS = {"": "Ungeprüft", "business": "Geschäftlich", "private": "Privat", "transfer": "Umbuchung"}

# ── Decoding & parsing ────────────────────────────────────────────────────────

def decode(raw: bytes) -> str:
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    if len(raw) > 3 and raw[1] == 0 and raw[3] == 0:      # UTF-16LE without BOM (HVB)
        return raw.decode("utf-16-le")
    if len(raw) > 3 and raw[0] == 0 and raw[2] == 0:
        return raw.decode("utf-16-be")
    try:
        return raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        return raw.decode("cp1252")


_COLS = {
    "date":      ("buchungsdatum", "belegdatum", "buchungstag", "datum"),
    "value":     ("wertstellung", "valuta"),
    "status":    ("status",),
    "payer":     ("zahlungspflichtige*r", "auftraggeber / begünstigter", "auftraggeber"),
    "payee":     ("zahlungsempfänger*in", "empfänger", "begünstigter"),
    "desc":      ("beschreibung",),
    "purpose":   ("verwendungszweck",),
    "type":      ("umsatztyp", "buchungstext"),
    "iban":      ("iban", "kontonummer/iban"),
    "amount":    ("betrag (€)", "betrag (eur)", "betrag"),
    "fx":        ("fremdwährungsbetrag",),
    "ref":       ("kundenreferenz",),
    "account":   ("kontonummer",),
}


def _map_header(row):
    low = [c.strip().lower() for c in row]
    m = {}
    for key, names in _COLS.items():
        for n in names:
            if n in low:
                m[key] = low.index(n)
                break
    return m


_THOUSANDS_ONLY = re.compile(r"^[+-]?\d{1,3}(\.\d{3})+$")


def parse_amount(s, legacy=False):
    """German amounts: "1.799,58", "-52,3", "-4" and, since DKB drops ",00",
    "1.146" for 1146 €. legacy=True reproduces the old reading of the latter
    (1.146) so transactions imported before the fix can be found and repaired."""
    s = (s or "").strip().replace("€", "").replace("EUR", "").replace("\xa0", "").replace(" ", "")
    if not s:
        return None
    if "," in s or (not legacy and _THOUSANDS_ONLY.match(s)):
        s = s.replace(".", "").replace(",", ".")
    try:
        return round(float(s), 2)
    except ValueError:
        return None


def parse_date(s):
    s = (s or "").strip()
    for fmt in ("%d.%m.%y", "%d.%m.%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            pass
    return None


_HVB_TYPES = [
    "LASTSCHRIFT IM AUFTR.V.", "DAUERAUFTRAG (AUSFÜHRUNG) EMPFAENGER", "DAUERAUFTRAG (AUSFÜHRUNG)",
    "ÜBERWEISUNG (DIRECT BANKING", "ECHTZEITÜBERWEISUNG", "ECHTZEITGUTSCHRIFT", "SEPA-DAUERAUFTRAG",
    "SEPA-GUTSCHRIFT", "SEPA-ÜBERWEISUNG", "ÜBERWEISUNG", "GUTSCHRIFT", "LASTSCHRIFT",
    "EC-GAA/POS", "KREDITKARTENABRECHNUNG", "PREISE/ENTGELTE", "KARTENPREIS", "ABSCHLUSS",
]
_HVB_STOP = re.compile(
    r"\s(?:[A-Z]{2}\d{2}[\d ]{10,}|IBAN|BIC|KUNDENREFERENZ|MANDATSREFERENZ|GLAEUBIGER|Belegdatum|"
    r"Order-Nr|VERWENDUNGSZWECK|KD-NR|Kd-Nr|RG-NR|AUFTRAG UM|MOBILE|INTERNET|\S*/\d|\d{4,})|,|\s{2,}")


def split_hvb(text):
    """HVB packs type, counterparty and purpose into one field."""
    t = " ".join((text or "").split())
    typ = next((p for p in _HVB_TYPES if t.upper().startswith(p.upper())), "")
    rest = t[len(typ):].strip()
    m = _HVB_STOP.search(" " + rest)
    name = (" " + rest)[:m.start()].strip() if m else rest
    name = " ".join(name.split()[:5])
    return typ.title(), name or typ.title(), rest


def _account_from_preamble(lines):
    """DKB puts "Girokonto";"DE…" or "Karte";"Visa Kreditkarte";"4930 •••• 6742" on top."""
    for row in lines[:6]:
        cells = [c.strip() for c in row]
        if len(cells) >= 2 and cells[0] == "Girokonto":
            iban = cells[1].replace(" ", "")
            return {"id": iban, "name": f"DKB Girokonto …{iban[-4:]}", "iban": iban, "bank": "DKB"}
        if len(cells) >= 3 and cells[0] == "Karte":
            last4 = re.sub(r"\D", "", cells[2])[-4:]
            return {"id": f"card-{last4}", "name": f"DKB {cells[1]} …{last4}", "iban": "", "bank": "DKB"}
    return None


def parse_csv(raw: bytes, filename=""):
    """Returns (account, transactions, skipped_pending). Raises ValueError if unknown."""
    text = decode(raw)
    rows = list(csv.reader(io.StringIO(text), delimiter=";"))
    hdr_i = next((i for i, r in enumerate(rows[:30])
                  if {"date", "amount"} <= set(_map_header(r))), None)
    if hdr_i is None:
        raise ValueError(f"{filename}: Format nicht erkannt (keine Datums-/Betragsspalte gefunden)")
    m = _map_header(rows[hdr_i])
    account = _account_from_preamble(rows[:hdr_i])

    def cell(r, k):
        i = m.get(k)
        return r[i].strip() if i is not None and i < len(r) else ""

    out, pending, seen = [], 0, {}
    for r in rows[hdr_i + 1:]:
        if not any(c.strip() for c in r):
            continue
        d, amt = parse_date(cell(r, "date")), parse_amount(cell(r, "amount"))
        if not d or amt is None:
            continue
        if cell(r, "status").lower() in ("vorgemerkt", "pending"):
            pending += 1   # imported once booked; pending lines change their date and id
            continue
        if account is None:
            acct_no = cell(r, "account")
            account = {"id": acct_no or (filename or "konto"), "bank": "HVB" if acct_no else "",
                       "name": f"HVB Girokonto {acct_no}" if acct_no else (filename or "Konto"), "iban": ""}
        purpose = cell(r, "purpose") or cell(r, "desc")
        typ = cell(r, "type")
        if m.get("payer") is not None or m.get("payee") is not None:
            party = cell(r, "payee") if amt < 0 else cell(r, "payer")
        elif m.get("desc") is not None:
            party = cell(r, "desc")              # card statements: merchant only
        else:
            typ, party, purpose = split_hvb(purpose)
        if party.upper() == "ISSUER":            # DKB debit card: payer is the card issuer
            party = cell(r, "payee") or party
        tx = {
            "account":      account["id"],
            "date":         d,
            "value_date":   parse_date(cell(r, "value")) or d,
            "amount":       amt,
            "counterparty": " ".join(party.split()),
            "purpose":      " ".join(purpose.split()),
            "type":         typ,
            "iban":         cell(r, "iban").replace(" ", ""),
            "ref":          cell(r, "ref"),
        }
        if cell(r, "fx"):
            tx["fx"] = cell(r, "fx")
        key = "|".join(str(tx[k]) for k in ("account", "date", "amount", "counterparty", "purpose", "ref"))
        seen[key] = seen.get(key, 0) + 1           # identical lines on one day stay distinct
        tx["id"] = hashlib.sha1(f"{key}|{seen[key]}".encode()).hexdigest()[:12]
        old_amt = parse_amount(cell(r, "amount"), legacy=True)
        if old_amt != amt:                         # id under the old "1.146" → 1.146 € reading
            old_key = "|".join(str({**tx, "amount": old_amt}[k])
                               for k in ("account", "date", "amount", "counterparty", "purpose", "ref"))
            tx["legacy_id"] = hashlib.sha1(f"{old_key}|{seen[key]}".encode()).hexdigest()[:12]
        out.append(tx)
    if account is None:
        raise ValueError(f"{filename}: keine Umsätze gefunden")
    return account, out, pending


# ── Storage ───────────────────────────────────────────────────────────────────

class BankStore:
    """JSON files under data/bank/. One lock, since the AI run writes from a thread."""

    def __init__(self, root: Path):
        self.root = root
        self.lock = threading.RLock()
        root.mkdir(parents=True, exist_ok=True)

    def _read(self, name, default):
        p = self.root / name
        if not p.exists():
            return default
        with open(p, encoding="utf-8") as f:
            return json.load(f)

    def _write(self, name, data):
        p = self.root / name
        tmp = p.with_name(f".{p.name}.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        os.replace(tmp, p)

    def transactions(self):
        return self._read("transactions.json", {})

    def save_transactions(self, txs):
        self._write("transactions.json", txs)

    def accounts(self):
        return self._read("accounts.json", {})

    def save_accounts(self, a):
        self._write("accounts.json", a)

    def rules(self):
        return self._read("rules.json", [])

    def save_rules(self, r):
        self._write("rules.json", r)

    def update(self, fn):
        """Read-modify-write the transactions under the lock; fn mutates the dict."""
        with self.lock:
            txs = self.transactions()
            result = fn(txs)
            self.save_transactions(txs)
            return result


# ── Rules & automatic classification ──────────────────────────────────────────

# Things that are never income or spending: card settlements, own transfers, bank statements
_TRANSFER_RE = re.compile(r"ausgleich kreditkarte|abrechnung \d\d\.\d\d\.\d{4} siehe anlage",
                          re.IGNORECASE)


def rule_matches(rule, tx):
    needle = (rule.get("match") or "").lower()
    if not needle:
        return False
    if rule.get("account") and rule["account"] != tx["account"]:
        return False
    hay = {"counterparty": tx["counterparty"], "purpose": tx["purpose"]}.get(
        rule.get("field", "counterparty"), f'{tx["counterparty"]} {tx["purpose"]}')
    return needle in hay.lower()


def apply_rules(txs, rules, accounts, only_unreviewed=True):
    """Rules first, then account defaults. Returns the number of transactions changed."""
    n = 0
    for tx in txs.values():
        if only_unreviewed and tx.get("cat"):
            continue
        rule = next((r for r in rules if rule_matches(r, tx)), None)
        if rule:
            tx["cat"] = rule.get("cat", "")
            if rule.get("project_id"):
                tx["project_id"] = rule["project_id"]
            if rule.get("exp_category"):
                tx["exp_category"] = rule["exp_category"]
            tx["auto"] = "rule"
            n += 1
        elif _TRANSFER_RE.search(f'{tx["counterparty"]} {tx["purpose"]}'):
            tx["cat"], tx["auto"] = "transfer", "transfer"
            n += 1
        else:
            default = (accounts.get(tx["account"]) or {}).get("default_cat", "")
            if default:
                tx["cat"], tx["auto"] = default, "account"
                n += 1
    return n


_CARD_SETTLEMENT = re.compile(r"kreditkartenabrechnung.*?(\d{4})\b", re.IGNORECASE)
_TRANSFER_WORDS = re.compile(r"ausgleich|umbuchung|übertrag|uebertrag|kontoauflös|eigene", re.IGNORECASE)


def card_settlement_card(tx):
    """Last four digits of the card a "KREDITKARTENABRECHNUNG …XXXX1234" line settles."""
    m = _CARD_SETTLEMENT.search(tx["purpose"])
    return m.group(1) if m else None


def detect_transfers(txs, accounts, owner_name=""):
    """Internal money moves are neither income nor spending:
      - settlements of a card whose own statement is imported (else they are the
        only trace of that card's spending and stay up for review),
      - payments naming one of the own account numbers,
      - opposite equal amounts on two own accounts within 4 days, if one side is a
        card or the text/counterparty says so (own name, "Ausgleich", "Umbuchung").
    Only unreviewed transactions are touched. Returns the number changed."""
    own_nrs = set()
    for a in accounts.values():
        if a.get("iban"):
            own_nrs.add(a["iban"][-10:])
        digits = re.sub(r"\D", "", a.get("id", ""))
        if len(digits) >= 7:
            own_nrs.add(digits.zfill(10))
    cards = {a["id"][5:] for a in accounts.values() if a.get("id", "").startswith("card-")}
    owner = [w.lower() for w in owner_name.split() if len(w) > 2]

    def own_name(t):
        return owner and all(w in t["counterparty"].lower() for w in owner)

    def mark(t):
        t["cat"], t["auto"] = "transfer", "transfer"

    n = 0
    open_ = [t for t in txs.values() if not t.get("cat")]
    for t in open_:
        card = card_settlement_card(t)
        blob = re.sub(r"\s", "", f'{t.get("iban", "")}{t["purpose"]}')
        if (card and card in cards) or any(o in blob for o in own_nrs) or own_name(t):
            mark(t)
            n += 1
    by_amount = {}
    for t in txs.values():
        by_amount.setdefault(abs(t["amount"]), []).append(t)
    free = ("", None, "transfer")   # one side may already be marked, e.g. "Ausgleich Kreditkarte"
    for t in txs.values():
        if t["amount"] <= 0 or t.get("cat") not in free:
            continue
        d = datetime.fromisoformat(t["date"])
        for o in by_amount.get(t["amount"], []):
            if (o["account"] == t["account"] or o["amount"] != -t["amount"]
                    or o.get("cat") not in free or (t.get("cat") and o.get("cat"))
                    or abs((datetime.fromisoformat(o["date"]) - d).days) > 4):
                continue
            hint = (t["account"].startswith("card-") or o["account"].startswith("card-")
                    or any(_TRANSFER_WORDS.search(f'{x["counterparty"]} {x["purpose"]}') or own_name(x)
                           for x in (t, o)))
            if hint:
                for x in (t, o):
                    if not x.get("cat"):
                        mark(x)
                        n += 1
                break
    return n


# ── Matching against invoices and expenses ────────────────────────────────────

def invoice_candidates(tx, open_invoices):
    """open_invoices: [(invoice, total)]. Exact amount or the invoice number in the text."""
    if tx["amount"] <= 0:
        return []
    text = f'{tx["purpose"]} {tx["counterparty"]}'.replace(" ", "")
    out = []
    for inv, total in open_invoices:
        iid = str(inv.get("id", ""))
        named = len(iid) >= 6 and iid.replace(" ", "") in text
        same = abs(total - tx["amount"]) < 0.01
        if (named or same) and (inv.get("date") or "") <= tx["date"]:
            out.append({"id": iid, "total": total, "named": named, "exact": same})
    out.sort(key=lambda c: (not c["named"], not c["exact"]))
    return out[:3]


def expense_candidates(tx, expenses, linked_ids):
    """Existing, unlinked expenses with the same amount within a week."""
    if tx["amount"] >= 0:
        return []
    d = datetime.fromisoformat(tx["date"])
    out = []
    for e in expenses:
        if e.get("id") in linked_ids:
            continue
        try:
            same = abs(float(e.get("amount") or 0) - abs(tx["amount"])) < 0.01
            near = abs((datetime.fromisoformat(str(e.get("date"))) - d).days) <= 7
        except ValueError:
            continue
        if same and near:
            out.append(e)
    return out[:3]
