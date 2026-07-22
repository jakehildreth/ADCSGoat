## Question

What is the page hierarchy and navigation structure for the ADCSGoat HTML site?

Type: grilling
Status: resolved

## Answer

Site uses a multi-page structure with a sidebar nav grouped by major sections.

Top-level pages:
- `index.html` — overview + difficulty quick-start
- `setup.html` — lab installation & configuration
- `prerequisites.html` — required knowledge / accounts / tools
- `tools.html` — recommended tooling (Certify, Certipy, etc.)
- `references.html` — links, credits, changelog

Attack paths live under `paths/`:
- `paths/index.html` — all paths, filterable by difficulty
- `paths/beginner/esc1.html`, `esc4.html`, `esc5.html`
- `paths/intermediate/esc2-schema-v1.html`, `golden-certificate.html`
- `paths/combos/esc7-almost-esc1.html`, `esc4-esc5-on-ca.html`, `esc5-esc5-tinyprivesc.html`
- `paths/advanced/esc8.html`, `esc11.html`

Each attack path page includes a Remediation section. There is no standalone remediation page.

Navigation:
- Sidebar with collapsible Attack Paths section grouped by difficulty.
- Top bar holds theme toggle and search.
- Breadcrumb or page title indicates current location.
