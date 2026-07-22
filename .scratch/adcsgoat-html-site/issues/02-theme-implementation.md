## Question

How should the light/dark theme switch and Berkeley Mono font be implemented in plain HTML/CSS/JS for offline use?

Type: prototype
Status: resolved

## Answer

Implement with CSS custom properties, a manual toggle that overrides `prefers-color-scheme`, and Berkeley Mono loaded from local font files with a system-monospace fallback.

Decisions:
- Load Berkeley Mono from `fonts/BerkeleyMono-*.woff2`; fallback stack is `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`.
- Reference all four cuts: Regular, Bold, Italic, Bold Italic.
- Default to OS preference via `prefers-color-scheme`; manual toggle stores preference in `localStorage`.
- Inline sync script in `<head>` reads `localStorage` and sets `data-theme` before first paint to avoid flash.
- Core color tokens: `--bg`, `--bg-surface`, `--text`, `--text-muted`, `--accent`, `--border`, `--focus-ring`.
- Add ski-slope difficulty badge tokens to the theme:
  - Beginner: green circle + "Beginner"
  - Intermediate: blue square + "Intermediate"
  - Combos: black diamond + "Combos"
  - Advanced: double black diamond + "Advanced"
- Badge shapes are inline SVG with `aria-hidden="true"` and visible text labels.
- Toggle button uses `aria-pressed` and updates label dynamically.
