function Get-AGEnrollmentServiceFullName {
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ $_.objectClass -eq 'pKIEnrollmentService' })]
        [System.DirectoryServices.DirectoryEntry]$EnrollmentService
    )

    "$($EnrollmentService.dNSHostName)\$($EnrollmentService.name)"
}
