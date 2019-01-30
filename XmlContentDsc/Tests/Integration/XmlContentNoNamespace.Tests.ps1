function Initialize-DscLocalConfigurationManager {

    $lcmConfigPath = Join-Path -Path $env:temp -ChildPath 'LCMConfiguration'
    if (-not (Test-Path -Path $lcmConfigPath)) {
        New-Item -Path $lcmConfigPath -ItemType Directory -Force | Out-Null
    }
    
    $lcmConfig = @'
Configuration LocalConfigurationManagerConfiguration
{
    LocalConfigurationManager
    {
    
    ConfigurationMode = 'ApplyOnly'
        
    }
}
'@

    Invoke-Command -ScriptBlock ([scriptblock]::Create($lcmConfig)) -NoNewScope

    LocalConfigurationManagerConfiguration -OutputPath $lcmConfigPath | Out-Null
    
    Set-DscLocalConfigurationManager -Path $lcmConfigPath -Force
    Remove-Item -LiteralPath $lcmConfigPath -Recurse -Force -Confirm:$false
}


function Reset-DscLocalConfigurationManager {

    Write-Verbose -Message 'Resetting the DSC LCM'

    Stop-DscConfiguration -WarningAction SilentlyContinue -Force
    Remove-DscConfigurationDocument -Stage Current -Force
    Remove-DscConfigurationDocument -Stage Pending -Force
    Remove-DscConfigurationDocument -Stage Previous -Force
}

Initialize-DscLocalConfigurationManager

$testXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <ToBeRemoved>
      <SomeElement />
    </ToBeRemoved>
    <SomeElement ToBeRemoved="123" ToRemain="Test">
    </SomeElement>
  </runtime>
</configuration>
'@

$testFilePath = 'd:\test.xml' #New-TemporaryFile | Select-Object -ExpandProperty FullName
if (Test-Path -Path "C:\Program Files\WindowsPowerShell\Modules\$($env:BHProjectName)") {
    Remove-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$($env:BHProjectName)" -Force -Recurse -Confirm:$false
}
Move-Item -Path "$($env:BHBuildOutput)\Modules\$($env:BHProjectName)" -Destination 'C:\Program Files\WindowsPowerShell\Modules' -Force

# Load the DSC config to use for testing
$PSScriptName = $MyInvocation.MyCommand.Name
$dscTestConfigFileName = $PSScriptName.Replace('Tests', 'Config')
$dscTestConfigName = $PSScriptName.Substring(0, $PSScriptName.IndexOf('.')).Replace(' ', '').Trim()
. "$PSScriptRoot\$dscTestConfigFileName" -ConfigurationName $dscTestConfigName

try {
    Describe 'XmlContentResourceTest' {
        Context 'General Tests' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime'
            $namespaces = @{}
            $ensure = 'Present'

            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Attributes = $attributes
                                Namespaces = $namespaces
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop } | Should -Not -throw
            }
        
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
    
        Context 'Add an attribute to an exsiting element' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime'
            $attributes = @{ Attribute1 = 'Value1' }
            $namespaces = @{}
            $ensure = 'Present'
        
            $expectedTestXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime Attribute1="Value1">
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <ToBeRemoved>
      <SomeElement />
    </ToBeRemoved>
    <SomeElement ToBeRemoved="123" ToRemain="Test">
    </SomeElement>
  </runtime>
</configuration>
'@
    
            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Attributes = $attributes
                                Namespaces = $namespaces
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop } | Should -Not -throw
            }
        
            It 'The XML conent should be the same as generated via DSC' {
                Get-Content -Path $testFilePath -Raw | Should -Be $expectedTestXmlContent
            }
        
            It 'Should have set the resource and all the parameters should match' {
                $currentDscConfig = Get-DscConfiguration -ErrorAction Stop
                $current = $currentDscConfig | Where-Object ConfigurationName -eq $dscTestConfigName
            
                $current.Path | Should -Be $path
                $current.XPath | Should -Be $xPath
                Compare-Hashtable -Reference ($current.Attributes | Convert-CimInstanceArrayToHashtable) -Difference $attributes | Should -Be $true
                Compare-Hashtable -Reference ($current.Namespaces | Convert-CimInstanceArrayToHashtable) -Difference $namespaces | Should -Be $true
                $current.Ensure | Should -Be $ensure
            }
        
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Context 'Remove an attribute to an exsiting element' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime/SomeElement'
            $attributes = @{ ToRemain = 'Test' }
            $namespaces = @{}
            $ensure = 'Present'
        
            $expectedTestXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <ToBeRemoved>
      <SomeElement />
    </ToBeRemoved>
    <SomeElement ToRemain="Test">
    </SomeElement>
  </runtime>
</configuration>
'@
    
            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Attributes = $attributes
                                Namespaces = $namespaces
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop } | Should -Not -throw
            }
        
            It 'The XML conent should be the same as generated via DSC' {
                Get-Content -Path $testFilePath -Raw | Should -Be $expectedTestXmlContent
            }
        
            It 'Should have set the resource and all the parameters should match' {
                $currentDscConfig = Get-DscConfiguration -ErrorAction Stop
                $current = $currentDscConfig | Where-Object ConfigurationName -eq $dscTestConfigName
            
                $current.Path | Should -Be $path
                $current.XPath | Should -Be $xPath
                Compare-Hashtable -Reference ($current.Attributes | Convert-CimInstanceArrayToHashtable) -Difference $attributes | Should -Be $true
                Compare-Hashtable -Reference ($current.Namespaces | Convert-CimInstanceArrayToHashtable) -Difference $namespaces | Should -Be $true
                $current.Ensure | Should -Be $ensure
            }
            
        
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Context 'Add an element to an exsiting element' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime/SomeElement/SomeSubElement'
            $attributes = @{}
            $namespaces = @{}
            $ensure = 'Present'
        
            $expectedTestXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <ToBeRemoved>
      <SomeElement />
    </ToBeRemoved>
    <SomeElement ToBeRemoved="123" ToRemain="Test">
      <SomeSubElement />
    </SomeElement>
  </runtime>
</configuration>
'@
    
            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop } | Should -Not -throw
            }
        
            It 'The XML conent should be the same as generated via DSC' {
                Get-Content -Path $testFilePath -Raw | Should -Be $expectedTestXmlContent
            }
        
            It 'Should have set the resource and all the parameters should match' {
                $currentDscConfig = Get-DscConfiguration -ErrorAction Stop
                $current = $currentDscConfig | Where-Object ConfigurationName -eq $dscTestConfigName
            
                $current.Path | Should -Be $path
                $current.XPath | Should -Be $xPath
                Compare-Hashtable -Reference ($current.Attributes | Convert-CimInstanceArrayToHashtable) -Difference $attributes | Should -Be $true
                Compare-Hashtable -Reference ($current.Namespaces | Convert-CimInstanceArrayToHashtable) -Difference $namespaces | Should -Be $true
                $current.Ensure | Should -Be $ensure
            }
            
        
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Context 'Add an element to a non-existing element should throw' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime/DoesNotExist/SomeSubElement'
            $attributes = @{}
            $namespaces = @{}
            $ensure = 'Present'
        
            $expectedTestXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <ToBeRemoved>
      <SomeElement />
    </ToBeRemoved>
    <SomeElement ToBeRemoved="123" ToRemain="Test">
      <SomeSubElement />
    </SomeElement>
  </runtime>
</configuration>
'@
    
            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop -WarningAction SilentlyContinue } | Should -Not -throw
            }
            
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Context 'Remove an element from an exsiting element' {
    
            $nodeName = 'localhost'
            $path = $testFilePath
            $xPath = '/configuration/runtime/ToBeRemoved'
            $attributes = @{}
            $namespaces = @{}
            $ensure = 'Absent'
        
            $expectedTestXmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-8.0.0.0" newVersion="8.0.0.0" />
      </dependentAssembly>
    </assemblyBinding>
    <SomeElement ToBeRemoved="123" ToRemain="Test">
    </SomeElement>
  </runtime>
</configuration>
'@
    
            BeforeAll {
                Set-Content -Path $testFilePath -Value $testXmlContent -NoNewline -Force
            }

            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName   = $nodeName
                                Path       = $path
                                XPath      = $xPath
                                Ensure     = $ensure
                            }
                        )
                    }

                    & $dscTestConfigName -OutputPath C:\DSC -ConfigurationData $configData

                Start-DscConfiguration -Path C:\DSC -ComputerName localhost -Wait -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { $currentDscConfig = Get-DscConfiguration -ErrorAction Stop } | Should -Not -throw
            }
        
            It 'The XML conent should be the same as generated via DSC' {
                Get-Content -Path $testFilePath -Raw | Should -Be $expectedTestXmlContent
            }
        
            It 'Should have set the resource and all the parameters should match' {
                $currentDscConfig = Get-DscConfiguration -ErrorAction Stop
                $current = $currentDscConfig | Where-Object ConfigurationName -eq $dscTestConfigName
            
                $current.Path | Should -Be $path
                $current.XPath | Should -Be $xPath
                Compare-Hashtable -Reference ($current.Attributes | Convert-CimInstanceArrayToHashtable) -Difference $attributes | Should -Be $true
                Compare-Hashtable -Reference ($current.Namespaces | Convert-CimInstanceArrayToHashtable) -Difference $namespaces | Should -Be $true
                $current.Ensure | Should -Be $ensure
            }
        
            AfterAll {
                Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    Reset-DscLocalConfigurationManager
    
    Move-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$($env:BHProjectName)" -Destination "$($env:BHBuildOutput)\Modules" -Force
}
#Context 'An INI settings file containing an entry to be replaced with another secret text string' {
#    BeforeAll {
#        # Create the text file to use for testing
#        Set-Content `
#            -Path $script:testTextFile `
#            -Value $script:testFileContent `
#            -NoNewline `
#            -Force
#    }
#
#    #region DEFAULT TESTS
#    It 'Should compile and apply the MOF without throwing' {
#        {
#            $configData = @{
#                AllNodes = @(
#                    @{
#                        NodeName                    = 'localhost'
#                        Path                        = $script:testTextFile
#                        Section                     = $script:testSection
#                        Key                         = $script:testKey
#                        Type                        = 'Secret'
#                        Secret                      = $script:testSecretCredential
#                        PsDscAllowPlainTextPassword = $true
#                    }
#                )
#            }
#
#            & $script:configurationName `
#                -OutputPath $TestDrive `
#                -ConfigurationData $configData
#
#            Start-DscConfiguration `
#                -Path $TestDrive `
#                -ComputerName localhost `
#                -Wait `
#                -Verbose `
#                -Force `
#                -ErrorAction Stop
#        } | Should -Not -Throw
#    }
#
#    It 'Should be able to call Get-DscConfiguration without throwing' {
#        { $script:currentDscConfig = Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -throw
#    }
#
#    It 'Should have set the resource and all the parameters should match' {
#        $script:current = $script:currentDscConfig | Where-Object {
#            $_.ConfigurationName -eq $script:configurationName
#        }
#        $current.Path             | Should -Be $script:testTextFile
#        $current.Section          | Should -Be $script:testSection
#        $current.Key              | Should -Be $script:testKey
#        $current.Type             | Should -Be 'Text'
#        $current.Text             | Should -Be $script:testSecret
#    }
#
#    It 'Should be convert the file content to match expected content' {
#        Get-Content -Path $script:testTextFile -Raw | Should -Be $script:testFileExpectedSecretContent
#    }
#
#    AfterAll {
#        if (Test-Path -Path $script:testTextFile)
#        {
#            Remove-Item -Path $script:testTextFile -Force
#        }
#    }
#}
#    }
#}