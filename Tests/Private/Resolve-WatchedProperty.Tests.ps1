$PSVersion = $PSVersionTable.PSVersion.Major

Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Resolve-WatchedProperty PS$PSVersion" {

    InModuleScope Watch {

        It "Should use the item's default display property set when -Property isn't given" {
            $Item = [PSCustomObject]@{ A = 1; B = 2; C = 3 }
            $DisplaySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', [string[]]('A', 'C'))
            $Item | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value ([System.Management.Automation.PSMemberInfo[]]$DisplaySet)

            Resolve-WatchedProperty -InputObject $Item | Should -Be 'A', 'C'
        }

        It 'Should leave out properties matching -ExcludeProperty, case-insensitively' {
            $Item = [PSCustomObject]@{ Name = 'a'; LastWriteTime = 1; LastWriteTimeUtc = 2; Size = 3 }

            Resolve-WatchedProperty -InputObject $Item -Property * -ExcludeProperty 'lastwrite*' | Should -Be 'Name', 'Size'
            Resolve-WatchedProperty -InputObject $Item -Property Name, Size -ExcludeProperty Size | Should -Be 'Name'
        }

        It 'Should return nothing when -ExcludeProperty matches every property' {
            $Item = [PSCustomObject]@{ A = 1 }
            @(Resolve-WatchedProperty -InputObject $Item -ExcludeProperty *).Count | Should -Be 0
        }
    }
}
