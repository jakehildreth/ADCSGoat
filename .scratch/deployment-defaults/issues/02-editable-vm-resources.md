# Define editable per-VM resource suggestions

Archived local record. Continue in [Define editable per-VM resource suggestions](https://github.com/jakehildreth/ADCSGoat/issues/17), the canonical open decision ticket.

Type: grilling
Label: wayfinder:grilling
Status: open
Parent: [Plan ADCSGoat deployment defaults and installation dependencies](../map.md)

## Question

What exact prompt and noninteractive contract should `Deploy-AGInfrastructure` use for editable per-VM memory and CPU suggestions?

## Confirmed preferences

The user selected these during charting:

- Offer editable suggestions for DC, CA, and PAW. Pressing Enter accepts the suggested value.
- Keep dynamic memory rather than switching to fixed memory.
- Initial suggested profile for each VM: 2 GB minimum RAM, 4 GB startup RAM, 4 GB maximum RAM, and 2 vCPUs. These are starting suggestions, not locked allocations.

## Decisions still needed

- Which values does each prompt edit: startup memory and CPUs only, or minimum/startup/maximum memory and CPUs?
- If the user edits startup memory, how are the dynamic-memory bounds selected? Maintain `minimum <= startup <= maximum` without discarding the user's choices.
- How should scripted callers supply per-VM overrides and avoid prompts? The current custom `-Confirm` switch bypasses the final deployment confirmation; decide its relationship to the new resource prompts explicitly.
- Where does the final configuration show effective allocations before deployment?

## Repository evidence

`Public/Deploy-AGInfrastructure.ps1` currently assigns all three VMs the same common defaults: 512 MB minimum, 1 GB startup, 4 GB maximum, and 2 processors. It displays network settings before confirmation but not resource allocations.

## Acceptance for the decision

- Record a prompt example, units, empty-input behavior, invalid-input behavior, and the dynamic-memory invariant.
- Record a scripted invocation with per-VM overrides and no input requests.
- Preserve existing deployment confirmation behavior unless the user explicitly chooses otherwise.
- Define behavior checks for an accepted default, an edited value, invalid input, and noninteractive execution. Do not test incidental wording.
