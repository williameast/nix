"""
Standard clauses for the project contract (Auftragsvereinbarung).

Boilerplate for a freelance Werkvertrag under German law (BGB), tuned for
production work: props, set builds, custom objects, rentals. Each clause is
a Jinja template rendered with the contract context (see app.contract_context)
and then passed through rich_text, so **fett**, *kursiv* and "- " lists work.

This is a sensible starting point, not legal advice: have it checked once
by a lawyer before relying on it for large jobs.
"""

# Placeholders available in standard AND custom clauses
PLACEHOLDERS = {
    "contractor": "Ihr Firmenname",
    "client":     "Name des Kunden",
    "project":    "Projektname",
    "start":      "Startdatum",
    "end":        "Enddatum",
    "fee":        "Vergütung (formatiert)",
    "deposit":    "Anzahlung (formatiert)",
    "location":   "Leistungs-/Lieferort",
}

CLAUSES = [
    {
        "key": "scope",
        "de": ("Vertragsgegenstand",
               """Der Auftragnehmer erbringt für den Auftraggeber im Rahmen des Projekts „{{ project }}“ die nachfolgend beschriebenen Leistungen{% if quote_id %}. Ergänzend gilt das Angebot Nr. {{ quote_id }}{% if quote_attached %}, das diesem Vertrag als Anlage beiliegt{% endif %}{% endif %}.{% if location %} Leistungs- bzw. Lieferort ist {{ location }}.{% endif %}

{{ scope }}{% if deliverables %}

**Lieferumfang**
{{ deliverables }}{% endif %}

Der Auftragnehmer erbringt seine Leistungen selbstständig und eigenverantwortlich; er ist bei der Wahl von Arbeitsort, Arbeitszeit und Arbeitsmitteln frei und darf Subunternehmer einsetzen. Ein Arbeitsverhältnis wird nicht begründet."""),
        "en": ("Subject of the Agreement",
               """The Contractor shall provide the services described below to the Client for the project “{{ project }}”{% if quote_id %}. Quote no. {{ quote_id }} applies in addition{% if quote_attached %} and is attached to this agreement{% endif %}{% endif %}.{% if location %} The place of performance and delivery is {{ location }}.{% endif %}

{{ scope }}{% if deliverables %}

**Deliverables**
{{ deliverables }}{% endif %}

The Contractor works independently and on their own responsibility, is free to choose place, time and means of work, and may engage subcontractors. No employment relationship is created."""),
    },
    {
        "key": "dates",
        "de": ("Leistungszeitraum und Termine",
               """{% if start and end %}Die Leistungen werden im Zeitraum vom {{ start }} bis {{ end }} erbracht.{% elif start %}Die Leistungserbringung beginnt am {{ start }}.{% elif end %}Die Leistungen werden bis zum {{ end }} fertiggestellt.{% else %}Termine werden gesondert in Textform vereinbart.{% endif %}

Termine sind nur verbindlich, wenn sie ausdrücklich als verbindlich vereinbart wurden. Verzögert sich die Leistung aus Gründen, die der Auftraggeber zu vertreten hat (z. B. verspätete Freigaben, Informationen oder Beistellungen), verschieben sich alle Termine angemessen; der dadurch entstehende Mehraufwand wird gesondert vergütet."""),
        "en": ("Term and Deadlines",
               """{% if start and end %}The services will be provided between {{ start }} and {{ end }}.{% elif start %}Work begins on {{ start }}.{% elif end %}The services will be completed by {{ end }}.{% else %}Dates will be agreed separately in writing.{% endif %}

Deadlines are binding only if expressly agreed as binding. If performance is delayed for reasons attributable to the Client (e.g. late approvals, information or supplied materials), all deadlines shall be extended accordingly, and any additional effort shall be paid separately."""),
    },
    {
        "key": "fee",
        "de": ("Vergütung",
               """{% if fee_type == 'fixed' %}Für die vereinbarten Leistungen erhält der Auftragnehmer eine Pauschalvergütung von **{{ fee }}**.{% else %}Die Leistungen werden nach Aufwand mit **{{ rate }} je {{ unit }}** abgerechnet.{% if fee %} Der voraussichtliche Gesamtaufwand wird auf {{ fee }} geschätzt; eine Überschreitung um mehr als 15 % zeigt der Auftragnehmer rechtzeitig an.{% endif %}{% endif %}

Material, Fremdleistungen, Transporte und Reisekosten, die nicht ausdrücklich in der Vergütung enthalten sind, werden nach vorheriger Absprache zum Selbstkostenpreis gegen Beleg gesondert berechnet.

{% if kleinunternehmer %}Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.{% else %}Alle Beträge verstehen sich zuzüglich der gesetzlichen Umsatzsteuer.{% endif %}"""),
        "en": ("Remuneration",
               """{% if fee_type == 'fixed' %}For the agreed services the Contractor receives a fixed fee of **{{ fee }}**.{% else %}Services are billed on a time basis at **{{ rate }} per {{ unit }}**.{% if fee %} The total effort is estimated at {{ fee }}; the Contractor will give timely notice if this estimate is likely to be exceeded by more than 15 %.{% endif %}{% endif %}

Materials, third-party services, transport and travel costs not expressly included in the fee will be charged separately at cost against receipts, after prior consultation.

{% if kleinunternehmer %}Pursuant to § 19 UStG (German VAT Act), no VAT is charged.{% else %}All amounts are subject to statutory VAT.{% endif %}"""),
    },
    {
        "key": "payment",
        "de": ("Zahlungsbedingungen",
               """{% if deposit_pct %}Mit Unterzeichnung dieses Vertrags wird eine Anzahlung von {{ deposit_pct }} %{% if deposit %} (**{{ deposit }}**){% endif %} fällig. Der Auftragnehmer beginnt mit der Arbeit nach Eingang der Anzahlung. {% endif %}{% if fee_type == 'fixed' %}Der Restbetrag wird mit Fertigstellung bzw. Abnahme in Rechnung gestellt.{% else %}Der Aufwand wird {% if deposit_pct %}darüber hinaus {% endif %}monatlich bzw. nach Abschluss der Leistung abgerechnet.{% endif %} Bei Projekten über mehr als einen Monat ist der Auftragnehmer berechtigt, Abschlagszahlungen für bereits erbrachte Leistungen zu verlangen.

Rechnungen sind innerhalb von {{ payment_days }} Tagen nach Rechnungsdatum ohne Abzug zahlbar. Bei Zahlungsverzug gelten die gesetzlichen Regelungen (§§ 286, 288 BGB)."""),
        "en": ("Payment Terms",
               """{% if deposit_pct %}A deposit of {{ deposit_pct }} %{% if deposit %} (**{{ deposit }}**){% endif %} is due upon signing this agreement. Work begins once the deposit has been received. {% endif %}{% if fee_type == 'fixed' %}The balance is invoiced upon completion or acceptance.{% else %}Time spent is {% if deposit_pct %}further {% endif %}invoiced monthly or on completion.{% endif %} For projects lasting more than one month the Contractor may request interim payments for services already rendered.

Invoices are payable within {{ payment_days }} days of the invoice date without deduction. Statutory provisions apply in case of late payment (§§ 286, 288 BGB)."""),
    },
    {
        "key": "cooperation",
        "de": ("Mitwirkung des Auftraggebers",
               """Der Auftraggeber stellt rechtzeitig alle für die Leistung erforderlichen Informationen, Vorlagen, Maße, Referenzen und Freigaben zur Verfügung und benennt eine entscheidungsbefugte Ansprechperson. Für vom Auftraggeber beigestellte Materialien und Inhalte sowie deren Rechte ist der Auftraggeber verantwortlich."""),
        "en": ("Client Cooperation",
               """The Client shall provide all information, templates, dimensions, references and approvals required for the work in good time and shall name a contact person with authority to make decisions. The Client is responsible for any materials and content it supplies, including the rights to them."""),
    },
    {
        "key": "changes",
        "de": ("Änderungen und Zusatzleistungen",
               """Im Leistungsumfang {% if revisions %}{% if revisions == 1 %}ist eine Korrekturschleife{% else %}sind {{ revisions }} Korrekturschleifen{% endif %}{% else %}sind keine Korrekturschleifen{% endif %} enthalten. Änderungswünsche nach Freigabe eines Entwurfs oder Leistungen, die über den vereinbarten Umfang hinausgehen, werden nach vorheriger Ankündigung {% if extra_rate %}mit {{ extra_rate }} je {{ unit }}{% else %}nach Aufwand{% endif %} gesondert berechnet. Zusatzaufträge können in Textform (z. B. per E-Mail) erteilt werden."""),
        "en": ("Changes and Additional Work",
               """The scope includes {% if revisions %}{% if revisions == 1 %}one round{% else %}{{ revisions }} rounds{% endif %}{% else %}no rounds{% endif %} of revisions. Changes requested after approval of a design, or work beyond the agreed scope, will be charged separately {% if extra_rate %}at {{ extra_rate }} per {{ unit }}{% else %}on a time basis{% endif %} after prior notice. Additional orders may be placed in text form (e.g. by email)."""),
    },
    {
        "key": "acceptance",
        "de": ("Abnahme",
               """Der Auftraggeber prüft die Leistung unverzüglich nach Übergabe. Sie gilt als abgenommen, wenn der Auftraggeber sie nicht innerhalb von {{ acceptance_days }} Tagen nach Fertigstellung unter Angabe mindestens eines wesentlichen Mangels verweigert, spätestens jedoch mit der Verwendung am Set bzw. der Veröffentlichung (§ 640 Abs. 2 BGB). Bei berechtigten Mängeln hat der Auftragnehmer zunächst das Recht zur Nachbesserung."""),
        "en": ("Acceptance",
               """The Client shall inspect the work promptly after handover. It is deemed accepted unless the Client refuses acceptance within {{ acceptance_days }} days of completion, stating at least one material defect, and in any case once it is used on set or published (§ 640 (2) BGB). In the event of justified defects, the Contractor shall first have the right to remedy them."""),
    },
    {
        "key": "cancellation",
        "de": ("Kündigung durch den Auftraggeber",
               """Der Auftraggeber kann den Vertrag jederzeit in Textform kündigen (§ 648 BGB). In diesem Fall erhält der Auftragnehmer:

- die vereinbarte Vergütung für alle bis zum Zugang der Kündigung erbrachten Leistungen,
- Ersatz für bereits beschaffte oder verbindlich bestellte Materialien und beauftragte Fremdleistungen; beschaffte Materialien und Zwischenstände werden nach Zahlung an den Auftraggeber herausgegeben,
- für den noch nicht erbrachten Teil eine Pauschale von {{ cancel_pct }} % der darauf entfallenden Vergütung als Ausgleich für reservierte Kapazitäten.

Beiden Parteien bleibt der Nachweis vorbehalten, dass der tatsächliche Anspruch höher oder niedriger ist. Eine geleistete Anzahlung wird verrechnet. Das Recht beider Parteien zur Kündigung aus wichtigem Grund bleibt unberührt."""),
        "en": ("Termination by the Client",
               """The Client may terminate this agreement at any time in text form (§ 648 BGB). In that case the Contractor shall receive:

- the agreed remuneration for all work performed up to receipt of the notice,
- reimbursement for materials already procured or bindingly ordered and for commissioned third-party services; procured materials and work in progress will be handed over to the Client upon payment,
- for the part not yet performed, a flat fee of {{ cancel_pct }} % of the remuneration attributable to it, as compensation for reserved capacity.

Each party may prove that the actual claim is higher or lower. Any deposit paid will be offset. The right of both parties to terminate for good cause remains unaffected."""),
    },
    {
        "key": "postponement",
        "de": ("Verschiebung",
               """Verschiebt der Auftraggeber vereinbarte Termine (z. B. Dreh-, Aufbau- oder Liefertermine), werden die dadurch entstehenden Kosten (Lager, Miete, umgebuchte Transporte, Ausfallzeiten) ersetzt. Ist der Auftragnehmer zum neuen Termin bereits anderweitig gebunden, bemüht er sich um eine gleichwertige Lösung; gelingt dies nicht, gilt die Verschiebung als Kündigung im Sinne des vorstehenden Paragraphen."""),
        "en": ("Postponement",
               """If the Client postpones agreed dates (e.g. shooting, set-up or delivery dates), any costs arising from this (storage, rental, rebooked transport, downtime) shall be reimbursed. If the Contractor is already committed elsewhere on the new date, they will make reasonable efforts to find an equivalent solution; failing this, the postponement is treated as termination under the preceding section."""),
    },
    {
        "key": "property",
        "de": ("Eigentum, Material und Mietgegenstände",
               """Hergestellte und gelieferte Gegenstände bleiben bis zur vollständigen Bezahlung Eigentum des Auftragnehmers. Vermietete oder leihweise überlassene Gegenstände sind zum vereinbarten Termin vollständig und in ordnungsgemäßem Zustand zurückzugeben; für Beschädigung oder Verlust über die übliche Abnutzung hinaus haftet der Auftraggeber zum Wiederbeschaffungswert. Gegenstände sind für den Einsatz als Requisite gefertigt und – sofern nicht anders vereinbart – nicht für Stunts, Dauerbelastung oder den Gebrauch als Verbraucherprodukt bestimmt."""),
        "en": ("Ownership, Materials and Rentals",
               """Items made and delivered remain the property of the Contractor until paid for in full. Rented or loaned items must be returned complete and in proper condition on the agreed date; the Client is liable at replacement value for damage or loss beyond normal wear and tear. Items are made for use as props and, unless agreed otherwise, are not intended for stunts, continuous load or use as consumer products."""),
    },
    {
        "key": "rights",
        "de": ("Nutzungsrechte und Referenzen",
               """Mit vollständiger Bezahlung erhält der Auftraggeber das einfache, zeitlich und räumlich unbeschränkte Recht, die Arbeitsergebnisse für den vereinbarten Projektzweck zu nutzen. Eine darüber hinausgehende Nutzung, Bearbeitung oder Vervielfältigung (z. B. Merchandising, Serienfertigung) bedarf einer gesonderten Vereinbarung. Entwürfe, Konstruktionsunterlagen und Dateien bleiben beim Auftragnehmer.{% if portfolio %}

Der Auftragnehmer darf die Arbeitsergebnisse nach Veröffentlichung des Projekts unter Nennung des Projekts in seinem Portfolio, auf seiner Website und in sozialen Medien zeigen.{% endif %}"""),
        "en": ("Usage Rights and References",
               """Upon full payment, the Client receives the simple (non-exclusive) right, unlimited in time and territory, to use the work for the agreed project purpose. Any further use, modification or reproduction (e.g. merchandising, series production) requires a separate agreement. Designs, construction documents and files remain with the Contractor.{% if portfolio %}

After the project has been published, the Contractor may show the work, naming the project, in their portfolio, on their website and on social media.{% endif %}"""),
    },
    {
        "key": "liability",
        "de": ("Haftung",
               """Der Auftragnehmer haftet unbeschränkt für Vorsatz und grobe Fahrlässigkeit sowie für Schäden aus der Verletzung von Leben, Körper oder Gesundheit. Bei leichter Fahrlässigkeit haftet er nur bei Verletzung einer wesentlichen Vertragspflicht und begrenzt auf den vertragstypischen, vorhersehbaren Schaden. Für Schäden durch unsachgemäßen oder nicht vereinbarten Gebrauch der Gegenstände sowie durch vom Auftraggeber beigestellte Materialien wird nicht gehaftet."""),
        "en": ("Liability",
               """The Contractor is liable without limitation for intent and gross negligence and for injury to life, body or health. In case of slight negligence, the Contractor is liable only for breach of an essential contractual obligation and limited to the typical, foreseeable damage. There is no liability for damage caused by improper or unagreed use of the items or by materials supplied by the Client."""),
    },
    {
        "key": "force_majeure",
        "de": ("Höhere Gewalt",
               """Kann eine Partei ihre Pflichten aufgrund von Ereignissen außerhalb ihres Einflussbereichs (z. B. Krankheit, Unwetter, behördliche Anordnungen, Lieferausfälle) nicht rechtzeitig erfüllen, verschieben sich die betroffenen Termine um die Dauer der Behinderung. Bis dahin erbrachte Leistungen und angefallene Kosten werden vergütet."""),
        "en": ("Force Majeure",
               """If a party cannot fulfil its obligations on time due to events beyond its control (e.g. illness, severe weather, official orders, supply failures), the affected deadlines are extended by the duration of the impediment. Work performed and costs incurred up to that point shall be paid."""),
    },
    {
        "key": "confidentiality",
        "de": ("Vertraulichkeit",
               """Beide Parteien behandeln alle nicht öffentlichen Informationen über das Projekt, insbesondere Drehbücher, Entwürfe und Veröffentlichungstermine, vertraulich. Diese Pflicht gilt über das Vertragsende hinaus."""),
        "en": ("Confidentiality",
               """Both parties shall keep all non-public information about the project confidential, in particular scripts, designs and release dates. This obligation survives the end of the agreement."""),
    },
    {
        "key": "final",
        "final": True,  # always last, after any custom clauses
        "de": ("Schlussbestimmungen",
               """Änderungen und Ergänzungen dieses Vertrags bedürfen der Textform. Sollte eine Bestimmung unwirksam sein, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt; an ihre Stelle tritt die gesetzliche Regelung. Es gilt das Recht der Bundesrepublik Deutschland. Ist der Auftraggeber Kaufmann, juristische Person des öffentlichen Rechts oder hat er keinen Sitz in Deutschland, ist Gerichtsstand {{ city }}."""),
        "en": ("Final Provisions",
               """Amendments and additions to this agreement must be made in text form. Should any provision be invalid, the validity of the remaining provisions remains unaffected and the statutory provision shall apply instead. This agreement is governed by the laws of the Federal Republic of Germany. If the Client is a merchant, a legal entity under public law, or has no registered office in Germany, the place of jurisdiction is {{ city }}."""),
    },
]

CLAUSE_KEYS = [c["key"] for c in CLAUSES]
