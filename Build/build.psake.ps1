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

    # Documentation
    $DocumentationPath = Join-Path -Path $ProjectRoot -ChildPath 'Documentation'

    # Wiki (GitHub wikis are backed by a separate '<repo>.wiki.git' repository)
    $WikiPath = Join-Path -Path $ProjectRoot -ChildPath 'wiki'
}


# Define top-level tasks
Task 'Default' -Depends 'Test'


# Show build variables
Task 'Init' {
    $lines

    Set-Location $ProjectRoot

    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}


# Clean the Artifact and Staging folders
Task 'Clean' -Depends 'Init' {
    $lines

    $foldersToClean = @(
        $ArtifactFolder
        $StagingFolder
    )

    # Remove folders
    foreach ($folderPath in $foldersToClean) {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        New-Item -Path $folderPath -ItemType 'Directory' -Force | Out-String | Write-Verbose
    }
}


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
}


# Import new module
Task 'ImportStagingModule' -Depends 'Init' {
    $lines
    Write-Output "Reloading staged module from path: [$StagingModulePath]`n"

    # Reload module
    if (Get-Module -Name $env:BHProjectName) {
        Remove-Module -Name $env:BHProjectName
    }
    # Global scope used for UpdateDocumentation / UpdateWiki (PlatyPS)
    Import-Module -Name $StagingModulePath -ErrorAction 'Stop' -Force -Global
}


# Run PSScriptAnalyzer against code to ensure quality and best practices are used
Task 'Analyze' -Depends 'ImportStagingModule' {
    $lines
    Write-Output "Running PSScriptAnalyzer on path: [$StagingModulePath]`n"

    $Results = Invoke-ScriptAnalyzer -Path $StagingModulePath -Recurse -Settings $ScriptAnalyzerSettingsPath -Verbose:$VerbosePreference
    $Results | Select-Object 'RuleName', 'Severity', 'ScriptName', 'Line', 'Message' | Format-List

    switch ($ScriptAnalysisFailBuildOnSeverityLevel) {
        'None' {
            return
        }
        'Error' {
            Assert -conditionToCheck (
                ($Results | Where-Object 'Severity' -eq 'Error').Count -eq 0
            ) -failureMessage 'One or more ScriptAnalyzer errors were found. Build cannot continue!'
        }
        'Warning' {
            Assert -conditionToCheck (
                ($Results | Where-Object {
                        $_.Severity -eq 'Warning' -or $_.Severity -eq 'Error'
                    }).Count -eq 0) -failureMessage 'One or more ScriptAnalyzer warnings were found. Build cannot continue!'
        }
        default {
            Assert -conditionToCheck ($analysisResult.Count -eq 0) -failureMessage 'One or more ScriptAnalyzer issues were found. Build cannot continue!'
        }
    }
}


# Run Pester tests
# Unit tests: verify inputs / outputs / expected execution path
# Misc tests: verify manifest data, check comment-based help exists
Task 'Test' -Depends 'ImportStagingModule' {
    $lines

    Import-Module -Name 'Pester' -RequiredVersion '6.1.0' -Force

    # Gather test results. Store them in a variable and file
    $CodeFiles = (Get-ChildItem $ENV:BHModulePath -Recurse -Include '*.ps1').FullName
    $TestFilePath = Join-Path -Path $ArtifactFolder -ChildPath $TestFile

    $PesterConfiguration = New-PesterConfiguration
    $PesterConfiguration.Run.Path = $TestScripts.FullName
    $PesterConfiguration.Run.PassThru = $true
    $PesterConfiguration.CodeCoverage.Enabled = $true
    $PesterConfiguration.CodeCoverage.Path = $CodeFiles
    $PesterConfiguration.TestResult.Enabled = $true
    $PesterConfiguration.TestResult.OutputFormat = 'NUnitXml'
    $PesterConfiguration.TestResult.OutputPath = $TestFilePath
    $PesterConfiguration.Output.Verbosity = 'Detailed'

    $TestResults = Invoke-Pester -Configuration $PesterConfiguration

    # Fail build if any tests fail
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }

    # Surface the coverage result as a pipeline output variable so a later stage (which runs in a
    # separate, discarded workspace) can apply it to README.md without re-running the tests.
    $CoveragePercent = [math]::floor($TestResults.CodeCoverage.CoveragePercent)

    Write-Host "##vso[task.setvariable variable=CoveragePercent;isOutput=true]$CoveragePercent"
}


# Update the coverage badge in README.md using a coverage percentage computed by an earlier Test task
Task 'UpdateCoverageBadge' -Depends 'Init' {
    $lines

    if (-not $env:CoveragePercent) {
        throw "CoveragePercent environment variable not set. Run the 'Test' task first and pass its coverage output through."
    }

    Set-ShieldsIoBadge -Path (Join-Path $ProjectRoot 'README.md') -Subject 'coverage' -Status $env:CoveragePercent -AsPercentage
}


# Create new Documentation markdown files from comment-based help
Task 'UpdateDocumentation' -Depends 'ImportStagingModule' {
    $lines
    Write-Output "Updating Markdown help in Staging folder: [$DocumentationPath]`n"

    if (Test-Path $DocumentationPath) {
        Remove-Item -Path $DocumentationPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        Start-Sleep -Seconds 5
    }

    # Cleanup
    New-Item -Path $DocumentationPath -ItemType 'Directory' | Out-Null

    # Create new Documentation markdown files
    $platyPSParams = @{
        Module       = $env:BHProjectName
        OutputFolder = $DocumentationPath
        NoMetadata   = $true
    }
    New-MarkdownHelp @platyPSParams -ErrorAction 'SilentlyContinue' -Verbose | Out-Null
}


# Generate markdown help from comment-based help and publish it to the GitHub wiki.
# GitHub wikis are backed by a separate '<repo>.wiki.git' repository, so this clones
# that repo, regenerates the function reference pages with PlatyPS, and pushes the result.
Task 'UpdateWiki' -Depends 'ImportStagingModule' {
    $lines

    if (-not $env:GITHUBPAT) {
        Write-Warning 'GITHUBPAT environment variable not set. Skipping wiki update.'
        return
    }

    # Derive the wiki repo URL from the main repo's origin remote.
    $OriginUrl = (git config --get remote.origin.url) -replace '\.git$', ''
    $WikiUrl = "$OriginUrl.wiki.git"
    $AuthedWikiUrl = $WikiUrl -replace '^https://', "https://x-access-token:$($env:GITHUBPAT)@"

    # Safety check: refuse to continue unless the derived URL is unambiguously a wiki
    # repo and distinct from the main repo. This is what would have caught the bug above.
    if ($WikiUrl -notmatch '\.wiki\.git$' -or $WikiUrl -eq (git config --get remote.origin.url)) {
        throw "Failed to derive a valid wiki repository URL from the main repo's origin remote. Refusing to continue, to avoid publishing to the main repository instead of its wiki."
    }

    Write-Output "Cloning wiki repo: [$WikiUrl] to [$WikiPath]`n"

    if (Test-Path $WikiPath) {
        Remove-Item -Path $WikiPath -Recurse -Force -ErrorAction 'SilentlyContinue'
    }

    git clone $AuthedWikiUrl $WikiPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone wiki repo [$WikiUrl]. Ensure the Wiki feature is enabled for the repository and at least one page has been created manually via the GitHub UI to initialize it."
    }

    # Confirm the clone actually produced a usable git repository before generating anything into it.
    # Without this check, a silently-failed clone could leave downstream steps operating on $ProjectRoot instead.
    if (-not (Test-Path (Join-Path $WikiPath '.git'))) {
        throw "Wiki clone did not produce a git repository at [$WikiPath]. Aborting before publishing anything, to avoid committing wiki pages to the main repository."
    }

    $ResolvedWikiPath = (Resolve-Path $WikiPath).Path

    # Remove previously generated function reference pages, leaving any manually authored pages (e.g. Home.md) untouched
    $ModuleFunctions = Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1", "$env:BHModulePath\Private\*.ps1" -Recurse -ErrorAction 'SilentlyContinue'

    foreach ($Function in $ModuleFunctions) {
        Remove-Item -Path (Join-Path $WikiPath "$($Function.BaseName).md") -Force -ErrorAction 'SilentlyContinue'
    }

    # Create new wiki pages
    $platyPSParams = @{
        Module       = $env:BHProjectName
        OutputFolder = $ResolvedWikiPath
        NoMetadata   = $true
    }
    New-MarkdownHelp @platyPSParams -ErrorAction 'Stop' -Verbose | Out-Null

    # Confirm PlatyPS actually wrote a page for every exported (Public) function into the
    # wiki clone. Private functions aren't exported, so PlatyPS never generates pages for
    # them - only Public functions are checked here. Checking specific expected filenames
    # (rather than "any *.md exists") avoids a false pass from the pre-existing,
    # manually-authored Home.md alone.
    $PublicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
    $MissingPages = @( $PublicFunctions | Where-Object {
            -not (Test-Path (Join-Path $ResolvedWikiPath "$($_.BaseName).md"))
        }
    )
    if ($MissingPages.Count -gt 0) {
        throw "New-MarkdownHelp did not produce pages for: $($MissingPages.BaseName -join ', ') in [$ResolvedWikiPath]. Aborting before publishing anything."
    }

    Push-Location $ResolvedWikiPath -ErrorAction 'Stop'
    try {
        # Safety check: refuse to publish unless we are verifiably inside the wiki clone. This guards
        # against ever again committing/pushing wiki pages to the main repository if the location change
        # above were to silently no-op.
        $CurrentRepoRoot = git rev-parse --show-toplevel
        if ((ConvertTo-ComparablePath $CurrentRepoRoot) -ne (ConvertTo-ComparablePath $ResolvedWikiPath)) {
            throw "Refusing to publish: current git repository [$CurrentRepoRoot] does not match the wiki clone [$ResolvedWikiPath]."
        }

        git config user.email "build@azuredevops.com"
        git config user.name "AzureDevOps"
        git add -A

        if (git status --porcelain) {
            git commit -m "[skip ci] AzureDevOps Build $($env:BUILD_BUILDID)"
            git push

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push changes to wiki repo [$WikiUrl]."
            }
        }
        else {
            Write-Output 'No wiki changes to publish.'
        }
    }
    finally {
        Pop-Location
    }
}


# Create a versioned zip file of all staged files
# NOTE: Admin Rights are needed if you run this locally
Task 'CreateBuildArtifact' -Depends 'Init' {
    $lines

    # Create /Release folder
    New-Item -Path $ArtifactFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get current manifest version
    try {
        $manifest = Test-ModuleManifest -Path $StagingModuleManifestPath -ErrorAction 'Stop'
        [Version]$manifestVersion = $manifest.Version

    }
    catch {
        throw "Could not get manifest version from [$StagingModuleManifestPath]"
    }

    # Create zip file
    try {
        $releaseFilename = "$($env:BHProjectName)-v$($manifestVersion.ToString()).zip"
        $releasePath = Join-Path -Path $ArtifactFolder -ChildPath $releaseFilename
        Write-Host "Creating release artifact [$releasePath] using manifest version [$manifestVersion]" -ForegroundColor 'Yellow'
        Compress-Archive -Path "$StagingFolder/*" -DestinationPath $releasePath -Force -Verbose -ErrorAction 'Stop'
    }
    catch {
        throw "Could not create release artifact [$releasePath] using manifest version [$manifestVersion]"
    }

    Write-Output "`nFINISHED: Release artifact creation."
}

Task 'Deploy' -Depends 'Init' {
    $lines

    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions -Name $env:BHPSModuleManifest

    # Bump the module version
    try {
        $Version = Get-NextPSGalleryVersion -Name $env:BHProjectName -ErrorAction 'Stop'

        # Ensure the next deploy is at least 1.1.0. Once the Gallery has a 1.1.0+ release published, Get-NextPSGalleryVersion will always be >= this floor
        # on its own, so this check becomes a no-op and doesn't need to be removed later.
        $MinimumVersion = [Version]'1.1.0'
        if ($Version -lt $MinimumVersion) { $Version = $MinimumVersion }

        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName 'ModuleVersion' -Value $Version -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to update version for '$env:BHProjectName': $_.`n"
    }

    # deploy.psdeploy.ps1 publishes the combined module built by CombineFunctionsAndStage, not the source --
    # its manifest was copied from source before this task bumped the version above, so it needs the same
    # updates applied to it directly too.
    if (Test-Path $StagingModuleManifestPath) {
        Set-ModuleFunctions -Name $StagingModuleManifestPath
        Update-Metadata -Path $StagingModuleManifestPath -PropertyName 'ModuleVersion' -Value $Version -ErrorAction 'Stop'

        # Invoke-PSDeploy runs deploy.psdeploy.ps1 from inside the PSDeploy module's own function scope, which
        # can't see this task's local $StagingModulePath -- module scope boundaries block that. An environment
        # variable crosses the boundary instead.
        $env:BHStagingModulePath = $StagingModulePath
    }
    else {
        Write-Warning "Staging module not found at [$StagingModulePath] -- run the CombineFunctionsAndStage task first. Falling back to publishing directly from source."
    }

    if (Get-Item "$ProjectRoot/CHANGELOG.md") {

        $ChangeLog = Get-Content "$ProjectRoot/CHANGELOG.md"

        if ($ChangeLog -contains '## !Deploy') {

            $Params = @{
                Path    = "$ProjectRoot/Build/deploy.psdeploy.ps1"
                Force   = $true
                Recurse = $false
            }

            Invoke-PSDeploy @Verbose @Params

            # Update ChangeLog with deployment version and date
            $ChangeLog = $ChangeLog -replace '## !Deploy', "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')"
            Set-Content -Path "$ProjectRoot/CHANGELOG.md" -Value $ChangeLog
        }
        else {
            Write-Host 'CHANGELOG.md did not contain ## !Deploy. Skipping deployment.'
        }
    }
    else {
        Write-Host "$ProjectRoot/CHANGELOG.md not found. Skipping deployment."
    }
}

Task 'Commit' -Depends 'Init' {
    $lines

    Set-Location $ProjectRoot
    $Module = $env:BHProjectName

    git --version
    git config --global user.email "build@azuredevops.com"
    git config --global user.name "AzureDevOps"
    git checkout $env:BUILD_SOURCEBRANCHNAME
    git add Documentation/*.md
    git add README.md
    git add CHANGELOG.md
    git commit -m "[skip ci] AzureDevOps Build $($env:BUILD_BUILDID)"
    git push
}
