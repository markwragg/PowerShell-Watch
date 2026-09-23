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

        Context 'Default property selection excludes computed properties (regression for #3)' {

            BeforeAll {
                # Compare-Object is mocked so the comparison properties it's called with can be inspected
                # directly, and so the do-until loop exits after a single comparison instead of waiting for
                # a real difference.
                $script:CapturedProperty = $null
                Mock Compare-Object {
                    $script:CapturedProperty = $Property
                    [pscustomobject]@{ SideIndicator = '=>' }
                }

                # A FileInfo's Target/LinkType members behave the same way: no DefaultDisplayPropertySet,
                # and a computed property that throws when the item it refers to no longer exists.
                $Obj = [pscustomobject]@{ Name = 'a.txt'; Length = 5 }
                $Obj | Add-Member -MemberType ScriptProperty -Name 'Target' -Value { throw 'Simulated live property failure' }

                Watch-Command -ScriptBlock { $Obj } -Seconds 1 | Out-Null
            }

            It 'Should not include computed (ScriptProperty) members in the comparison' {
                $CapturedProperty | Should -Not -Contain 'Target'
            }

            It 'Should still include real data properties in the comparison' {
                $CapturedProperty | Should -Contain 'Name'
                $CapturedProperty | Should -Contain 'Length'
            }
        }

        Context 'Explicit -Property parameter is used as-is' {

            BeforeAll {
                $script:CapturedProperty = $null
                Mock Compare-Object {
                    $script:CapturedProperty = $Property
                    [pscustomobject]@{ SideIndicator = '=>' }
                }

                Watch-Command -ScriptBlock { [pscustomobject]@{ Name = 'a'; Length = 1 } } -Property 'Name' -Seconds 1 | Out-Null
            }

            It 'Should use exactly the specified property' {
                $CapturedProperty | Should -Be 'Name'
            }
        }

        Context 'Explicit -Property * forces every property, including computed ones' {

            BeforeAll {
                $script:CapturedProperty = $null
                Mock Compare-Object {
                    $script:CapturedProperty = $Property
                    [pscustomobject]@{ SideIndicator = '=>' }
                }

                $Obj = [pscustomobject]@{ Name = 'a' }
                $Obj | Add-Member -MemberType ScriptProperty -Name 'Computed' -Value { 'x' }

                Watch-Command -ScriptBlock { $Obj } -Property '*' -Seconds 1 | Out-Null
            }

            It 'Should include the computed property when * is explicitly requested' {
                $CapturedProperty | Should -Contain 'Computed'
            }
        }

        Context 'Invoked with -Difference' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Id = 1 }
                    }
                    else {
                        [pscustomobject]@{ Id = 1 }
                        [pscustomobject]@{ Id = 2 }
                    }
                }

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -Difference
            }

            It 'Should only return the item that was added' {
                $Result.Id | Should -Be 2
                $Result.SideIndicator | Should -Be '=>'
            }
        }

        Context 'Invoked without -Difference' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Id = 1 }
                    }
                    else {
                        [pscustomobject]@{ Id = 1 }
                        [pscustomobject]@{ Id = 2 }
                    }
                }

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1
            }

            It 'Should return the entire new result set, not just the difference' {
                $Result.Id | Should -Be @(1, 2)
            }
        }

        Context 'Invoked with -PassThru' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -le 2) {
                        [pscustomobject]@{ Id = 1 }
                    }
                    else {
                        [pscustomobject]@{ Id = 2 }
                    }
                }

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -PassThru
            }

            It 'Should emit the initial result immediately, before any change has occurred' {
                $Result[0].Id | Should -Be 1
            }

            It 'Should also emit the result once a change occurs' {
                $Result[-1].Id | Should -Be 2
            }
        }

        Context 'Invoked with -ClearScreen' {

            BeforeAll {
                Mock Clear-Host {}

                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Id = 1 }
                    }
                    else {
                        [pscustomobject]@{ Id = 2 }
                    }
                }

                Watch-Command -ScriptBlock $Sb -Seconds 1 -ClearScreen | Out-Null
            }

            It 'Should clear the screen once a change is detected' {
                Should -Invoke Clear-Host -Times 1 -Scope Context
            }
        }
    }
}
