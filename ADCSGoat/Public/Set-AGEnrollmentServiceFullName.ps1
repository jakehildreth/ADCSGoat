function Set-AGEnrollmentServiceFullName {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ $_.objectClass -eq 'pKIEnrollmentService' })]
        [System.DirectoryServices.DirectoryEntry]$EnrollmentService
    )

    process {
        $EnrollmentServiceFullName = "$($EnrollmentService.dNSHostName)\$($EnrollmentService.name)"
        $EnrollmentService | Add-Member -NotePropertyName 'FullName' -NotePropertyValue $EnrollmentServiceFullName -Force
    }
}
