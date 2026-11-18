$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Invoke-WatchedCommand PS$PSVersion" {

    InModuleScope Watch {

        It 'Should return the result unchanged without -AsString or matchers' {
            $Warned = $false
            $Result = @(Invoke-WatchedCommand -ScriptBlock { 1, 2 } -WarnedAllExcluded ([ref]$Warned))

            $Result | Should -Be 1, 2
        }

        It 'Should return nothing, not $null, when the command returns nothing' {
            $Warned = $false
            @(Invoke-WatchedCommand -ScriptBlock { } -WarnedAllExcluded ([ref]$Warned)).Count | Should -Be 0
        }

        It 'Should convert the result to lines with -AsString, then leave out excluded lines' {
            $Warned = $false
            $Params = @{
                ScriptBlock       = { [PSCustomObject]@{ Name = 'a' } }
                AsString          = $true
                ExcludeMatcher    = [regex]::new('^\s*$')
                WarnedAllExcluded = [ref]$Warned
            }

            $Result = @(Invoke-WatchedCommand @Params)

            # Windows PowerShell 5.1 pads table rows with trailing spaces.
            $Result | Should -BeOfType [string]
            $Result.TrimEnd() | Should -Contain 'a'
            $Result | Should -Not -Contain ''
        }

        It 'Should warn only once, through -WarnedAllExcluded, when every item is excluded' {
            $Warned = $false
            $Params = @{
                ScriptBlock          = { 'noise' }
                ExcludeMatcher       = [regex]::new('noise')
                ExcludeParameterName = '-ExcludePattern'
                WarnedAllExcluded    = [ref]$Warned
            }

            $null = Invoke-WatchedCommand @Params -WarningVariable First -WarningAction SilentlyContinue
            $null = Invoke-WatchedCommand @Params -WarningVariable Second -WarningAction SilentlyContinue

            $Warned | Should -BeTrue
            "$($First[0])" | Should -BeLike "-ExcludePattern excluded every item*'noise'*"
            @($Second).Count | Should -Be 0
        }
    }
}
