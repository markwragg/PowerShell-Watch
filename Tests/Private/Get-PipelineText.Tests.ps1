$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-PipelineText PS$PSVersion" {

    InModuleScope Watch {

        BeforeAll {
            function Get-TestInvocation { $MyInvocation }

            # Returns what Watch-Command passes to Get-PipelineText: its invocation and its caller's extent.
            function Get-TestCallerInfo {
                [PSCustomObject]@{
                    Invocation   = $MyInvocation
                    CallerExtent = (Get-PSCallStack)[1].Position
                }
            }
        }

        It 'Should return nothing when the command was not piped into' {
            $Invocation = & ([scriptblock]::Create('Get-TestInvocation'))
            Get-PipelineText -Invocation $Invocation | Should -BeNullOrEmpty
        }

        # Not run from a script file, as when typed interactively, so .Line holds only the last line.
        It "Should recover a multi-line pipeline from the caller's full source" {
            $Info = & ([scriptblock]::Create("`$null = 'other statement'`n1, 2 |`n    Get-TestCallerInfo"))

            $Info.Invocation.ScriptName | Should -BeNullOrEmpty
            Get-PipelineText -Invocation $Info.Invocation | Should -BeNullOrEmpty
            Get-PipelineText -Invocation $Info.Invocation -CallerExtent $Info.CallerExtent | Should -Be '1, 2'
        }
    }
}
