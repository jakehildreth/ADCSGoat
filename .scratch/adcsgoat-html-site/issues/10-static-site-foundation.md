# 10 — Static site foundation

**What to build:** Establish the HTML/CSS/JS foundation for the embedded site. A student can open `Assets/index.html` from disk, see the layout, switch themes, and use the sidebar on both desktop and mobile.

**Blocked by:** 09 — Module scaffold and cmdlets

**Status:** ready-for-agent

- [ ] `Assets/index.html` exists with semantic landmarks, skip link, and mobile sidebar markup.
- [ ] `Assets/css/style.css` defines CSS custom properties for light/dark themes and applies them to layout, typography, and focus states.
- [ ] `Assets/js/theme.js` implements the manual theme toggle and persists the choice to `localStorage`.
- [ ] An inline sync script in `index.html` reads `localStorage` before first paint to prevent theme flash.
- [ ] Mobile sidebar toggle works via CSS-only hidden checkbox and `:checked` selector.
- [ ] Berkeley Mono font-face declarations exist for Regular/Bold/Italic/Bold Italic with a system-monospace fallback.
