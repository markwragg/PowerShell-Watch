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

        Context 'Pipeline shorthand only re-runs the commands piped into Watch-Command' {

            It 'Should ignore an assignment before the pipeline' {
                $Assigned = Get-Date | Select-Object Second | Watch-Command
                $Assigned.Second | Should -BeOfType [int]
            }

            It 'Should ignore statements before a ; and commands after Watch-Command' {
                $null = 'x'; $Piped = Get-Date | Select-Object Second | Watch-Command | ForEach-Object { $_.Second }
                $Piped | Should -BeOfType [int]
            }

            It 'Should recover a pipeline that spans several lines' {
                $MultiLine = Get-Date |
                    Select-Object Second |
                    Watch-Command
                $MultiLine.Second | Should -BeOfType [int]
            }

            It 'Should accept a pipeline that starts with an expression' {
                $Expression = (Get-Date).Second | Watch-Command
                $Expression | Should -BeOfType [int]
            }

            It "Should run the piped commands in the caller's scope, so they can see its local variables" {
                function Test-CallerLocal {
                    $LocalFormat = 'ss'
                    Get-Date -Format $LocalFormat | Watch-Command
                }
                Test-CallerLocal | Should -Match '^\d{2}$'
            }
        }

        Context 'Get-UpstreamPipelineText' {

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

        Context 'Expected exceptions' {
            It 'Should throw if a ScriptBlock is not provided unless via Pipeline' {
                { Watch-Command -ScriptBlock Get-Date } | Should -Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
            }

            It 'Should reject -ChangeSummary and -Difference together (parameter sets)' {
                { Watch-Command -ScriptBlock { [pscustomobject]@{ Id = 1 } } -ChangeSummary -Difference } |
                    Should -Throw -ErrorId 'AmbiguousParameterSet,Watch-Command'
            }

            It 'Should reject -Key combined with -Difference, since -Key implies -ChangeSummary (parameter sets)' {
                { Watch-Command -ScriptBlock { [pscustomobject]@{ Id = 1 } } -Key Id -Difference } |
                    Should -Throw -ErrorId 'AmbiguousParameterSet,Watch-Command'
            }

            It 'Should reject -Key combined with -AsString (parameter sets)' {
                { Watch-Command -ScriptBlock { [pscustomobject]@{ Id = 1 } } -ChangeSummary -Key Id -AsString } |
                    Should -Throw -ErrorId 'AmbiguousParameterSet,Watch-Command'
            }

            It 'Should keep -Property as the third positional parameter, as in previous releases' {
                (Get-Command Watch-Command).Parameters['Property'].ParameterSets.Values.Position | Select-Object -Unique | Should -Be 2
                (Get-Command Watch-Command).Parameters['Key'].ParameterSets.Values.Position | Select-Object -Unique | Should -BeLessThan 0
            }

            It 'Should throw if -Key names a property that does not exist on the result' {
                { Watch-Command -ScriptBlock { [pscustomobject]@{ Id = 1 } } -ChangeSummary -Key Nonexistent } |
                    Should -Throw "The property 'Nonexistent' specified via -Key was not found on the ScriptBlock's result."
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

        Context 'Default property selection excludes last-access times' {

            BeforeAll {
                $script:CapturedProperty = $null
                Mock Compare-Object {
                    $script:CapturedProperty = $Property
                    [pscustomobject]@{ SideIndicator = '=>' }
                }

                # A DirectoryInfo has no DefaultDisplayPropertySet, so it falls back to comparing every property.
                Watch-Command -ScriptBlock { Get-Item $TestDrive } -Seconds 1 | Out-Null
            }

            It 'Should not include LastAccessTime or LastAccessTimeUtc, which change when an item is merely read' {
                $CapturedProperty | Should -Not -Contain 'LastAccessTime'
                $CapturedProperty | Should -Not -Contain 'LastAccessTimeUtc'
            }

            It 'Should still include the other timestamps' {
                $CapturedProperty | Should -Contain 'LastWriteTime'
                $CapturedProperty | Should -Contain 'CreationTime'
            }
        }

        Context 'Last-access times can still be watched when named explicitly' {

            BeforeAll {
                $script:CapturedProperty = $null
                Mock Compare-Object {
                    $script:CapturedProperty = $Property
                    [pscustomobject]@{ SideIndicator = '=>' }
                }

                Watch-Command -ScriptBlock { Get-Item $TestDrive } -Property 'Name', 'LastAccessTime' -Seconds 1 | Out-Null
            }

            It 'Should use LastAccessTime when it is passed to -Property' {
                $CapturedProperty | Should -Be @('Name', 'LastAccessTime')
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

        Context 'Invoked with -ChangeSummary (no -Key): item added' {

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

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -ChangeSummary
            }

            It 'Should report the new item as Added' {
                $Result.ChangeType | Should -Be 'Added'
                $Result.CurrentItem.Id | Should -Be 2
                $Result.PreviousItem | Should -BeNullOrEmpty
            }

            It 'Should not leak the SideIndicator property added internally by Compare-Object' {
                $Result.CurrentItem.PSObject.Properties.Name | Should -Not -Contain 'SideIndicator'
            }
        }

        Context 'Invoked with -ChangeSummary (no -Key): item removed' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Id = 1 }
                        [pscustomobject]@{ Id = 2 }
                    }
                    else {
                        [pscustomobject]@{ Id = 1 }
                    }
                }

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -ChangeSummary
            }

            It 'Should report the missing item as Removed' {
                $Result.ChangeType | Should -Be 'Removed'
                $Result.PreviousItem.Id | Should -Be 2
                $Result.CurrentItem | Should -BeNullOrEmpty
            }
        }

        Context 'Invoked with -ChangeSummary (no -Key): .NET objects such as FileInfo are labelled correctly' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [System.IO.FileInfo]::new((Join-Path $TestDrive 'old.txt'))
                    }
                    else {
                        [System.IO.FileInfo]::new((Join-Path $TestDrive 'new.txt'))
                    }
                }

                $script:Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -ChangeSummary -Property Name
            }

            It 'Should report the new item as Added and the old one as Removed (not both as Removed)' {
                ($script:Result | Where-Object ChangeType -EQ 'Added').CurrentItem.Name | Should -Be 'new.txt'
                ($script:Result | Where-Object ChangeType -EQ 'Removed').PreviousItem.Name | Should -Be 'old.txt'
            }
        }

        Context 'Invoked with -ChangeSummary -Key: Added, Removed and Modified in one pass' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Id = 1; Status = 'Running' }
                        [pscustomobject]@{ Id = 2; Status = 'Running' }
                    }
                    else {
                        [pscustomobject]@{ Id = 1; Status = 'Stopped' }
                        [pscustomobject]@{ Id = 3; Status = 'Running' }
                    }
                }

                $Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -ChangeSummary -Key Id

                $script:ModifiedResult = $Result | Where-Object ChangeType -EQ 'Modified'
                $script:AddedResult = $Result | Where-Object ChangeType -EQ 'Added'
                $script:RemovedResult = $Result | Where-Object ChangeType -EQ 'Removed'
            }

            It 'Should report the changed item as Modified, naming only the properties that changed' {
                $script:ModifiedResult.Key | Should -Be 1
                $script:ModifiedResult.ChangedProperties | Should -Be 'Status'
                $script:ModifiedResult.PreviousItem.Status | Should -Be 'Running'
                $script:ModifiedResult.CurrentItem.Status | Should -Be 'Stopped'
            }

            It 'Should list each changed property with its previous and current value in Changes' {
                $script:ModifiedResult.Changes.Count | Should -Be 1
                $script:ModifiedResult.Changes[0].Property | Should -Be 'Status'
                $script:ModifiedResult.Changes[0].PreviousValue | Should -Be 'Running'
                $script:ModifiedResult.Changes[0].CurrentValue | Should -Be 'Stopped'
                "$($script:ModifiedResult.Changes[0])" | Should -Be 'Status: Running -> Stopped'
            }

            It 'Should leave Changes empty for Added and Removed items' {
                $script:AddedResult.Changes | Should -BeNullOrEmpty
                $script:RemovedResult.Changes | Should -BeNullOrEmpty
            }

            It 'Should report the new item as Added, keyed by Id' {
                $script:AddedResult.Key | Should -Be 3
                $script:AddedResult.CurrentItem.Id | Should -Be 3
            }

            It 'Should report the missing item as Removed, keyed by Id' {
                $script:RemovedResult.Key | Should -Be 2
                $script:RemovedResult.PreviousItem.Id | Should -Be 2
            }

            It 'Should not leak the SideIndicator property added internally by Compare-Object onto PreviousItem/CurrentItem' {
                $script:ModifiedResult.PreviousItem.PSObject.Properties.Name | Should -Not -Contain 'SideIndicator'
                $script:ModifiedResult.CurrentItem.PSObject.Properties.Name | Should -Not -Contain 'SideIndicator'
                $script:AddedResult.CurrentItem.PSObject.Properties.Name | Should -Not -Contain 'SideIndicator'
                $script:RemovedResult.PreviousItem.PSObject.Properties.Name | Should -Not -Contain 'SideIndicator'
            }

            It 'Should tag every summary object with the Watch.ChangeSummary type name' {
                foreach ($Item in @($script:ModifiedResult, $script:AddedResult, $script:RemovedResult)) {
                    $Item.PSObject.TypeNames[0] | Should -Be 'Watch.ChangeSummary'
                }
            }

            It 'Should stamp every summary object from the same check with one shared DetectedAt datetime' {
                $Stamps = @($script:ModifiedResult, $script:AddedResult, $script:RemovedResult).DetectedAt
                $Stamps | ForEach-Object { $_ | Should -BeOfType [datetime] }
                @($Stamps | Select-Object -Unique).Count | Should -Be 1
                $Stamps[0] | Should -BeLessOrEqual (Get-Date)
                $Stamps[0] | Should -BeGreaterThan (Get-Date).AddMinutes(-5)
            }

            It 'Should have a fixed-width table view registered for Watch.ChangeSummary (so -Continuous output is not buffered)' {
                $View = Get-FormatData -TypeName 'Watch.ChangeSummary'
                $View | Should -Not -BeNullOrEmpty
                $Headers = $View.FormatViewDefinition[0].Control.Headers
                $Headers.Label | Should -Be @('Time', 'ChangeType', 'Key', 'Details')
                $Headers[0..2].Width | Should -Not -Contain 0
            }

            It 'Should render the table view without error' {
                $Rendered = $Result | Format-Table | Out-String
                $Rendered | Should -Match '\d{2}:\d{2}:\d{2}\s+Modified\s+1\s+Status: Running -> Stopped'
            }
        }

        Context 'Invoked with -Key when the first result is empty' {

            BeforeAll {
                Mock Start-Sleep {}
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    # Empty for the first result, the immediate first check and one more check.
                    if ($script:CallCount -ge 4) {
                        [pscustomobject]@{ Name = 'first.txt'; Length = 1 }
                    }
                }

                $script:Result = Watch-Command -ScriptBlock $Sb -Key Name
            }

            It 'Should not throw, and should report the first item to appear as Added' {
                $script:Result.ChangeType | Should -Be 'Added'
                $script:Result.Key | Should -Be 'first.txt'
            }

            It 'Should still wait between checks while the command returns nothing' {
                Should -Invoke Start-Sleep -Times 2 -Exactly -Scope Context
            }

            It 'Should still validate -Key once an item appears' {
                $script:CallCount = 0
                { Watch-Command -ScriptBlock $Sb -Key Nonexistent } |
                    Should -Throw "The property 'Nonexistent' specified via -Key was not found on the ScriptBlock's result."
            }
        }

        Context 'Invoked with -Key when several items share a key value' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    # Only the first of the two 'svchost' items changes.
                    [pscustomobject]@{ Name = 'svchost'; Id = 1; Cpu = $script:CallCount }
                    [pscustomobject]@{ Name = 'svchost'; Id = 2; Cpu = 1 }
                }

                $script:Result = @(Watch-Command -ScriptBlock $Sb -Key Name -Property Cpu -WarningVariable script:Warnings -WarningAction SilentlyContinue)
            }

            It 'Should still report the change, as Removed and Added rows for that key' {
                ($script:Result | Where-Object ChangeType -EQ 'Removed').PreviousItem.Id | Should -Be 1
                ($script:Result | Where-Object ChangeType -EQ 'Added').CurrentItem.Id | Should -Be 1
                $script:Result.Key | Select-Object -Unique | Should -Be 'svchost'
            }

            It 'Should warn that the key value is not unique' {
                $script:Warnings | Should -HaveCount 1
                "$($script:Warnings[0])" | Should -Match "share the -Key value 'svchost'"
            }
        }

        Context 'Invoked with -Key when key values differ only by case' {

            BeforeAll {
                # Length changes too because Compare-Object, which decides whether anything changed, ignores case.
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Name = 'a.txt'; Length = 1 }
                    }
                    else {
                        [pscustomobject]@{ Name = 'A.TXT'; Length = 2 }
                    }
                }

                $script:Result = @(Watch-Command -ScriptBlock $Sb -Key Name)
            }

            It 'Should report the old and new names once each, as Removed and Added' {
                $script:Result | Should -HaveCount 2
                ($script:Result | Where-Object ChangeType -EQ 'Removed').Key | Should -BeExactly 'a.txt'
                ($script:Result | Where-Object ChangeType -EQ 'Added').Key | Should -BeExactly 'A.TXT'
            }
        }

        Context 'Invoked with -ChangeSummary when a detected difference has nothing to summarise' {

            BeforeAll {
                Mock Start-Sleep {}
                $script:RealCompareObject = Get-Command Compare-Object -CommandType Cmdlet
                $script:CompareCount = 0
                Mock Compare-Object {
                    $script:CompareCount++
                    if ($script:CompareCount -eq 1) {
                        # A difference the keyed comparison won't agree with: the items are identical.
                        [pscustomobject]@{ SideIndicator = '=>' }
                    }
                    else {
                        $Params = @{ ReferenceObject = $ReferenceObject; DifferenceObject = $DifferenceObject; PassThru = $PassThru }
                        if ($Property) {
                            $Params.Property = $Property
                        }
                        & $script:RealCompareObject @Params
                    }
                }

                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    [pscustomobject]@{ Id = 1; Status = if ($script:CallCount -le 2) { 'Running' } else { 'Stopped' } }
                }

                $script:Result = @(Watch-Command -ScriptBlock $Sb -Key Id)
            }

            It 'Should keep watching instead of returning nothing, and report the next real change' {
                $script:Result | Should -HaveCount 1
                $script:Result.ChangeType | Should -Be 'Modified'
                $script:Result.ChangedProperties | Should -Be 'Status'
            }
        }

        Context 'Verbose output describes the watched command' {

            It 'Should show the piped commands when using the pipeline shorthand' {
                $Verbose = Get-Date | Select-Object Second | Watch-Command -Verbose 4>&1 |
                    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] -and $_.Message -like 'Started executing*' }
                $Verbose.Message | Should -Be 'Started executing Get-Date | Select-Object Second'
            }

            It 'Should show the ScriptBlock when one is passed' {
                $Verbose = Watch-Command -ScriptBlock { (Get-Date).Second } -Verbose 4>&1 |
                    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] -and $_.Message -like 'Started executing*' }
                $Verbose.Message | Should -Be 'Started executing (Get-Date).Second'
            }
        }

        Context 'Invoked with -Key alone: implies -ChangeSummary' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    [pscustomobject]@{ Id = 1; Status = if ($script:CallCount -eq 1) { 'Running' } else { 'Stopped' } }
                }

                $script:Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -Key Id
            }

            It 'Should return a change summary with the item reported as Modified' {
                $script:Result.PSObject.TypeNames[0] | Should -Be 'Watch.ChangeSummary'
                $script:Result.ChangeType | Should -Be 'Modified'
                $script:Result.Key | Should -Be 1
                $script:Result.ChangedProperties | Should -Be 'Status'
            }
        }

        Context 'Invoked with -ChangeSummary -Key: object-valued properties are compared by value, not reference' {

            BeforeAll {
                $script:CallCount = 0
                $Sb = {
                    $script:CallCount++
                    # Each call creates new DirectoryInfo instances, mimicking Get-ChildItem's Parent/Root.
                    $Parent = [System.IO.DirectoryInfo]::new('C:\Temp')
                    if ($script:CallCount -eq 1) {
                        [pscustomobject]@{ Name = 'a'; Parent = $Parent; Status = 'Running' }
                        [pscustomobject]@{ Name = 'b'; Parent = $Parent; Status = 'Running' }
                    }
                    else {
                        [pscustomobject]@{ Name = 'a'; Parent = $Parent; Status = 'Running' }
                    }
                }

                $script:Result = Watch-Command -ScriptBlock $Sb -Seconds 1 -ChangeSummary -Key Name
            }

            It 'Should report only the removed item, not unchanged items with equivalent object-valued properties' {
                @($script:Result).Count | Should -Be 1
                $script:Result.ChangeType | Should -Be 'Removed'
                $script:Result.Key | Should -Be 'b'
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
