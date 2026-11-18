$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-WatchedProperty PS$PSVersion" {

    InModuleScope Watch {

        It 'Should return nothing until the result has an item' {
            Get-WatchedProperty -InputObject @() | Should -BeNullOrEmpty
            Get-WatchedProperty -InputObject $null | Should -BeNullOrEmpty
            Get-WatchedProperty -InputObject @($null, $null) | Should -BeNullOrEmpty
        }

        It 'Should resolve the properties from the first non-null item' {
            $Items = @($null, [PSCustomObject]@{ A = 1; B = 2 }, [PSCustomObject]@{ C = 3 })

            (Get-WatchedProperty -InputObject $Items).Property | Should -Be 'A', 'B'
        }

        It 'Should apply -Property and -ExcludeProperty' {
            $Item = [PSCustomObject]@{ A = 1; B = 2; C = 3 }

            (Get-WatchedProperty -InputObject $Item -Property * -ExcludeProperty B).Property | Should -Be 'A', 'C'
        }

        It 'Should throw if a -Key property is missing' {
            { Get-WatchedProperty -InputObject ([PSCustomObject]@{ A = 1 }) -Key A, Missing } |
                Should -Throw "The property 'Missing' specified via -Key was not found*"
        }

        It 'Should throw if -ExcludeProperty leaves nothing to compare' {
            { Get-WatchedProperty -InputObject ([PSCustomObject]@{ A = 1 }) -ExcludeProperty A } |
                Should -Throw '-ExcludeProperty excludes every property*'
        }

        It 'Should return an empty list, not nothing, for an object with no properties to compare' {
            $Watched = Get-WatchedProperty -InputObject 42

            $Watched | Should -Not -BeNullOrEmpty
            @($Watched.Property).Count | Should -Be 0
        }

        It 'Should keep -Property unchanged for text, and warn that -ExcludeProperty has no effect' {
            $Watched = Get-WatchedProperty -InputObject 'line' -Property Length -ExcludeProperty Chars -WarningVariable Warnings -WarningAction SilentlyContinue

            $Watched.Property | Should -Be 'Length'
            "$($Warnings[0])" | Should -BeLike '-ExcludeProperty has no effect here*'
        }
    }
}
