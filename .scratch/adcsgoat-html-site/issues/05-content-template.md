## Question

What is the reusable content template for each attack path page (sections, metadata, examples, command blocks, remediation)?

Type: prototype
Status: resolved

## Answer

Every attack path page follows a single reusable template:

1. **Header** — ESC identifier, path title, ski-slope difficulty badge, scenario tagline, prerequisites summary.
2. **The Mistake** — misconfiguration that enables the path.
3. **Prerequisites** — table, with links to the global Tools page.
4. **Attack Steps** — numbered steps; PowerShell command blocks in static `<pre><code>`; inline `#` comments; explanatory text before each block.
5. **Expected Result** — what success looks like.
6. **Remediation** — Root Cause paragraph; numbered Fix Steps with both CLI and GUI approaches.
7. **Detection Ideas** — separate section with event IDs/logs to monitor.
8. **References** — flat bullet list of links.
9. **Previous / Next** — footer navigation between paths, ordered by difficulty.

Constraints carried from earlier tickets:
- All commands are PowerShell.
- No copy-to-clipboard buttons (minimal JS).
- Expandable sections use native `<details>`/`<summary>`.
- Difficulty badge uses inline SVG + visible label.
