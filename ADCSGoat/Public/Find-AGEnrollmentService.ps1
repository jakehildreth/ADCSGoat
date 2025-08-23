function Find-AGEnrollmentService {
    # Get the Configuration partition automatically via RootDSE
    $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
    $ConfigurationPartition = $rootDSE.configurationNamingContext
    $EnrollmentServicesContainer = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigurationPartition"
    $EnrollmentServicesPath = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$EnrollmentServicesContainer")
    $EnrollmentServicesPath.Children
}
