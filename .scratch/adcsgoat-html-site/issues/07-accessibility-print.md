## Question

What accessibility and print-styling requirements must the site meet, and how do we satisfy them without bloating the build?

Type: research
Status: resolved

## Answer

Use semantic HTML plus minimal ARIA, CSS custom properties for light/dark themes, and a small inline script to persist theme preference before first paint. Total JS footprint for a11y/interactivity is ~55 lines, no dependencies.

Key decisions:
- Semantic HTML first (`<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`, proper heading hierarchy, `<label>` for inputs).
- Native widgets where possible: `<details>`/`<summary>`, checkboxes, `<button>`.
- Focus indicator: `outline: 3px solid` with `outline-offset: 2px`; never suppress focus.
- Color contrast ≥ 4.5:1 for body text and ≥ 3:1 for UI/focus in both themes.
- Theme system: `prefers-color-scheme` as default, `data-theme` attribute for manual override, `localStorage` persistence via inline sync script in `<head>` to avoid flash.
- Print CSS: hide sidebar/nav/search/filters/theme toggle; force-expand `<details>` with ~10 lines of JS on `beforeprint`/`afterprint`; add `break-after: avoid` on headings, `break-inside: avoid` on code blocks/tables; append URL for external links.

Full report and sample CSS/JS captured in this ticket.
