## Question

What is the minimal-JS approach for sidebar nav, difficulty filters, search, expandable details, and progress checkboxes?

Type: prototype
Status: resolved

## Answer

Keep interactivity minimal. The only JavaScript is the theme toggle (persists to `localStorage` and avoids flash with an inline sync script).

Decisions:
- **Sidebar nav:** always visible on desktop; collapsible on mobile via a CSS-only hidden checkbox + `:checked` selector (no JS).
- **Difficulty filters:** removed — sidebar grouping by difficulty is sufficient.
- **Search:** removed entirely — navigation plus the paths listing page provides adequate wayfinding.
- **Expandable details:** native `<details>`/`<summary>` elements for Exploit Steps, Remediation, and similar sections.
- **Progress checkboxes:** removed to eliminate JS and maintenance.
- **No print JS:** no force-expand script; print CSS from ticket 07 remains as pure CSS only.

Result: theme toggle is the only JS on the site.
