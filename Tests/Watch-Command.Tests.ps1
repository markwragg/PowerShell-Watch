if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

$PSVersion = $PSVersionTable.PSVersion.Major
$Root = "$PSScriptRoot/../"
$Module = 'Watch'

Get-Module $Module | Remove-Module -Force
Start-Sleep 5

Import-Module $Root/$Module

Describe "Watch-Command PS$PSVersion" {

    InModuleScope Watch {

        BeforeAll {
            $InvokeCommand = Get-Command Invoke-Command
            Mock Invoke-Command { & $InvokeCommand -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } -Verifiable
        }

        Context 'Invoked via pipeline' {

            BeforeAll {
                Get-Date | Select-Object Hour, Minute, Second | Watch-Command
            }

            It 'Should execute all verifiable mocks' {
                Should -InvokeVerifiable
            }
            It 'Should call Invoke-Command at least 2 times' {
                Should -Invoke Invoke-Command -Times 2 -Scope Context
            }
        }

        Context 'Invoked via scriptblock' {

            BeforeAll {
                Watch-Command -ScriptBlock { Get-Date } -Difference -AsString
            }

            It 'Should execute all verifiable mocks' {
                Should -InvokeVerifiable
            }
            It 'Should call Invoke-Command at least 2 times' {
                Should -Invoke Invoke-Command -Times 2 -Scope Context
            }
        }

        Context 'Invoked via wc Alias' {

            BeforeAll {
                Get-Date | wc
            }

            It 'Should execute all verifiable mocks' {
                Should -InvokeVerifiable
            }
            It 'Should call Invoke-Command at least 2 times' {
                Should -Invoke Invoke-Command -Times 2 -Scope Context
            }
        }

        Context 'Invoked via watch Alias' {

            BeforeAll {
                Get-Date | watch
            }

            It 'Should execute all verifiable mocks' {
                Should -InvokeVerifiable
            }
            It 'Should call Invoke-Command at least 2 times' {
                Should -Invoke Invoke-Command -Times 2 -Scope Context
            }
        }

        Context 'Expected exceptions' {
            It 'Should throw if a ScriptBlock is not provided unless via Pipeline' {
                { Watch-Command -ScriptBlock Get-Date } | Should -Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
            }
        }
    }
}
