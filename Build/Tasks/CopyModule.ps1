task CopyModule {

    # Bump the module version
    if ($env:BHBuildSystem -eq 'AppVeyor') {
        Update-Metadata -Path $env:BHPSModuleManifest -Verbose -Value $env:APPVEYOR_BUILD_VERSION
    }

    Write-Build Green "Copy folder '$projectPath\Modules\$($env:BHProjectName)' to '$buildOutput'" Green
    Copy-Item -Path $projectPath\Modules\$env:BHProjectName -Destination $buildOutput\Modules -Recurse -Force

}