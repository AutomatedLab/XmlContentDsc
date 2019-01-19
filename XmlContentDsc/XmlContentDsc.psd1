@{
    RootModule           = 'XmlContentDsc.psm1'

    ModuleVersion        = '0.0.1'

    GUID                 = '5810d7ae-53c4-4670-83e9-ba5d5e55db95'

    Author               = 'Raimund Andree'

    CompanyName          = 'Microsoft'

    Copyright            = '2018'

    Description          = 'Module with DSC Resources for managing XML file content'

    PowerShellVersion    = '4.0'

    CLRVersion           = '4.0'

    PrivateData          = @{

        PSData = @{

            Tags       = @('DesiredStateConfiguration', 'DSC', 'XML', 'DSCResource')

            LicenseUri = 'https://github.com/PowerShell/xWebAdministration/blob/master/LICENSE'

            ProjectUri = 'https://github.com/PowerShell/xWebAdministration'
        }
    }

    DscResourcesToExport = 'XmlFileContentResource'
}
