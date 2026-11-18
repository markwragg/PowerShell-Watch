$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-KeyedChange PS$PSVersion" {

    InModuleScope Watch {

        BeforeAll {
            $script:Now = Get-Date
        }

        It 'Should output a composite -Key as an object with each key property' {
            $Previous = [PSCustomObject]@{ Name = 'a'; Ext = '.txt'; Size = 1 }
            $Current = [PSCustomObject]@{ Name = 'a'; Ext = '.txt'; Size = 2 }

            $Result = @(Get-KeyedChange -PreviousResult $Previous -CurrentResult $Current -Key Name, Ext -DetectedAt $script:Now)

            $Result.Count | Should -Be 1
            $Result[0].ChangeType | Should -Be 'Modified'
            $Result[0].Key.Name | Should -Be 'a'
            $Result[0].Key.Ext | Should -Be '.txt'
            $Result[0].Changes.Property | Should -Be 'Size'
        }

        It 'Should report every item of a new duplicated key as Added' {
            $Current = @(
                [PSCustomObject]@{ Name = 'dup'; Size = 1 }
                [PSCustomObject]@{ Name = 'dup'; Size = 2 }
            )

            $Result = @(Get-KeyedChange -PreviousResult @() -CurrentResult $Current -Key Name -DetectedAt $script:Now -WarningAction SilentlyContinue)

            $Result.Count | Should -Be 2
            $Result.ChangeType | Should -Be 'Added', 'Added'
            $Result.CurrentItem.Size | Should -Be 1, 2
        }

        It 'Should report every item of a vanished duplicated key as Removed' {
            $Previous = @(
                [PSCustomObject]@{ Name = 'dup'; Size = 1 }
                [PSCustomObject]@{ Name = 'dup'; Size = 2 }
            )

            $Result = @(Get-KeyedChange -PreviousResult $Previous -CurrentResult @() -Key Name -DetectedAt $script:Now -WarningAction SilentlyContinue)

            $Result.Count | Should -Be 2
            $Result.ChangeType | Should -Be 'Removed', 'Removed'
            $Result.PreviousItem.Size | Should -Be 1, 2
        }

        It 'Should warn about a duplicated key only once across calls sharing -WarnedKey' {
            $Items = @(
                [PSCustomObject]@{ Name = 'dup'; Size = 1 }
                [PSCustomObject]@{ Name = 'dup'; Size = 2 }
            )
            $Warned = [System.Collections.Generic.HashSet[string]]::new()

            $null = Get-KeyedChange -PreviousResult @() -CurrentResult $Items -Key Name -DetectedAt $script:Now -WarnedKey $Warned -WarningVariable First -WarningAction SilentlyContinue
            $null = Get-KeyedChange -PreviousResult @() -CurrentResult $Items -Key Name -DetectedAt $script:Now -WarnedKey $Warned -WarningVariable Second -WarningAction SilentlyContinue

            @($First).Count | Should -Be 1
            @($Second).Count | Should -Be 0
        }
    }
}
