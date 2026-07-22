# Spec: ADCSGoat HTML Site

## Problem Statement

The ADCSGoat lab exposes students to multiple Active Directory Certificate Services attack paths, but there is no single, easy-to-navigate, offline reference that explains each path, the required setup, the tools, and how to remediate the underlying misconfiguration. Students need a self-contained educational site they can open from the lab module itself without relying on internet access or heavy JavaScript frameworks.

## Solution

Build a plain-HTML/CSS/JS static site embedded in the `ADCSGoat` PowerShell module. The site is distributed offline and opened via a module cmdlet. It covers lab setup, prerequisites, recommended tools, every ADCSGoat attack path, and per-path remediation guidance. The design is minimal-JS, accessible, theme-switchable, and printable.

## User Stories

1. As a student, I want to open the ADCSGoat site from the PowerShell module, so that I can access the lab documentation without internet access.
2. As a student, I want a clear overview page, so that I can understand how the lab is organized and where to start.
3. As a student, I want setup and prerequisite pages, so that I can prepare my environment before attempting attack paths.
4. As a student, I want a tools page, so that I know which tools are used in the lab and how to get them.
5. As a student, I want attack paths grouped by difficulty, so that I can choose a path matched to my skill level.
6. As a beginner student, I want to start with ESC1, ESC4, or ESC5, so that I can learn foundational AD CS attacks.
7. As an intermediate student, I want to tackle ESC2 + Schema V1 or Golden Certificate, so that I can build on the basics.
8. As an advanced student, I want to attempt ESC8 or ESC11, so that I can learn network-level and protocol-level attacks.
9. As a student, I want combo paths like ESC7 + Almost ESC1, so that I can understand how multiple vulnerabilities chain together.
10. As a student, I want each path page to explain the misconfiguration, so that I understand why the attack works.
11. As a student, I want each path page to list prerequisites, so that I know what accounts, access, and tools I need before starting.
12. As a student, I want numbered attack steps with PowerShell command examples, so that I can follow the exploitation flow in my own lab.
13. As a student, I want to know what a successful attack looks like, so that I can verify I executed the path correctly.
14. As a student, I want remediation guidance on every path page, so that I can fix or prevent the misconfiguration.
15. As a student, I want both CLI and GUI remediation steps, so that I can choose the remediation method that fits my workflow.
16. As a student, I want detection ideas for each path, so that I know what events and logs defenders should monitor.
17. As a student, I want references to original research and Microsoft docs, so that I can dig deeper after completing the path.
18. As a student, I want previous/next links between paths, so that I can move through the lab in a logical order.
19. As a student using a screen reader, I want semantic HTML and landmarks, so that I can navigate the site efficiently.
20. As a student who prefers dark mode, I want a theme toggle that persists my choice, so that the site is comfortable to read.
21. As a student on a mobile device, I want a collapsible sidebar, so that I can navigate the site on a small screen.
22. As a student, I want difficulty badges that use both shape and color, so that I can understand difficulty even if I cannot perceive color.
23. As an author, I want a reusable content template for every attack path, so that new paths are consistent and easy to add.
24. As an author, I want diagrams generated from text-based Mermaid sources, so that I can update attack-flow visuals without touching SVG coordinates.
25. As a maintainer, I want the HTML bundle to ship inside the PowerShell module, so that students get the site automatically when they install the module.
26. As a maintainer, I want build scripts excluded from the published module, so that packaging stays clean and small.
27. As a maintainer, I want all command examples in PowerShell, so that the lab aligns with the module's ecosystem.
28. As a maintainer, I want a Berkeley Mono font fallback, so that the site works before the licensed font files are added.
29. As a maintainer, I want minimal JavaScript, so that the site is easy to maintain and quick to load.
30. As a maintainer, I want the site to work from disk via `file://`, so that no web server is required.

## Implementation Decisions

- **Distribution:** The site ships as static HTML/CSS/JS assets inside the `ADCSGoat` PowerShell module, under `Assets/`. PSPublishModule 2.0.27 includes this folder by default.
- **Module cmdlets:**
  - `Start-ADCSGoatSite` resolves the path to `Assets/index.html` relative to the module and opens it in the default browser.
  - `Get-ADCSGoatSitePath` returns the full path to the site folder for users who want to open it manually.
- **Page hierarchy:** Top-level pages are `index.html`, `setup.html`, `prerequisites.html`, `tools.html`, and `references.html`. Attack paths live under `paths/` grouped by `beginner/`, `intermediate/`, `combos/`, and `advanced/`.
- **Content template:** Every attack path page contains: Header (ESC ID, title, difficulty badge, tagline, prerequisites summary), The Mistake, Prerequisites table, Attack Steps with PowerShell commands, Expected Result, Remediation (Root Cause + CLI/GUI Fix Steps), Detection Ideas, References, and Previous/Next navigation.
- **Tech stack:** Plain HTML, CSS custom properties, and minimal JavaScript. No frameworks, no build step for the site itself.
- **Theming:** CSS custom properties for light and dark modes; default follows `prefers-color-scheme`; manual toggle persists to `localStorage`; inline sync script in `<head>` prevents a theme flash on load.
- **Font:** Berkeley Mono loaded from `Assets/fonts/BerkeleyMono-*.woff2` for four cuts (Regular, Bold, Italic, Bold Italic), with a system-monospace fallback stack. Font files are supplied by the author after licensing.
- **Sidebar navigation:** Always visible on desktop; mobile toggle implemented with a CSS-only hidden checkbox and `:checked` selector, avoiding JavaScript.
- **Difficulty badges:** Ski-slope style: green circle for Beginner, blue square for Intermediate, black diamond for Combos, double black diamond for Advanced. Each badge uses an inline SVG shape plus visible text label.
- **Interactivity:** Native `<details>`/`<summary>` elements for expandable sections. No global search, no difficulty filters, no progress checkboxes, and no print-handling JavaScript.
- **JavaScript footprint:** Only the theme toggle (sync script + toggle handler). Everything else is CSS-only or native HTML.
- **Diagrams:** Mermaid CLI renders `.mmd` source files to static `.svg` files at build time. Only generated `.svg` files ship in `Assets/diagrams/`; source `.mmd` files and the build script live in `Build/` and are excluded from the module package.
- **Diagram semantics:** Four color classes encode meaning across all diagrams: red for attacker, amber for vulnerable component, blue for action, green for result.
- **Accessibility:** Semantic HTML landmarks, unique page titles, skip link, strict heading hierarchy, visible `:focus-visible` indicators, labels on all inputs, and color-contrast compliance in both themes. Difficulty badges and links never rely on color alone.
- **Print CSS:** Hides navigation and theme chrome, forces readable typography, avoids page breaks inside code blocks and tables, and appends external link URLs. No JavaScript is used to expand `<details>` for print.
- **Build maintenance:** `Build/Build-Diagrams.ps1` regenerates SVG diagrams from Mermaid source. No search-index generator is required because search was removed.
- **Source of truth:** Attack path content is derived from the existing `ADCSGoat.md` document.

## Testing Decisions

- **PowerShell module tests (Pester):** Verify that `Start-ADCSGoatSite` resolves the correct `Assets/index.html` path and invokes the default browser; verify that `Get-ADCSGoatSitePath` returns an existing directory.
- **HTML/CSS validation:** Run the generated HTML and CSS through validators to catch malformed markup or invalid rules.
- **Accessibility audit:** Use axe-core or Lighthouse to verify contrast ratios, landmark presence, heading hierarchy, focus visibility, and label associations.
- **Link integrity:** Scan all internal links, image references, and diagram SVG paths to confirm they resolve within the `Assets/` tree.
- **Offline smoke test:** Open `Assets/index.html` directly via `file://` with no network connection and confirm every page and diagram loads.
- **Theme toggle test:** Verify the theme switcher changes the active theme and that the choice persists across page reloads via `localStorage`.
- **Packaging test:** Build the module with PSPublishModule and assert that `Assets/` is present and `Build/` is absent from the produced package.

## Out of Scope

- Actual content authoring for every attack path beyond the template and a representative example page.
- Online hosting or CI/CD pipelines.
- Backend services or dynamic features.
- Copy-to-clipboard buttons, live search, difficulty filters, or progress tracking.
- Protocol-level sequence diagrams (e.g., PKINIT handshake) unless added later as a separate effort.
- Video, interactive terminals, or embedded lab VMs.

## Further Notes

- The site intentionally avoids JavaScript for navigation and interactivity to keep maintenance low and offline reliability high.
- The `Build/` directory is excluded from the PSPublishModule package; only the generated `Assets/` bundle ships to students.
- Diagram `.mmd` sources should be committed to the repository for maintainability, but only the rendered `.svg` files are required at runtime.
- The author must separately license and add Berkeley Mono font files to `Assets/fonts/`; until then, the site renders cleanly with system monospace fonts.
