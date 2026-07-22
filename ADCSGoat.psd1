@{
    AliasesToExport=@('*')
    Author='Jake Hildreth'
    CmdletsToExport=@()
    CompanyName='Gilmour Technologies Ltd'
    CompatiblePSEditions=@('Desktop',        'Core')
    Copyright='(c) 2025 - 2026 Jake Hildreth, Gilmour Technologies Ltd. All rights reserved.'
    Description='A tiny module built for a single purpose: building a small and very insecure AD CS lab.'
    FunctionsToExport=@('*')
    GUID='9febf038-d9cc-40d2-915a-5a51f26b78e3'
    ModuleVersion='2026.7.220804'
    PowerShellVersion='5.1'
    PrivateData=@{
        PSData=@{
            ExternalModuleDependencies=@('Microsoft.PowerShell.Utility',                'Microsoft.PowerShell.Management',                'Microsoft.PowerShell.Security')
            ProjectUri='https://github.com/jakehildreth/ADCSGoat'
            RequireLicenseAcceptance=$false
            Tags=@('ADCS',                'ADCSGoat',                'CertificateServices',                'PKI',                'Lab',                'ActiveDirectory',                'Windows')
        }
    }
    RequiredModules=@('Microsoft.PowerShell.Utility',        'Microsoft.PowerShell.Management',        'Microsoft.PowerShell.Security')
    RootModule='ADCSGoat.psm1'
    VariablesToExport='*'
}
