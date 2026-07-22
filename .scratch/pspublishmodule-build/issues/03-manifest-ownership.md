## Question

Should the module manifest remain hand-maintained, or should PSPublishModule own/generate it during build?

The reference repos keep a root `.psd1` file, but `Build-Module.ps1` defines the authoritative manifest inside `New-ConfigurationManifest`. ADCSGoat's current manifest has extensive comments and manual settings.

## Answer

Let PSPublishModule own the manifest. `Build-Module.ps1` will define the authoritative metadata via `New-ConfigurationManifest`, and the root `ADCSGoat.psd1` becomes build output. Module metadata (GUID, author, description, tags, dependencies, version) moves into `Build-Module.ps1`.

Type: grilling
Status: resolved
