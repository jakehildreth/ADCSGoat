## Question

What is the easiest-to-maintain diagram format for illustrating AD CS attack paths in an offline static site?

Type: research
Status: resolved

## Answer

Use **Mermaid CLI rendered to static SVG at build time**.

Key decisions:
- Author `.mmd` text files (one per attack path) under a `diagrams/` folder.
- Run `mmdc -i esc1.mmd -o esc1.svg --theme base` to generate self-contained SVGs.
- Commit both `.mmd` source and `.svg` output so the site works offline with zero runtime tooling.
- Use semantic `classDef` styles: red=attacker, amber=vulnerable component, blue=action, green=result.
- Embed diagrams with `<img src="esc1.svg" alt="ESC1: prose description">` for accessibility.
- Use a Makefile or npm script to regenerate all diagrams: `make diagrams`.

Alternatives:
- ASCII `<pre>`: acceptable only for inline one-liners, fails WCAG 1.1.1 without workaround.
- Hand-coded SVG: best visual quality but painful maintenance.
- Excalidraw SVG: good for stable conceptual intro diagrams, not for 8+ evolving paths.
- PlantUML: justified only if adding protocol sequence diagrams and avoiding Node.js.

Full evaluation report captured in this ticket.
