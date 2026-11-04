# Create a GitHub Release for the version just published, with the matching CHANGELOG.md section as
# its notes and the zip built by CreateBuildArtifact attached as a release asset.
Task 'GitHubRelease' -Depends 'Init' {
    $lines

    if (-not $env:GITHUBPAT) {
        Write-Warning 'GITHUBPAT environment variable not set. Skipping GitHub release.'
        return
    }

    # Derive owner/repo from the main repo's origin remote, the same way UpdateWiki derives the wiki URL.
    $OriginUrl = (git config --get remote.origin.url) -replace '\.git$', ''
    if ($OriginUrl -notmatch 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+)$') {
        throw "Could not derive a GitHub owner/repo from origin remote [$OriginUrl]. Refusing to continue."
    }
    $Owner = $Matches.owner
    $Repo = $Matches.repo

    # Read back the version the Deploy task just bumped (it updates the manifest in place, so this
    # step doesn't need Deploy's local $Version - each pipeline step is a separate pwsh process).
    try {
        $manifest = Test-ModuleManifest -Path $StagingModuleManifestPath -ErrorAction 'Stop'
        $Version = $manifest.Version.ToString()
    }
    catch {
        throw "Could not get manifest version from [$StagingModuleManifestPath]"
    }

    $Tag = "v$Version"

    # This task only runs (per the pipeline step's condition) when the Deploy task's DidDeploy output
    # variable was set, i.e. a real PSGallery publish just happened - the manifest version read above is
    # otherwise bumped on every build regardless, so that alone can't be trusted as the "did we deploy"
    # signal. Given that, the CHANGELOG.md section for $Version is expected to exist (Deploy writes it in
    # the same branch that sets DidDeploy); its absence means something is inconsistent, so fail loudly
    # rather than silently skipping the release.
    $ChangeLogPath = Join-Path -Path $ProjectRoot -ChildPath 'CHANGELOG.md'
    if (-not (Test-Path $ChangeLogPath)) {
        throw "$ChangeLogPath not found, but the Deploy task reported a release was just published. Refusing to create a GitHub release without notes."
    }

    $ChangeLogContent = Get-Content $ChangeLogPath -Raw
    if ($ChangeLogContent -notmatch "(?ms)^## \[$([regex]::Escape($Version))\].*?(?=^## \[|\z)") {
        throw "No CHANGELOG.md entry for version [$Version], but the Deploy task reported a release was just published. Refusing to create a GitHub release without notes."
    }
    $ReleaseNotes = $Matches[0].Trim()

    $Headers = @{
        Authorization = "Bearer $env:GITHUBPAT"
        Accept        = 'application/vnd.github+json'
        'User-Agent'  = 'GitHub-Actions-Build'
    }

    # Tags the commit that triggered this run, so the release's diff shows the actual change rather than
    # mechanical build output (version bump, regenerated docs/badge).
    $ReleaseBody = @{
        tag_name         = $Tag
        target_commitish = $env:GITHUB_SHA
        name             = $Tag
        body             = $ReleaseNotes
    } | ConvertTo-Json

    Write-Output "Creating GitHub release [$Tag] for [$Owner/$Repo]`n"

    try {
        $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases" -Method 'Post' -Headers $Headers -Body $ReleaseBody -ContentType 'application/json' -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to create GitHub release [$Tag] for [$Owner/$Repo]: $_"
    }

    # Attach the zipped module built by CreateBuildArtifact as a release asset
    $ReleaseAsset = Get-ChildItem -Path $ArtifactFolder -Filter "$($env:BHProjectName)-$Tag.zip" -ErrorAction 'SilentlyContinue'
    if ($ReleaseAsset) {
        $UploadUrl = $Release.upload_url -replace '\{.*\}$', ''
        Invoke-RestMethod -Uri "$UploadUrl`?name=$($ReleaseAsset.Name)" -Method 'Post' -Headers $Headers -InFile $ReleaseAsset.FullName -ContentType 'application/zip' | Out-Null
    }
    else {
        Write-Warning "Could not find release artifact zip in [$ArtifactFolder] to attach to release [$Tag]. Run the 'CreateBuildArtifact' task first."
    }
}
