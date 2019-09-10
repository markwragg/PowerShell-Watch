# Config file for PSDeploy
# Set-BuildEnvironment from BuildHelpers module has populated ENV:BHModulePath and related variables
# Publish to gallery with a few restrictions
if ($StagingModulePath) {
    $ModuleSourcePath = $StagingModulePath
}
else {
    $ModuleSourcePath = $env:BHPSModulePath
}

if (
    $ModuleSourcePath -and
    $env:BHBuildSystem -ne 'Unknown' -and
    $env:BHBranchName -eq "master" -and
    $ENV:NugetApiKey
) {
    Deploy Module {
        By PSGalleryModule {
            FromSource $ModuleSourcePath
            To PSGallery
            WithOptions @{
                ApiKey = $ENV:NugetApiKey
            }
        }
    }
} else {
    "Skipping deployment: To deploy, ensure that...`n" +
    "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" +
    "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" +
    "`t* You have access to the Nuget API key" |
        Write-Host
}

# Publish to AppVeyor if we're in AppVeyor
if ($env:BHPSModulePath -and $env:BHBuildSystem -eq 'AppVeyor') {
    Deploy DeveloperBuild {
        By AppVeyorModule {
            FromSource $ModuleSourcePath
            To AppVeyor
            WithOptions @{
                Version = $env:APPVEYOR_BUILD_VERSION
            }
        }
    }
}
