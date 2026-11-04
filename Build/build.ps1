[CmdletBinding()]
param (
    [Parameter()]
    [System.String[]]
    $TaskList = 'Default',

    [Parameter()]
    [System.Collections.Hashtable]
    $Parameters,

    [Parameter()]
    [System.Collections.Hashtable]
    $Properties,

    [Parameter()]
    [Switch]
    $ResolveDependency
)

Write-Output "`nSTARTED TASKS: $($TaskList -join ',')`n"

Write-Output "`nPowerShell Version Information:"
$PSVersionTable

# Load dependencies
if ($PSBoundParameters.Keys -contains 'ResolveDependency') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # Bootstrap environment
    Get-PackageProvider -Name 'NuGet' -ForceBootstrap | Out-Null

    if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Default
    }
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'

    # Install PSDepend module if it is not already installed
    if (-not (Get-Module -Name 'PSDepend' -ListAvailable)) {
        Write-Output "`nPSDepend is not yet installed...installing PSDepend now..."
        Install-Module -Name 'PSDepend' -Scope 'CurrentUser' -Force
    } else {
        Write-Output "`nPSDepend already installed...skipping."
    }

    # Install build dependencies
    $psdependencyConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'build.depend.psd1'
    Write-Output "Checking / resolving module dependencies from [$psdependencyConfigPath]..."
    Import-Module -Name 'PSDepend'
    $invokePSDependParams = @{
        Path    = $psdependencyConfigPath
        Import  = $false
        Confirm = $false
        Install = $true
    }
    Invoke-PSDepend @invokePSDependParams

    # Remove ResolveDependency PSBoundParameter ready for passthru to PSake
    $PSBoundParameters.Remove('ResolveDependency')
} else {
    Write-Output "Skipping dependency check (-ResolveDependency not set).`n"
}


# Init BuildHelpers
Set-BuildEnvironment -Force

if ($env:GITHUB_ACTIONS -eq 'true') {
    $env:BHBuildSystem = 'GitHub Actions'
    $env:BHBranchName = $env:GITHUB_REF_NAME
    $env:BHBuildNumber = $env:GITHUB_RUN_NUMBER
}

# Execute PSake tasts
$invokePsakeParams = @{
    buildFile = (Join-Path -Path $env:BHProjectPath -ChildPath 'Build\build.psake.ps1')
    nologo    = $true
}
Invoke-Psake @invokePsakeParams @PSBoundParameters

Write-Output "`nFINISHED TASKS: $($TaskList -join ',')"

exit ( [int](-not $psake.build_success) )
