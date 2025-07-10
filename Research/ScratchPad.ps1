$TemplateNames = @(
    'ESC1'
    'ESC2'
    'ESC3c1'
    'ESC3c2'
    'ESC4'
    'ESC9'
)

$properties = Import-Clixml -Path ESC1Properties.xml

foreach ($property in $properties.GetEnumerator() ) {
    $newTemplate.Properties[$property.Name].Value = $property.Value
}
$newTemplate.CommitChanges()
