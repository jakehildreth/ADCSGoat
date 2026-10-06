# Windows Server 2025 default: research and decision evidence

Archived local record. Published report: [Windows Server 2025 default: research and decision evidence](https://github.com/jakehildreth/ADCSGoat/issues/16#issuecomment-5968932733). Continue discussion in [Choose a Server 2025 Desktop Experience default](https://github.com/jakehildreth/ADCSGoat/issues/16).

Research date: 2026-10-03. Scope: [Server 2025 default ticket](../issues/01-server-2025-default.md). Planning only; no production changes.

## Decision recommendation

**Propose `Windows Server 2025 Datacenter (Desktop Experience)` as the common default for DC, CA, and PAW, conditional on a matching local media enumeration and the deployment smoke below.** AutomatedLab's tagged product-key catalog explicitly contains this identifier, including in releases 5.55.0 and 5.61.0. It also contains the distinct identifier `Windows Server 2025 Datacenter Evaluation (Desktop Experience)`. These are not interchangeable names. Preserve Datacenter, Desktop Experience, Hyper-V, and the existing topology; there is no evidence here requiring an edition or role change. [S1], [S2], [R1]

Use the human-selected **dynamic-memory suggestions of 2 GB minimum / 4 GB startup / 4 GB maximum and 2 vCPUs for each VM**, not the current 512 MB / 1 GB startup profile. Microsoft specifies 2 GB minimum and recommends 4 GB for Server 2025 Desktop Experience. This supports the starting suggestion, not a guarantee that every role/workload fits in 4 GB. Prompt fields and scripted overrides remain the separate human decision in the resource ticket. [S5], [R1], [R4]

**Do not call the switch proven compatible or promise that every advertised ESC is exploitable.** Feature-support evidence exists, but local media, actual deployment, package imports, and scenario outcomes remain unverified. Strong certificate mapping restrictions also affect patched Server 2022; returning to Server 2022 alone does not restore old weak-mapping attack paths. [S6], [S7]

## Evidence actually gathered

- Read the named deployment function, vulnerability-install function, README, and relevant template properties. Their existing default affects all three VMs; the definitions use `RootDC` and `CaRoot`, and PAW receives RSAT. The installer imports six XML templates and changes the CA flags for ESC6 and ESC11. [R1], [R2], [R3]
- Read linked first-party AutomatedLab source/history and Microsoft documentation/specifications. Source facts are distinguished below from recommendations and `[INFERENCE]` statements.
- Read the already available local manifest at `C:/Program Files/WindowsPowerShell/Modules/AutomatedLab/5.61.0/AutomatedLab.psd1`: `ModuleVersion = '5.61.0'`, `CompatiblePSEditions = 'Core', 'Desktop'`, `PowerShellVersion = '5.1'`. This proves manifest availability only. [R5]
- **Not performed:** module import or installation, package compatibility check, `Get-LabAvailableOperatingSystem`, ISO mounting/enumeration, Hyper-V readiness check, VM provisioning, deployment smoke, enrollment, certificate authentication, builds, tests, lint, or formatting.

## Image identifier and AutomatedLab version evidence

| Evidence | What it supports | What it does not establish |
| --- | --- | --- |
| Tagged `Assets/ProductKeys.xml`, 5.55.0 and 5.61.0, includes `Windows Server 2025 Datacenter (Desktop Experience)` and the separate Evaluation name. | Exact identifiers recognized by AutomatedLab's product-key catalog. [S1] | Which image name is present in this host's ISO, a successful unattended deployment, or licensing/activation entitlement. |
| Changelog 5.51.0, 2024-03-18: “Added support and product key for Windows Server 2025 Insider Preview.” | Explicit support milestone for **Insider Preview**. [S2] | A suitable GA Server 2025 minimum version. |
| Changelog 5.55.0, 2024-12-31: “Added product keys for Windows Server 2025.” | Earliest GA-oriented key milestone documented in the inspected changelog; 5.55.0 is a defensible feature-evidence floor. [S2] | A tested minimum for ADCSGoat's RootDC/CaRoot/RSAT combination, or blanket compatibility of all releases above it. |
| Local 5.61.0 manifest and upstream 5.61.0 catalog. | A concrete, available candidate version for the future smoke. [R5], [S1] | That its required component modules load successfully, are aligned, or work with this media/host. |
| AutomatedLab issue #1687: an evaluation-media enumeration uses the Evaluation identifier; a maintainer identifies stale `ProductKeys.xml` after upgrades, and the reporter says installing 5.56.1 by MSI resolved their example. | First-hand evidence of distinct media naming and a historical cached-key prerequisite. [S3] | A reproducible ADCSGoat compatibility test or a reason to require 5.56.1 rather than 5.55.0. |

**Conservative version position:** do not assert a tested minimum. Record 5.55.0 as the documented GA-key milestone and 5.61.0 as the currently available candidate for deployment evidence. The commented `#requires ... AutomatedLab -Version 7` in the deployment function is not an active requirement and is not support evidence. [S2], [R1], [R5]

**Local media enumeration remains required.** AutomatedLab documents `Get-LabAvailableOperatingSystem -Path` for the actual ISO folder and exposes the operating-system name, image index, version, and ISO path. Capture those values for the selected Datacenter Desktop Experience image before committing a default/media contract. Do not infer the local image name from a download filename, a catalog version field, or Microsoft's generic setup-option wording. [S4], [S1], [S8]

The non-Evaluation string is the proposed replacement for the existing non-Evaluation Server 2022 default. If the supplied media only enumerates the Evaluation string, explicitly choose/document the matching media identifier before deployment; do not silently fall back to Core, Standard, Insider Preview, or another OS. This is a planning decision, not a proposed new media-selection feature. [R1], [S1], [S3]

## Official memory baseline

Microsoft's hardware requirements distinguish the Server 2025 and Server 2022 pivots: [S5]

| Installation option | Server 2025 | Server 2022 |
| --- | --- | --- |
| Desktop Experience | 2 GB RAM minimum; 4 GB recommended | 2 GB RAM minimum |
| Server Core | 2 GB RAM minimum | 1 GB RAM minimum |

The Server 2025 VM setup note warns that a VM with one processor core and 1,024 MB RAM fails installation, with additional RAM potentially needed for customized boot images. That troubleshooting note is **not** justification for a Desktop Experience dynamic-memory minimum below the stated 2 GB. The proposed 4 GB startup avoids that stated 1 GB setup configuration, but installation still requires a real smoke. Microsoft also says actual requirements depend on installed applications/features and recommends test deployments for workload sizing. [S5]

The user-selected three-VM profile has 12 GB aggregate guest startup allocation, before host/Hyper-V overhead and other workloads. **[INFERENCE: arithmetic, not an official host minimum.]** The 4 GB maximum is editable and should not be described as a proven capacity ceiling for AD DS, AD CS, and PAW workloads. [R4], [S5]

## Existing scenarios: configuration versus usable attack path

### Shared patch behavior, not a Server 2025-only restriction

Microsoft KB5014754 documents the following for affected domain controllers, explicitly including Server 2022: May 2022 updates introduced SID-extension/strong-mapping protections; the February 2025 security update moved DCs to Full Enforcement by default; the September 9, 2025 security update removed support for the `StrongCertificateBindingEnforcement` compatibility override. In Full Enforcement, a certificate without an acceptable strong mapping is denied. The same KB describes Schannel weak mappings being disabled by default. This is update-dependent behavior, not merely a calendar switch or a restriction introduced by choosing Server 2025. [S6]

Microsoft's PKINIT specification includes both Server 2022 and Server 2025, specifies SID-based mapping, and says a mismatched SID must fail. It also documents SAN URL SID mapping for Server 2019 and later. Consequently, neither “any SAN can impersonate anyone” nor “all certificate abuse is blocked” is a justified conclusion from the OS version alone. [S7]

| Existing scenario | Repository fact and relevant implication |
| --- | --- |
| **ESC6** | The installer enables `EDITF_ATTRIBUTESUBJECTALTNAME2`. Microsoft describes this as accepting request-supplied SAN values across templates. However, a SAN name change alone does not override an issued certificate's conflicting SID or the KDC's strong-mapping requirements. **[INFERENCE]** Record both the SAN accepted by the CA and the resulting DC mapping outcome; a set CA flag is not proof of arbitrary-account authentication. Patched Server 2022 needs the same distinction. [R2], [S9], [S6], [S7] |
| **ESC9** | `ESC9.xml` has `msPKI-Enrollment-Flag = 524329` (`0x00080029`, containing the `0x00080000` no-security-extension bit). KB5014754 documents that bit as suppressing the SID extension. Omitting it can remain observable even when a name-only authentication attempt is rejected under Full Enforcement. **[INFERENCE]** The globally enabled ESC6 and alternative strong mappings can change combined-scenario behavior, so do not promise or rule out a complete attack path from this flag alone. No compatibility-mode rollback should be quietly added. [R2], [R3f], [S6], [S7] |
| **ESC1 / ESC2** | These XML templates use schema version 2 and `msPKI-Certificate-Name-Flag = 1` (enrollee supplies subject). Server processing rules distinguish supplied-subject templates from directory-built subject templates, including how a requested SID extension is handled. Do not assume every non-ESC9 certificate automatically receives the requester's SID or that old name-only demonstrations still work. Template misconfiguration and final certificate authentication need separate observations. [R3a], [R3b], [S10], [S7] |
| **ESC3 conditions / ESC4** | The installer gives Authenticated Users enrollment on the two ESC3 templates and GenericAll on ESC4. The XML templates retain schema version 2; ESC3c1 has the request-agent EKU, ESC3c2 requires one authorized signature and the request-agent policy. Microsoft continues to document version-2 templates, enrollment-agent misconfiguration, and permissive template ACL risks. **[INFERENCE]** No primary evidence examined requires changing these template definitions solely for Server 2025, but eventual certificate authentication is still subject to mapping/protocol requirements. [R2], [R3c], [R3d], [R3e], [S11], [S9], [S7] |

### ESC11: test the correct enrollment transport

The installer clears `IF_ENFORCEENCRYPTICERTREQUEST`. Microsoft's ESC11 guidance expressly describes **MS-ICPR**: when the flag is enabled, the RPC enrollment interface requires signed/encrypted packet privacy; when not required, the interface is susceptible to relay. MS-ICPR's request specification applies the flag-dependent connection check, and its product-behavior appendix includes both Server 2022 and Server 2025 without a separate Server 2025 exception for this check. **[INFERENCE]** There is no documented Server 2025-only removal of this misconfiguration in the inspected sources, but clearing the flag alone is not a real relay/deployment proof. [R2], [S9], [S12]

Do **not** confuse that endpoint with MS-WCCE's **DCOM** enrollment transport. Microsoft's MS-WCCE product-behavior footnotes 8 and 127 document CVE-2022-37976 packet-privacy enforcement regardless of the flag on applicable patched systems. This is historical patch-related DCOM behavior, not evidence that every MS-ICPR ESC11 path is blocked only on Server 2025. Record the endpoint, transport, authentication protocol, and RPC authentication level used by the smoke. [S13], [S12]

### Genuine Server 2025 changes to observe, without redesigning scenarios

- **PKINIT tooling:** Microsoft's product-behavior appendix states that Server 2025 does not support PKINIT's RFC4556 public-key-encryption key-delivery mode and returns `KRB_ERROR_GENERIC`. This is distinct from an RSA certificate/key being unsupported. **[INFERENCE]** A certificate-authentication client relying on that delivery mode can fail even when issuance/mapping is correct; record the actual client and key-delivery mode instead of diagnosing every failure as a template defect. [S7]
- **Fresh AD deployment/LDAP:** Server 2025 requires LDAP signing by default for new AD deployments; Server 2022 and earlier expose these policies without default server-side enforcement. **[INFERENCE]** Observe successful template creation/ACL updates against the new DC; tools requiring unsigned LDAP can behave differently. Do not disable the policy preemptively. [S14], [R2]
- **Relay/client behavior:** Server 2025 removes NTLMv1 while NTLMv2 remains available. Its SMB client requires outbound SMB signing by default. **[INFERENCE]** Those changes can alter a chosen coercion/relay source or named-pipe path, but they do not establish that NTLMv2 over MS-ICPR/TCP is universally disabled. Keep the source/transport explicit rather than claiming ESC11 is inherently impossible on 2025. [S15], [S16], [S12]

No new ESC scenarios, patch avoidance, security-policy weakening, exploit-tool migration, or template redesign is proposed by this research.

## Unresolved host and media prerequisites

These are **not checked locally** and gate deployment evidence:

1. **Suitable Windows Hyper-V host and privileges:** enabled Hyper-V, administrative execution, virtualization-capable CPU, remoting prerequisites, writable LabSources/VM storage, and enough available RAM/storage for three guests plus the host. AutomatedLab requires local OS DVD ISOs and recommends en-US media and low-latency storage. Server 2025 additionally requires SSE4.2 and POPCNT support visible to the guest. [S17], [S5]
2. **Actual ISO contract:** accessible GA Server 2025 x64 Datacenter Desktop Experience installation media in the configured ISO location; record its exact enumerated name/index/version/path and provenance. Evaluation and non-Evaluation names differ. Evaluation media expires after 180 days and requires internet activation within the first 10 days to avoid automatic shutdown. The product-key catalog is not a license entitlement. [S1], [S3], [S4], [S8], [S18]
3. **Actual dependency/runtime state:** coherent AutomatedLab component versions, successful imports under the chosen PowerShell runtime, and usable current key assets. Historical stale key-cache evidence is a prerequisite to inspect if deployment reports an unknown key, not permission to delete files during this planning effort. Only the 5.61.0 top-level manifest was inspected here. [R5], [S3], [S17]
4. **Existing network assumptions:** the deployment function uses an external switch and adapter selection constrained to DHCP IPv4 with a /24 prefix; it derives the gateway as `.1` and selects unoccupied guest addresses. A future smoke needs that network contract to actually fit the host and a dedicated test segment preventing an intentionally vulnerable domain/CA from exposing production systems. The isolation recommendation is **[INFERENCE: lab safety]**, not a topology change. [R1], [R3]
5. **DC promotion and certificate-authentication readiness:** Server 2025 new forests must use Windows Server 2016 or later functional levels. Verify the installed AutomatedLab RootDC role's effective promotion choice in the deployed lab; this research did not inspect/execute that role. Certificate-authentication observations also require an appropriate DC certificate/trust and the actual selected client. [S16], [S7]
6. **Patch state:** record each guest's OS build and installed cumulative update, rather than treating “2022” or “2025” as a complete security-behavior specification. [S6], [S7], [S13]

## Observable deployment smoke criteria — proposed, not run

Keep infrastructure success, vulnerability-configuration success, and attack-path behavior as separate results. A deployment summary or a registry bit is not sufficient evidence for all three.

1. **Before provisioning:** enumerate the actual ISO directory with `Get-LabAvailableOperatingSystem -Path` (not cache-only); save the selected image's exact name/index/version/path. Record host readiness, PowerShell and AutomatedLab/component versions, guest resource choices, and the intended patch state. Pass only if the selected image matches the agreed Datacenter Desktop Experience identifier. [S4], [S1]
2. **Infrastructure:** a fresh lab contains exactly DC, CA, and PAW on Hyper-V; all three report Server 2025 Datacenter and `InstallationType = Server` rather than Server Core, and expose the desktop shell. `Install-Lab` completes; the DC provides the intended domain/DNS, CA and PAW are domain-joined, and remoting is usable. Confirm the forest/domain levels meet the Server 2025 requirement. [R1], [S8], [S16]
3. **Resources:** Hyper-V reports dynamic memory enabled and each VM's effective minimum/startup/maximum/processor settings match the accepted suggestions or explicit edits. For unchanged suggestions, expect 2/4/4 GB and 2 vCPUs on each VM. Observe installation/reboot completion without setup-memory failure; record any required increase rather than concealing it. [R4], [S5]
4. **Roles/features:** DC AD DS/DNS and CA certificate services are operational; CA is an enterprise CA capable of issuing from AD templates; PAW's requested RSAT features are installed and usable. Validate enterprise-CA status explicitly because only an enterprise CA issues from certificate templates. [R1], [S11]
5. **Configuration:** run `Install-ADCSGoat` in the intended lab administrative context; confirm all six named templates are created and published. Compare their relevant properties to the XML files, including schema version 2, key-size floor, EKUs/application policies, and signature requirements. Confirm Authenticated Users enrollment on all except ESC4 and GenericAll on ESC4. Verify the active CA has the ESC6 edit flag enabled and ESC11 request-encryption flag cleared after any required service reload. Do not substitute a stored flag for an endpoint behavior observation. [R2], [R3a], [R3b], [R3c], [R3d], [R3e], [R3f], [S9]
6. **Representative enrollment/authentication:** retain request/disposition and issued-certificate evidence for supplied-subject/SAN issuance, no-EKU issuance, enrollment-agent/on-behalf-of issuance, and the ESC9 omitted SID extension. Record the complete SAN/SID-extension contents and DC mapping result for the tested certificate-authentication paths. A name-only ESC9 authentication rejection under enforced strong mapping is an expected restriction to report, not proof that the template was never configured. Use a known-supported PKINIT delivery mode and retain relevant KDC event/error evidence. [S6], [S7], [S10]
7. **ESC11 endpoint:** observe MS-ICPR enrollment with the actual chosen transport and RPC authentication level; distinguish it from DCOM/MS-WCCE and from SMB signing on a named-pipe connection. Record whether the flag change affects that endpoint and whether a controlled lab relay demonstration actually succeeds. If only ordinary encrypted enrollment is exercised, explicitly leave relay exploitability unproven. [S9], [S12], [S13], [S16]
8. **2022 comparison, only where a restriction is encountered:** record the same relevant test against a Server 2022 reference at a stated comparable patch level if needed to attribute a failure to the 2025 cutover. Do not demand an extra deployment merely to confirm Microsoft's documented shared patch restriction; do not label a modern patched 2022 failure “new in 2025.” No such comparison occurred here. [S6], [S13]

**Decision gate:** the image string is source-backed; actual media and end-to-end deployment remain open prerequisites. Accept the proposed 2025 default in the implementation plan with those explicit smoke gates and scenario caveats. If the requirement is guaranteed historic attack success rather than preserving the configured misconfigurations, the unverified scenario matrix must become an explicit separate decision—not a silent expansion of this default change.

## Primary sources

[S1]: https://github.com/AutomatedLab/AutomatedLab/blob/5.55.0/Assets/ProductKeys.xml "AutomatedLab 5.55.0 product catalog; also read the same path at tag 5.61.0"
[S2]: https://github.com/AutomatedLab/AutomatedLab/blob/master/CHANGELOG.md "AutomatedLab version history, 5.51.0 / 5.55.0 / 5.61.0"
[S3]: https://github.com/AutomatedLab/AutomatedLab/issues/1687 "AutomatedLab issue: first-hand Evaluation enumeration and maintainer key-cache guidance"
[S4]: https://automatedlab.org/en/latest/AutomatedLabCore/en-us/Get-LabAvailableOperatingSystem/ "AutomatedLab local-media enumeration documentation"
[S5]: https://learn.microsoft.com/en-us/windows-server/get-started/hardware-requirements "Microsoft hardware requirements; Server 2025 and Server 2022 pivots"
[S6]: https://support.microsoft.com/en-us/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-ad2c23b0-15d8-4340-a468-4d4f3b188f16 "Microsoft KB5014754: strong mapping, SID extension, enforcement phases and Schannel"
[S7]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-pkca/eb360f66-86ed-4231-beb9-a66814003513 "Microsoft MS-PKCA product behavior, especially notes 20, 28 and 29; follow SID mapping section"
[S8]: https://learn.microsoft.com/en-us/windows-server/get-started/install-options-server-core-desktop-experience "Microsoft installation options: Desktop Experience versus Core"
[S9]: https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/certificates "Microsoft ESC11, ESC6 and certificate-template posture descriptions"
[S10]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/a1f27ffb-7f74-4fa1-8841-7cde4ba0bcfe "Microsoft CA processing of supplied subject and SID security extension"
[S11]: https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/certificate-template-concepts "Microsoft enterprise CA and template-version concepts"
[S12]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-icpr/0c6f150e-3ead-4006-b37f-ebbf9e2cf2e7 "Microsoft MS-ICPR request flag checks; also read Transport and Product Behavior"
[S13]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/c8bec234-0a53-4a7c-859d-2bb7b2537da5 "Microsoft MS-WCCE product behavior: CVE-2022-37976 packet-privacy footnotes 8 and 127"
[S14]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/ldap-signing "Microsoft version-specific LDAP signing defaults"
[S15]: https://learn.microsoft.com/en-us/windows-server/get-started/removed-deprecated-features-windows-server "Microsoft Server 2025 NTLMv1 removal and NTLMv2 availability"
[S16]: https://learn.microsoft.com/en-us/windows-server/get-started/whats-new-windows-server-2025 "Microsoft Server 2025 functional levels and outbound SMB signing"
[S17]: https://automatedlab.org/en/latest/ "AutomatedLab host, runtime, privilege, ISO and storage requirements"
[S18]: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025 "Microsoft evaluation media options, expiry and activation requirements"
[R1]: ../../../Public/Deploy-AGInfrastructure.ps1 "Repository deployment function, especially lines 170–190"
[R2]: ../../../Public/Install-ADCSGoat.ps1 "Repository template creation, ACLs, CA flags and publication"
[R3]: ../../../README.md "Repository advertised scenarios and deployment flow"
[R3a]: ../../../Private/Template/ESC1.xml "Repository ESC1 template"
[R3b]: ../../../Private/Template/ESC2.xml "Repository ESC2 template"
[R3c]: ../../../Private/Template/ESC3c1.xml "Repository enrollment-agent template"
[R3d]: ../../../Private/Template/ESC3c2.xml "Repository on-behalf-of template"
[R3e]: ../../../Private/Template/ESC4.xml "Repository ESC4 template"
[R3f]: ../../../Private/Template/ESC9.xml "Repository no-security-extension template"
[R4]: ../issues/02-editable-vm-resources.md "Human-selected editable dynamic-memory suggestions"
[R5]: file:///C:/Program%20Files/WindowsPowerShell/Modules/AutomatedLab/5.61.0/AutomatedLab.psd1 "Inspected local AutomatedLab manifest; availability only"

Additional directly read protocol sections: [MS-PKCA SID mapping](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-pkca/e8fd2c1d-50d3-493a-9b58-5e453850c567), [MS-ICPR transport](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-icpr/9f0b251b-c722-4851-9a45-4e912660b458), [MS-ICPR product behavior](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-icpr/e0df83f8-97ce-4744-bebc-041ed3b1e80f), [MS-WCCE DCOM transport](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/43af938c-071d-4568-b1a3-7ed75a953012), [MS-WCCE SID extension](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/e563cff8-1af6-4e6f-a655-7571ca482e71), and [AutomatedLab 5.61.0 product catalog](https://github.com/AutomatedLab/AutomatedLab/blob/5.61.0/Assets/ProductKeys.xml).
