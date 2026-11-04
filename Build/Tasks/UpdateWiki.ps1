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

        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git config user.name "github-actions[bot]"
        git add -A

        if (git status --porcelain) {
            git commit -m "[skip ci] GitHub Actions Build $env:GITHUB_RUN_NUMBER"
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
