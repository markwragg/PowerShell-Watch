$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
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
