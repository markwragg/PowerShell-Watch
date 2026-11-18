$PSVersion = $PSVersionTable.PSVersion.Major

Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-PipelineScriptBlock PS$PSVersion" {

    InModuleScope Watch {

        It 'Should return a plain ScriptBlock of the text when no -SessionState is given' {
            $Result = Get-PipelineScriptBlock -Text '1 + 1'

            $Result | Should -BeOfType [scriptblock]
            $Result.ToString() | Should -Be '1 + 1'
            & $Result | Should -Be 2
        }
    }
}
