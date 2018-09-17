if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

$PSVersion = $PSVersionTable.PSVersion.Major
$Root = "$PSScriptRoot\..\"
$Module = 'Watch'

If (-not (Get-Module $Module)) { Import-Module "$Root\$Module" -Force }

Describe "Watch-Command PS$PSVersion" {
    
    InModuleScope Watch {
        
        $InvokeCommand = Get-Command Invoke-Command

        Mock Invoke-Command { & $InvokeCommand -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } -Verifiable
        
        Context 'Invoked via pipeline' {
            
            Get-Date | Select-Object Hour, Minute, Second | Watch-Command

            It 'Should execute all verifiable mocks' {
                Assert-VerifiableMock
            }
            It 'Should call Invoke-Command at least 2 times' {
                Assert-MockCalled Invoke-Command -Times 2
            }
        }

        Context 'Invoked via scriptblock' {
            
            Watch-Command -ScriptBlock { Get-Date } -Difference -AsString

            It 'Should execute all verifiable mocks' {
                Assert-VerifiableMock
            }
            It 'Should call Invoke-Command at least 2 times' {
                Assert-MockCalled Invoke-Command -Times 2
            }
        }

        Context 'Invoked via wc Alias' {
            
            Get-Date | wc

            It 'Should execute all verifiable mocks' {
                Assert-VerifiableMock
            }
            It 'Should call Invoke-Command at least 2 times' {
                Assert-MockCalled Invoke-Command -Times 2
            }
        }

        Context 'Invoked via watch Alias' {
            
            Get-Date | watch

            It 'Should execute all verifiable mocks' {
                Assert-VerifiableMock
            }
            It 'Should call Invoke-Command at least 2 times' {
                Assert-MockCalled Invoke-Command -Times 2
            }
        }

        Context 'Expected exceptions' {
            It 'Should throw if a ScriptBlock is not provided unless via Pipeline' {
                { Watch-Command -ScriptBlock Get-Date } | Should -Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
            }
        }
    }
}