param
(
    [Parameter(Mandatory)]
    [string]
    $ConfigurationName
)

Configuration $ConfigurationName
{
    Import-DscResource -ModuleName XmlContentDsc

    Node localhost
    {
        XmlContent XmlConfigItem1 {
            Path       = $Node.Path
            XPath      = $Node.XPath
            Attributes = $Node.Attributes
            Namespaces = $Node.Namespaces
            Ensure     = $Node.Ensure
        }
    }
}
