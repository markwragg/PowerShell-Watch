$PSVersion = $PSVersionTable.PSVersion.Major

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
