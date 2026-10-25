function Set-AGRdpUserAccess {
    <#
    .SYNOPSIS
        Adds or removes a domain user in a computer's Remote Desktop Users group.

    .DESCRIPTION
        Internal helper. Runs locally when ComputerName is this computer,
        otherwise through PowerShell remoting. Only the group membership is
        changed; AutomatedLab already enables Remote Desktop on lab VMs. Both
        directions are idempotent.

    .PARAMETER ComputerName
        The computer whose local Remote Desktop Users group is changed.

    .PARAMETER Member
        The domain account in DOMAIN\user form.

    .PARAMETER Ensure
        Present adds the member, Absent removes it.

    .EXAMPLE
        Set-AGRdpUserAccess -ComputerName ADCSGoat-PAW -Member 'ADCS\user' -Ensure Present
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Member,

        [Parameter(Mandatory)]
        [ValidateSet('Present', 'Absent')]
        [string]$Ensure
    )

    $action = {
        param($Member, $Ensure)

        $group = 'Remote Desktop Users'
        $isMember = [bool](Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $Member })

        if ($Ensure -eq 'Present') {
            if (-not $isMember) { Add-LocalGroupMember -Group $group -Member $Member -ErrorAction Stop }
        } elseif ($isMember) {
            Remove-LocalGroupMember -Group $group -Member $Member -ErrorAction Stop
        }
    }

    if (-not $PSCmdlet.ShouldProcess($ComputerName, "Ensure $Member is $Ensure in Remote Desktop Users")) { return }

    $isLocal = $ComputerName.Split('.')[0] -eq $env:COMPUTERNAME
    if ($isLocal) {
        & $action $Member $Ensure
    } else {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $action -ArgumentList $Member, $Ensure -ErrorAction Stop
    }
}
