# Plan ADCSGoat deployment defaults and installation dependencies

Archived local record. Continue in [Plan ADCSGoat deployment defaults and installation dependencies](https://github.com/jakehildreth/ADCSGoat/issues/15), the canonical GitHub map.

Label: wayfinder:map

## Destination

A decision-ready implementation plan for three changes: default to Windows Server 2025 Desktop Experience, offer editable per-VM memory and CPU suggestions during `Deploy-AGInfrastructure`, and make `Install-Module ADCSGoat` install AutomatedLab and PSFramework.

## Notes

- Planning only. Do not change production code or publish packages during this effort.
- Follow `/wayfinder`, `/grilling`, and `/domain-modeling`. Use `/research` for external facts.
- Use GitHub Issues and native sub-issues as described in `Docs/agents/issue-tracker.md`. These local files are archived records.
- Preserve the existing DC, CA, and PAW topology and Hyper-V deployment engine.
- Preserve Datacenter unless the Server 2025 investigation identifies a reason to revisit the edition.
- Confirmed resource preferences are recorded in [Define editable per-VM resource suggestions](issues/02-editable-vm-resources.md).
- Research reports are preserved as linked comments on the corresponding GitHub research tickets. Do not commit, switch branches, install dependencies, provision VMs, or publish to the Gallery.
- Each implementation plan must identify its observable acceptance checks. A real Hyper-V deployment requires a suitable Windows host and Server 2025 media; local inspection alone cannot prove guest deployment.

## Decisions so far

- [Declare AutomatedLab and PSFramework installation dependencies](issues/03-installation-dependencies.md) — use direct required-module metadata in source and build; account for whole-module dependency import effects.
- [Choose a Server 2025 Desktop Experience default](issues/01-server-2025-default.md) — source-backed Datacenter Desktop Experience identifier; matching media and runtime/scenario proof remain release gates.

## Not yet specified

None beyond the questions in the child tickets. Add new questions only when the current frontier exposes them.

## Out of scope

- Implementing the three changes in this planning session.
- Adding VM roles, host-adaptive sizing, or new deployment engines.
- Changing PSCertutil vendoring or fixing unrelated build and help defects.
- Redesigning vulnerability scenarios. Record any Server 2025 compatibility risk before deciding whether separate work is needed.
