Task 'Commit' -Depends 'Init' {
    $lines

    Set-Location $ProjectRoot
    $Module = $env:BHProjectName

    git --version
    git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git config --global user.name "github-actions[bot]"
    git checkout $env:GITHUB_REF_NAME

    git add Documentation/*.md
    git add README.md
    git add CHANGELOG.md
    git add $env:BHPSModuleManifest

    # Copy modified artifacts back to the source repo and stage them for commit
    if (Test-Path $ModuleArtifactsConfigPath) {
        $ModuleArtifacts = Import-PowerShellDataFile -Path $ModuleArtifactsConfigPath

        foreach ($RelativePath in $ModuleArtifacts.ModuleFiles) {
            $StagedArtifactPath = Join-Path -Path $StagingModulePath -ChildPath (Split-Path -Path $RelativePath -Leaf)
            $SourceArtifactPath = Join-Path -Path $env:BHModulePath -ChildPath $RelativePath

            if (Test-Path $StagedArtifactPath) {
                Copy-Item -Path $StagedArtifactPath -Destination $SourceArtifactPath -Force
                git add $SourceArtifactPath
            }
        }
    }

    git commit -m "[skip ci] GitHub Actions Build $env:GITHUB_RUN_NUMBER"
    git push
}
