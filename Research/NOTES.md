* Script by Marc-Andre to create cert templates programmatically: https://github.com/Devolutions/devolutions-labs/blob/master/powershell/scripts/New-CertificateTemplate.ps1

* API called by MA's script: https://github.com/tpn/winsdk-10/blob/master/Include/10.0.16299.0/um/certca.h#L2134

* FileTime description: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/2c57429b-fdd4-488f-b5fc-9e4cf020fcdf

```powershell
[System.Security.Cryptography.Oid]::FromFriendlyName("Server Authentication", [System.Security.Cryptography.OidGroup]::EnhancedKeyUsage);
```

![An Image Showing How To Create a Flags Enum](image.png)
```powershell
[Flags()] enum EnrollmentFlags
{
    INCLUDE_SYMMETRIC_ALGORITHMS = 0x01
    PEND_ALL_REQUESTS = 0x02
    PUBLISH_TO_KRA_CONTAINER = 0x04
    PUBLISH_TO_DS = 0x08
}
[EnrollmentFlags](9)
```

New-LocksmithLab
1. ~~Write script using AL~~
1. Modularize https://gist.github.com/jakehildreth/d7e00d2d342896caab3d27d0344280f7

~~Preparation:~~
1. ~~Create example templates using MA's script.~~
    ~~* Naming convention: Example-[VulnType]-[AdditionalInfo]~~
1. ~~Manually modify example templates as needed.~~
1. ~~Create blank template object using scripted New-ADObject.~~
    ~~* Naming convention: [VulnType]-[AdditionalInfo]~~
1. ~~Capture differences between example and blank templates and export to CliXML.~~
    ~~* Naming convention: [VulnType]-[AdditionalInfo].xml~~

Deploy:
1. Create blank template object using scripted New-ADObject using naming convention: [VulnType]-[AdditionalInfo]
    * ESC1
    * ESC2
    * ESC3c1
    * ESC3c2
    * ESC4
    * ESC9
1. Grant Authenticated Users `Enroll` on new template objects except ESC4 template.
1. Grant Authenticated Users `GenericAll` on ESC4 template.
1. Import difference object from CliXML.
1. Apply difference object to blank template object.
1. Apply misconfigurations to CA:
    * ESC6
    * ESC7 (ACLs?)
    * ESC8 (Enable Windows Feature?)
    * ESC11
