# Hashtable containing vulnerable config is defined in .ps1 files
# This snippet loads hashtable into memory then converts it to JSON and CliXML
Get-ChildItem ./Research/ESC*.ps1 | ForEach-Object {
    . "./Research/$($_.Name)"
    Get-Variable -ValueOnly -Name $_.BaseName | ConvertTo-Json | Out-File -Path "./Research/$($_.BaseName).json"
    Get-Variable -ValueOnly -Name $_.BaseName | Export-Clixml -Path "./Research/$($_.BaseName).xml"
}
