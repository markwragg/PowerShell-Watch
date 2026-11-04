# Create a single .psm1 module file containing all functions
# Copy new module and other supporting files (Documentation / Examples) to Staging folder
Task 'CombineFunctionsAndStage' -Depends 'Clean' {
    $lines

    # Create folders
    New-Item -Path $StagingFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose
    New-Item -Path $StagingModulePath -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get public and private function files
    $publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
    $privateFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Private\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )

    # Combine functions into a single .psm1 module
    $combinedModulePath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psm1"
    @($publicFunctions + $privateFunctions) | Get-Content | Add-Content -Path $combinedModulePath

    # Copy other required folders and files if they exist
    $PathsToCopy = @(
        Join-Path -Path $ProjectRoot -ChildPath 'Documentation'
        Join-Path -Path $ProjectRoot -ChildPath 'Examples'
        Join-Path -Path $ProjectRoot -ChildPath 'CHANGELOG.md'
        Join-Path -Path $ProjectRoot -ChildPath 'README.md'
    )

    foreach ($Path in $PathsToCopy) {
        if (Test-Path $Path) {
            Copy-Item -Path $Path -Destination $StagingFolder -Recurse
        }
    }

    # Copy existing manifest
    Copy-Item -Path $env:BHPSModuleManifest -Destination $StagingModulePath -Recurse

    # Copy format/type ps1xml files so the views they define ship with the built module
    Get-ChildItem -Path $env:BHModulePath -Filter '*.ps1xml' -File | Copy-Item -Destination $StagingModulePath

    # Copy localized help (about_*.help.txt / MAML *-help.xml under en-US) if present.
    $HelpSourcePath = Join-Path -Path $env:BHModulePath -ChildPath 'en-US'

    if (Test-Path $HelpSourcePath) {
        Copy-Item -Path $HelpSourcePath -Destination $StagingModulePath -Recurse
    }

    # Copy repo-specific files (e.g. seed data) listed in build.artifacts.psd1.
    if (Test-Path $ModuleArtifactsConfigPath) {
        $ModuleArtifacts = Import-PowerShellDataFile -Path $ModuleArtifactsConfigPath

        foreach ($RelativePath in $ModuleArtifacts.ModuleFiles) {
            $ArtifactPath = Join-Path -Path $env:BHModulePath -ChildPath $RelativePath

            if (Test-Path $ArtifactPath) {
                Copy-Item -Path $ArtifactPath -Destination $StagingModulePath
            }
        }
    }
}
