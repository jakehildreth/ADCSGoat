# Domain Docs

This repo uses a single context. Its domain vocabulary lives in root `CONTEXT.md`; architecture decisions live in `Docs/adr/`.

`CONTEXT.md` is this repo's name for the glossary that upstream skills call `GLOSSARY.md`. Use the repo convention when those skills read or write domain terms.

## Before exploring

- Read root `CONTEXT.md`, if it exists.
- Read ADRs in `Docs/adr/` that cover the area being changed.

If these files do not exist, proceed silently. Do not suggest creating them upfront. `/domain-modeling` creates them lazily when terms or decisions are resolved.

## Use the domain vocabulary

When naming a domain concept in an issue, proposal, hypothesis, or test, use the term defined in `CONTEXT.md`. Respect any synonyms it explicitly excludes.

If a needed concept is absent, reconsider whether the project uses it. If it is a real gap, note it for `/domain-modeling`.

## Flag ADR conflicts

If a proposal contradicts an existing ADR, name the ADR and explain why the decision should be reopened. Do not override it silently.
