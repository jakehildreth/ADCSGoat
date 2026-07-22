# 09 — Rearrange repo layout for PSPublishModule

**What to build:** Move the module files from the nested `ADCSGoat/` directory to the repo root, and rename the `tests/` and `docs/` directories to `Tests/` and `Docs/` so the repository layout matches the Locksmith2/Stepper reference pattern.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `ADCSGoat.psd1`, `ADCSGoat.psm1`, `Public/`, and `Private/` live at the repo root.
- [ ] The `tests/` directory is renamed to `Tests/` (case-sensitive git move).
- [ ] The `docs/` directory is renamed to `Docs/` (case-sensitive git move).
- [ ] Any references inside the repo that still point to the old nested `ADCSGoat/` path are updated.
- [ ] The existing `en-US/` help files remain inside `Docs/en-US/`.
