$PSVersion = $PSVersionTable.PSVersion.Major

Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-PropertyChange PS$PSVersion" {

    InModuleScope Watch {

        It 'Should report a property that changes to or from $null' {
            $WithValue = [PSCustomObject]@{ Value = 'x' }
            $WithNull = [PSCustomObject]@{ Value = $null }

            $ToNull = @(Get-PropertyChange -PreviousItem $WithValue -CurrentItem $WithNull -Property Value)
            $FromNull = @(Get-PropertyChange -PreviousItem $WithNull -CurrentItem $WithValue -Property Value)

            $ToNull.Count | Should -Be 1
            $ToNull[0].PreviousValue | Should -Be 'x'
            $ToNull[0].CurrentValue | Should -BeNullOrEmpty
            $FromNull.Count | Should -Be 1
            $FromNull[0].CurrentValue | Should -Be 'x'
        }

        It 'Should not report a property that is $null on both' {
            $Item = [PSCustomObject]@{ Value = $null }
            @(Get-PropertyChange -PreviousItem $Item -CurrentItem $Item -Property Value).Count | Should -Be 0
        }
    }
}
