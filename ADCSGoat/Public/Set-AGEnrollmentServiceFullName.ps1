function Set-AGEnrollmentServiceFullName {
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ $_.objectClass -eq 'pKIEnrollmentService' })]
        [System.DirectoryServices.DirectoryEntry]$EnrollmentService,
        [Parameter(Mandatory)]
        [string]$EnrollmentServiceFullName
    )

    $EnrollmentService | Add-Member -NotePropertyName 'FullName' -NotePropertyValue $EnrollmentServiceFullName -Force
}
