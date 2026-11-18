$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "New-WildcardMatcher PS$PSVersion" {

    InModuleScope Watch {

        It 'Should return a case-insensitive wildcard for each pattern' {
            $Result = @(New-WildcardMatcher -Pattern '*lease*', 'a?c' -ParameterName '-Exclude')

            $Result.Count | Should -Be 2
            $Result | Should -BeOfType [System.Management.Automation.WildcardPattern]
            $Result[0].IsMatch('LEASE Expires') | Should -BeTrue
            $Result[1].IsMatch('ABC') | Should -BeTrue
            $Result[1].IsMatch('abcd') | Should -BeFalse
        }

        It 'Should throw straight away for an invalid pattern, naming the parameter and the pattern' {
            { New-WildcardMatcher -Pattern 'ok*', '[abc' -ParameterName '-ExcludeProperty' } |
                Should -Throw "-ExcludeProperty contains an invalid wildcard pattern '``[abc'*"
        }
    }
}
