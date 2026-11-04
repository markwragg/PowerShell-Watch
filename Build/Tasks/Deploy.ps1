Task 'Deploy' -Depends 'Init' {
    $lines

    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions -Name $env:BHPSModuleManifest

    if (Test-Path $StagingModuleManifestPath) {
        Set-ModuleFunctions -Name $StagingModuleManifestPath

        $env:BHStagingModulePath = $StagingModulePath
    }
    else {
        Write-Warning "Staging module not found at [$StagingModulePath] -- run the CombineFunctionsAndStage task first. Falling back to publishing directly from source."
    }

    # A "## !Deploy" CHANGELOG.md line can optionally pin an exact version, e.g. "## !Deploy 1.12.0" --
    # used below for both the version bump and the deploy gate further down, so it's read once up front.
    $ChangeLogPath = "$ProjectRoot/CHANGELOG.md"
    $DeployPattern = '^## !Deploy(?:\s+(?<Version>\d+(?:\.\d+){1,3}))?\s*$'
    $ChangeLog = if (Test-Path $ChangeLogPath) { Get-Content $ChangeLogPath }
    $DeployLine = $ChangeLog | Where-Object { $_ -match $DeployPattern } | Select-Object -First 1

    if (-not $DeployLine) {
        if ($ChangeLog) {
            Write-Host 'CHANGELOG.md did not contain ## !Deploy. Skipping deployment.'
        }
        else {
            Write-Host "$ChangeLogPath not found. Skipping deployment."
        }
        return
    }

    $null = $DeployLine -match $DeployPattern
    $RequestedVersion = $Matches.Version
    # Bump the module version. An explicit version pinned via "## !Deploy x.x.x" is used as-is, after
    # checking it's newer than what's already published (so a stale/typo'd version can't ship); otherwise
    # it's just the next patch/build number from the Gallery, as before.
    try {
        if ($RequestedVersion) {
            [Version]$Version = $RequestedVersion

            # Reuses BuildHelpers' own Find-NugetPackage (which Get-NextPSGalleryVersion calls internally)
            # rather than pulling in a separate PowerShellGet dependency just for this check.
            try {
                $PublishedVersion = [Version](Find-NugetPackage -Name $env:BHProjectName -PackageSourceUrl 'https://www.powershellgallery.com/api/v2/' -IsLatest -ErrorAction 'Stop').Version
            }
            catch {
                $PublishedVersion = [Version]'0.0.0'
            }

            if ($Version -le $PublishedVersion) {
                throw "CHANGELOG.md requests deploying version [$Version], but [$PublishedVersion] is already published to the PowerShell Gallery. Use a version later than the current latest."
            }
        }
        else {
            $Version = Get-NextPSGalleryVersion -Name $env:BHProjectName -ErrorAction 'Stop'
        }

        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName 'ModuleVersion' -Value $Version -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to update version for '$env:BHProjectName': $_.`n"
    }

    if (Test-Path $StagingModuleManifestPath) {
        Update-Metadata -Path $StagingModuleManifestPath -PropertyName 'ModuleVersion' -Value $Version -ErrorAction 'Stop'
    }

    $Params = @{
        Path    = "$ProjectRoot/Build/deploy.psdeploy.ps1"
        Force   = $true
        Recurse = $false
    }

    Invoke-PSDeploy @Verbose @Params

    # Update ChangeLog with deployment version and date
    $ChangeLog = $ChangeLog -replace $DeployPattern, "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')"
    Set-Content -Path $ChangeLogPath -Value $ChangeLog

    # Signal to the pipeline that a real deploy happened, so the GitHubRelease step (which runs as a later,
    # separate step in the same job) knows to run. Only set when actually running in GitHub Actions.
    if ($env:GITHUB_OUTPUT) {
        "DidDeploy=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
}
