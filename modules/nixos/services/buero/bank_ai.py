"""
LLM review of bank transactions: business or private, which project, which
expense category, which invoice an incoming payment settles.

Two ways to use it:
  - run() calls the Claude API directly (needs an API key in settings or
    ANTHROPIC_API_KEY), in batches, from a background thread;
  - export_markdown() writes the same prompt + data as a file to paste into
    any chat (or hand to Claude Code); parse_reply() reads the JSON answer back.

Only what is needed to judge a payment leaves the server: date, amount,
counterparty, purpose text and the account's role. IBANs, card and account
numbers are stripped.
"""

import json
import re

MODEL = "claude-opus-5-5"
BATCH = 120

SCHEMA = {
    "type": "object",
    "properties": {
        "suggestions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id":           {"type": "string"},
                    "category":     {"type": "string", "enum": ["business", "private", "transfer", "unsure"]},
                    "project_id":   {"type": "string"},
                    "exp_category": {"type": "string"},
                    "invoice_id":   {"type": "string"},
                    "confidence":   {"type": "integer"},
                    "reason":       {"type": "string"},
                },
                "required": ["id", "category", "project_id", "exp_category", "invoice_id", "confidence", "reason"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["suggestions"],
    "additionalProperties": False,
}

SYSTEM = """You help a freelancer in Berlin keep their books. They run a one-person studio ({business}) \
building props, set pieces and custom objects for film, music video and advertising productions, \
and invoice clients per project. Their bank accounts and cards mix private and business spending.

For every transaction you are given, decide:
- category: "business" (cost or income of the studio), "private" (personal life), "transfer" \
(money moving between the owner's own accounts or cards, card settlements), or "unsure" when the data \
genuinely does not tell. Prefer "unsure" over guessing; it is cheap for the owner to look at it.
- project_id: for business transactions that clearly belong to one project, its id from the project \
list, else "". Use the project period (spending in the weeks before and during it), the client, the \
description and what was bought. Do not assign a project only because the date fits.
- exp_category: for business spending, one of the given expense categories, else "".
- invoice_id: for incoming payments, the id of the open invoice it settles (amount, client name or \
invoice number in the text), else "".
- confidence: 0-100, how sure you are of category and project together.
- reason: one short sentence in German the owner can check at a glance.

Signals: building materials, hardware stores, art and model-making suppliers, 3D printing, \
fabric, paint, tools, prop rentals, transport/van rental, software subscriptions and the business \
phone are usually business. Groceries, restaurants, rent, utilities for the flat, insurance for \
private life, gifts from family and leisure are usually private, unless the text says otherwise or \
it is catering on a shoot day of a project. Each account has a role (business, private, mixed); a \
business account leans business but still carries private spending. The owner's own past decisions \
are given as examples; follow their habits for the same merchants.

Return one suggestion for every transaction id you were given, and only those ids."""


def _clean(text, limit=180):
    t = re.sub(r"\b[A-Z]{2}\d{2}(?:\s?[\dA-Z]{2,4}){3,8}\b", "[IBAN]", text or "")
    t = re.sub(r"\b\d{4}[\s*X•]{4,}[\dX•*\s]{4,}\d{4}\b|\b\d{6}[X*]{4,}\d{4}\b", "[KARTE]", t)
    t = re.sub(r"\b\d{9,}\b|…\d{4}\b", "[NR]", t)
    return " ".join(t.split())[:limit]


def build_context(txs, projects, clients, open_invoices, accounts, examples, exp_categories):
    """txs: transactions to judge. examples: already reviewed ones (the owner's decisions)."""
    cname = {c.get("id"): c.get("name", "") for c in clients}
    pname = {p.get("id"): p.get("name", "") for p in projects}
    # Account ids are IBANs / account numbers: send neutral aliases instead
    alias = {aid: f"A{i + 1}" for i, aid in enumerate(sorted({t["account"] for t in txs}))}
    acct = lambda a: {"name": _clean((accounts.get(a) or {}).get("name", ""), 60),
                      "role": (accounts.get(a) or {}).get("role", "mixed")}
    return {
        "expense_categories": exp_categories,
        "accounts": {alias[aid]: acct(aid) for aid in alias},
        "projects": [{
            "id": p["id"], "name": p.get("name", ""), "client": cname.get(p.get("client_id"), ""),
            "start": p.get("start_date", ""), "end": p.get("end_date", ""), "status": p.get("status", ""),
            "description": _clean(p.get("description", ""), 300),
        } for p in projects],
        "open_invoices": [{
            "id": inv["id"], "client": cname.get(inv.get("client_id"), ""), "date": inv.get("date", ""),
            "total": round(total, 2),
        } for inv, total in open_invoices],
        "examples": [{
            "date": t["date"], "amount": t["amount"], "counterparty": _clean(t["counterparty"], 60),
            "purpose": _clean(t["purpose"], 80), "category": t["cat"],
            "project": pname.get(t.get("project_id"), ""), "exp_category": t.get("exp_category", ""),
        } for t in examples],
        "transactions": [{
            "id": t["id"], "date": t["date"], "amount": t["amount"], "account": alias[t["account"]],
            "counterparty": _clean(t["counterparty"], 80), "purpose": _clean(t["purpose"]),
            "type": t.get("type", ""),
        } for t in txs],
    }


def _system(business):
    return SYSTEM.format(business=business or "the studio")


def _user_text(ctx):
    return ("Here are the owner's projects, open invoices, past decisions and the transactions to "
            "review, as JSON:\n\n" + json.dumps(ctx, ensure_ascii=False, indent=1))


def run(api_key, business, ctx, on_batch=None):
    """Call Claude in batches. Returns a list of suggestion dicts.
    on_batch(done, total) reports progress. Raises RuntimeError with a readable message."""
    import anthropic
    client = anthropic.Anthropic(api_key=api_key) if api_key else anthropic.Anthropic()
    txs, out = ctx["transactions"], []
    total = len(txs)
    for i in range(0, total, BATCH):
        part = {**ctx, "transactions": txs[i:i + BATCH]}
        try:
            with client.beta.messages.stream(
                model=MODEL,
                max_tokens=32000,
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
                output_config={"effort": "medium",
                               "format": {"type": "json_schema", "schema": SCHEMA}},
                system=[{"type": "text", "text": _system(business), "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": _user_text(part)}],
            ) as stream:
                msg = stream.get_final_message()
        except anthropic.AuthenticationError:
            raise RuntimeError("API-Schlüssel ungültig – in den Einstellungen prüfen.")
        except anthropic.RateLimitError:
            raise RuntimeError("Rate-Limit erreicht – in ein paar Minuten erneut versuchen.")
        except anthropic.APIStatusError as e:
            raise RuntimeError(f"API-Fehler {e.status_code}: {e.message}")
        except anthropic.APIConnectionError:
            raise RuntimeError("Keine Verbindung zur Claude API.")
        if msg.stop_reason == "refusal":
            raise RuntimeError("Die Anfrage wurde abgelehnt (refusal).")
        if msg.stop_reason == "max_tokens":
            raise RuntimeError("Antwort abgeschnitten (max_tokens) – Stapel zu groß.")
        text = next((b.text for b in msg.content if b.type == "text"), "")
        out.extend(json.loads(text).get("suggestions", []))
        if on_batch:
            on_batch(min(i + BATCH, total), total)
    return out


def export_markdown(business, ctx):
    """Prompt + data as one file, for pasting into a chat or giving to Claude Code."""
    return f"""# Kontoumsätze prüfen

{_system(business)}

Answer with JSON only, matching this schema:

```json
{json.dumps(SCHEMA, indent=1)}
```

## Data

{_user_text(ctx)}
"""


def parse_reply(text):
    """Accept the JSON answer from a chat, with or without ``` fences around it."""
    m = re.search(r"\{.*\}", text or "", re.DOTALL)
    if not m:
        raise ValueError("Keine JSON-Antwort gefunden.")
    data = json.loads(m.group(0))
    items = data.get("suggestions") if isinstance(data, dict) else data
    if not isinstance(items, list):
        raise ValueError("JSON enthält keine Liste „suggestions“.")
    return items
