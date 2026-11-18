$PSVersion = $PSVersionTable.PSVersion.Major

Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Skip-ExcludedItem PS$PSVersion" {

    InModuleScope Watch {

        It 'Should return the input unchanged when there are no matchers' {
            $Result = @(Skip-ExcludedItem -InputObject 'a', 'b' -Matcher $null)
            $Result | Should -Be 'a', 'b'
        }

        It 'Should return nothing for empty or null input' {
            $Matcher = [regex]::new('a')
            @(Skip-ExcludedItem -InputObject @() -Matcher $Matcher).Count | Should -Be 0
            @(Skip-ExcludedItem -InputObject $null -Matcher $Matcher).Count | Should -Be 0
        }

        It 'Should drop items that any matcher matches and keep the rest in order' {
            $Matcher = [WildcardPattern]::new('*noise*', 'IgnoreCase'), [WildcardPattern]::new('skip*', 'IgnoreCase')
            $Result = @(Skip-ExcludedItem -InputObject 'keep1', 'NOISE here', 'skip me', 'keep2' -Matcher $Matcher)
            $Result | Should -Be 'keep1', 'keep2'
        }

        It 'Should match a regex matcher anywhere in the text' {
            $Matcher = [regex]::new('lease', 'IgnoreCase')
            $Result = @(Skip-ExcludedItem -InputObject 'Lease Obtained', 'DHCP Enabled' -Matcher $Matcher)
            $Result | Should -Be 'DHCP Enabled'
        }

        It 'Should match files by their full path rather than their name' {
            $Folder = Join-Path $TestDrive 'remove-excluded'
            $null = New-Item -Path $Folder -ItemType Directory -Force
            Set-Content -Path (Join-Path $Folder 'app.log') -Value 'a'
            Set-Content -Path (Join-Path $Folder 'data.txt') -Value 'a'
            $Files = Get-ChildItem -Path $Folder

            $ByPath = [WildcardPattern]::new("$Folder\*.log", 'IgnoreCase')
            $Result = @(Skip-ExcludedItem -InputObject $Files -Matcher $ByPath)
            $Result.Name | Should -Be 'data.txt'

            # A name-only pattern must match the whole full path, so it excludes nothing.
            $ByName = [WildcardPattern]::new('app.log', 'IgnoreCase')
            @(Skip-ExcludedItem -InputObject $Files -Matcher $ByName).Count | Should -Be 2
        }
    }
}
