$PSVersion = $PSVersionTable.PSVersion.Major

# Remove any copy already loaded (e.g. the staged build) first: Windows PowerShell 5.1 can't re-import
# Watch.types.ps1xml over an existing one ("The member ToString is already present"), which fails Discovery.
Get-Module Watch | Remove-Module -Force
Import-Module "$PSScriptRoot/../../Watch" -Force

Describe "Get-UpstreamPipelineText PS$PSVersion" {

    InModuleScope Watch {

        BeforeAll {
            function Get-TestUpstream ($Source, $Line, $Column) {
                $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$null, [ref]$null)
                Get-UpstreamPipelineText -Ast $Ast -LineNumber $Line -ColumnNumber $Column
            }
        }

        It 'Should return only the elements before the command, excluding assignments and later elements' {
            Get-TestUpstream '$r = Get-ChildItem C:\Temp | Sort-Object Name | Watch-Command -Seconds 2 | Format-Table' 1 49 |
                Should -Be 'Get-ChildItem C:\Temp | Sort-Object Name'
        }

        It 'Should find the command on a later line of a multi-line pipeline' {
            Get-TestUpstream "Get-Process |`n    Where-Object CPU |`n    Watch-Command" 3 5 |
                Should -Be 'Get-Process | Where-Object CPU'
        }

        It 'Should return nothing when the command is first in its pipeline' {
            Get-TestUpstream 'Watch-Command { Get-Date }' 1 1 | Should -BeNullOrEmpty
        }

        It 'Should return nothing when no command starts at the given position' {
            Get-TestUpstream 'Get-Date | Watch-Command' 1 5 | Should -BeNullOrEmpty
        }
    }
}
