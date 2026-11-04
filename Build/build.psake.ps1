# Normalizes path separators/casing
function ConvertTo-ComparablePath ([string]$Path) {
    ($Path -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
}

# PSake makes variables declared here available in other scriptblocks
Properties {
    $ProjectRoot = $ENV:BHProjectPath

    if (-not $ProjectRoot) {
        $ProjectRoot = "$PSScriptRoot/.."
    }

    $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
    $PSVersion = $PSVersionTable.PSVersion.Major
    $lines = '----------------------------------------------------------------------'

    # Pester
    $TestScripts = Get-ChildItem "$ProjectRoot\Tests\*.Tests.ps1" -Recurse
    $TestFile = "Test-Unit_$($TimeStamp).xml"

    # Script Analyzer
    [ValidateSet('Error', 'Warning', 'Any', 'None')]
    $ScriptAnalysisFailBuildOnSeverityLevel = 'Error'
    $ScriptAnalyzerSettingsPath = "$ProjectRoot\PSScriptAnalyzerSettings.psd1"

    # Build
    $ArtifactFolder = Join-Path -Path $ProjectRoot -ChildPath 'Artifacts'

    # Staging
    $StagingFolder = Join-Path -Path $ProjectRoot -ChildPath 'Staging'
    $StagingModulePath = Join-Path -Path $StagingFolder -ChildPath $env:BHProjectName
    $StagingModuleManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psd1"

    # Repo-specific files to ship with the module (e.g. seed data)
    $ModuleArtifactsConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'build.artifacts.psd1'

    # Documentation
    $DocumentationPath = Join-Path -Path $ProjectRoot -ChildPath 'Documentation'

    # Wiki (GitHub wikis are backed by a separate '<repo>.wiki.git' repository)
    $WikiPath = Join-Path -Path $ProjectRoot -ChildPath 'wiki'
}


# Define top-level tasks
Task 'Default' -Depends 'Test'


# Each task lives in its own file under Tasks/ -- Task/Properties/Default are just psake functions
# that register metadata, so dot-sourcing them here is equivalent to defining them inline.
Get-ChildItem -Path "$PSScriptRoot\Tasks\*.ps1" | ForEach-Object { . $_.FullName }
