function Set-AGEnrollmentServiceFullName {
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ $_.objectClass -eq 'pKIEnrollmentService' })]
        [System.DirectoryServices.DirectoryEntry]$EnrollmentService,
        [Parameter(Mandatory)]
        [string]$EnrollmentServiceFullName
    )

    "$($EnrollmentService.dNSHostName)\$($EnrollmentService.name)"
}
