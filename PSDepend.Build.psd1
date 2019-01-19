@{
    PSDependOptions              = @{
        AddToPath = $True
        Target    = 'BuildOutput\Modules'
    }

    #Modules
    BuildHelpers                 = 'latest'
    InvokeBuild                  = 'latest'
    Pester                       = 'latest'
    PSScriptAnalyzer             = 'latest'
    PSDeploy                     = 'latest'
    PowershellGet                = 'latest' 

    #DSC Resources
    xPSDesiredStateConfiguration = '8.4.0.0'
}