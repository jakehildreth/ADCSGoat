## Question

Should ADCSGoat's module files move from the `./ADCSGoat/` subdirectory to the repo root (matching Locksmith2/Stepper), or stay in the subdirectory?

Locksmith2 and Stepper keep the `.psd1`, `.psm1`, `Public/`, and `Private/` directories at the repo root. ADCSGoat currently nests these under `./ADCSGoat/`. PSPublishModule can work with either layout, but the reference pattern and default PSPublishModule assumptions favor root.

## Answer

Move ADCSGoat's module files (`ADCSGoat.psd1`, `ADCSGoat.psm1`, `Public/`, `Private/`) to the repo root, matching the Locksmith2/Stepper pattern. The existing `docs/`, `tests/`, and `Research/` directories remain in place for now.

Type: grilling
Status: resolved
