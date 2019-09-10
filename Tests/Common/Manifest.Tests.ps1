# Vars
$changelogPath = Join-Path -Path $env:BHProjectPath -Child 'CHANGELOG.md'

Describe 'Module manifest' {
    Context 'Validation' {

        $script:manifest = $null

        It 'Has a valid manifest' {
            {
                $script:manifest = Test-ModuleManifest -Path $env:BHPSModuleManifest -Verbose:$false -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'
            } | Should Not Throw
        }

        It 'Has a valid name in the manifest' {
            $script:manifest.Name | Should Be $env:BHProjectName
        }

        It 'Has a valid root module' {
            $script:manifest.RootModule | Should Be "$($env:BHProjectName).psm1"
        }

        It 'Has a valid version in the manifest' {
            $script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
        }

        It 'Has a valid description' {
            $script:manifest.Description | Should Not BeNullOrEmpty
        }

        It 'Has a valid author' {
            $script:manifest.Author | Should Not BeNullOrEmpty
        }

        It 'Has a valid guid' {
            {
                [guid]::Parse($script:manifest.Guid)
            } | Should Not throw
        }

        It 'Has a valid copyright' {
            $script:manifest.CopyRight | Should Not BeNullOrEmpty
        }

        # Only for DSC modules
        # It 'exports DSC resources' {
        #     $dscResources = ($Manifest.psobject.Properties | Where Name -eq 'ExportedDscResources').Value
        #     @($dscResources).Count | Should Not Be 0
        # }

        $script:changelogVersion = $null
        It 'Has a valid version in the changelog' -Skip {
            foreach ($line in (Get-Content $changelogPath)) {
                if ($line -match "^##\s\[(?<Version>(\d+\.){1,3}\d+)\]") {
                    $script:changelogVersion = $matches.Version
                    break
                }
            }
            $script:changelogVersion               | Should Not BeNullOrEmpty
            $script:changelogVersion -as [Version] | Should Not BeNullOrEmpty
        }

        It 'Has matching changelog and manifest versions' -Skip {
            $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
        }

        if (Get-Command -Name 'git.exe' -ErrorAction 'SilentlyContinue') {
            $script:tagVersion = $null

            # Skipped as we tag as part of CI build
            It 'Is tagged with a valid version' -skip {
                $thisCommit = git.exe log --decorate --oneline HEAD~1..HEAD

                if ($thisCommit -match 'tag:\s*(\d+(?:\.\d+)*)') {
                    $script:tagVersion = $matches[1]
                }

                $script:tagVersion               | Should Not BeNullOrEmpty
                $script:tagVersion -as [Version] | Should Not BeNullOrEmpty
            }
        }
    }
}
