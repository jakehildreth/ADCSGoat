# Choose a Server 2025 Desktop Experience default

Archived local record. Canonical ticket: [Choose a Server 2025 Desktop Experience default](https://github.com/jakehildreth/ADCSGoat/issues/16).

Type: research
Label: wayfinder:research
Status: resolved
Parent: [Plan ADCSGoat deployment defaults and installation dependencies](../map.md)

## Question

What exact AutomatedLab operating-system identifier and compatibility requirements should replace the current `Windows Server 2022 Datacenter (Desktop Experience)` default?

Investigate primary sources for Server 2025 Desktop Experience image naming, AutomatedLab support, and guest memory requirements. Identify whether Server 2025 introduces a relevant risk to the existing ESC scenarios. Distinguish a new Server 2025 limitation from patch behavior that also affects Server 2022. Do not silently expand this effort into vulnerability redesign.

## Repository evidence

- `Public/Deploy-AGInfrastructure.ps1`: the common operating-system default applies to DC, CA, and PAW. Machine definitions use RootDC and CaRoot; PAW receives RSAT.
- `Public/Install-ADCSGoat.ps1` and `Private/Template/`: current vulnerability configuration.
- `README.md`: advertised scenarios and deployment flow.

## Acceptance for the decision

- Cite the image identifier evidence, or explicitly state that local media enumeration is still required.
- State compatible AutomatedLab versions only where primary-source evidence supports them.
- Record the memory baseline and any relevant scenario risk.
- Describe a real deployment smoke check and its host/media prerequisites without claiming it ran.

## Answer

Use `Windows Server 2025 Datacenter (Desktop Experience)` as the proposed common default for DC, CA, and PAW. AutomatedLab's tagged 5.55.0 and 5.61.0 product-key catalogs contain that exact identifier. The distinct `Windows Server 2025 Datacenter Evaluation (Desktop Experience)` identifier must match Evaluation media; do not silently treat the names as interchangeable.

AutomatedLab 5.55.0 documents GA Server 2025 product keys, but that milestone is not a tested minimum for ADCSGoat. Locally available AutomatedLab 5.61.0 is a candidate for later runtime proof, not a passed compatibility check. Do not add an unproven version floor.

Microsoft specifies 2 GB minimum and recommends 4 GB for Server 2025 Desktop Experience. This supports the confirmed starting suggestions in the resource ticket. Guest resources, host capacity, actual image enumeration, module imports, and role deployment still need a suitable host/media smoke.

Keep vulnerability configuration separate from demonstrated authentication or relay success. Strong certificate-mapping restrictions also affect patched Server 2022. Server 2025 additionally changes relevant LDAP, PKINIT, NTLMv1, and SMB behavior. Record client, transport, patch level, and actual outcomes; do not quietly weaken security policies or redesign scenarios as part of changing the default.

Acceptance: enumerate the actual ISO name/index/version/path, deploy the three intended Desktop Experience guests, observe effective Hyper-V resources, verify AD DS/CA/RSAT operation, and observe the existing lab configuration and representative enrollment/authentication behavior. No such deployment or media enumeration ran during planning.

Evidence, image/version distinctions, scenario caveats, and full smoke criteria: [Windows Server 2025 default: research and decision evidence](../research/server-2025.md).
