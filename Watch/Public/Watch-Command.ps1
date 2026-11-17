Function Watch-Command {
    <#
        .SYNOPSIS
            Runs a scriptblock or the preceding pipeline repeatedly until there is change.

        .DESCRIPTION
            The Watch-Command cmdlet runs a specified scriptblock repeatedly at the specified interval (or
            every 1 second by default) and returns the result of the scriptblock when the output has changed.
            For the command to work the specified scriptblock must return a result to the pipeline.

        .PARAMETER ScriptBlock
            The scriptblock to execute, specified via curly braces. If you provide input via the pipeline that
            isn't a scriptblock then the entire invocation line that preceded the cmdlet will be used as the
            scriptblock input.

        .PARAMETER Seconds
            Number of seconds to wait between checks. Default = 1

        .PARAMETER Difference
            Switch: Use to only output items in the collection that have changed
            (additions or modifications).

        .PARAMETER ChangeSummary
            Switch: Instead of returning raw objects, reports each change as a clean object with
            DetectedAt (when the change was detected), ChangeType ('Added', 'Removed' or 'Modified'), Key,
            ChangedProperties, Changes (each changed property with its PreviousValue and CurrentValue), and
            the whole item before and after the change as PreviousItem and CurrentItem. Unlike -Difference,
            this also reports items that were removed. Cannot be combined with -Difference.

            -Key is optional. Without it, changes are only reported as 'Added' or 'Removed' (a changed item
            appears as its old version removed and its new version added), and Key, ChangedProperties and
            Changes are $null. With -Key, items are paired up between checks, so a changed item is reported
            as 'Modified', with its key value in Key, the names of the properties that changed in
            ChangedProperties, and their previous and current values in Changes.

        .PARAMETER Key
            One or more property names that uniquely identify an item across checks (e.g. Name or Id).
            Items are paired up by this key between checks so that in-place changes are reported as
            'Modified' (with the specific properties that changed) rather than appearing as an unrelated
            removal and addition. Implies -ChangeSummary, so specifying -ChangeSummary as well is optional.
            Cannot be used with -Difference or -AsString.

        .PARAMETER Continuous
            Switch: Run continuously (even after a change has occurred) until exited with CTRL+C.

        .PARAMETER AsString
            Switch: Converts the result of the scriptblock into an array of strings for comparison.

        .PARAMETER ClearScreen
            Switch: Clears the screen between each different result. You can also use 'cls' as an alias.

        .PARAMETER PassThru
            Switch: Passes through the initial result from the command (before any change has occurred).

        .PARAMETER Property
            Manually specify one or more property names to be used for comparison. If not specified,
            the default display property set is used. If there is not a default display property set,
            all properties are used. You can also use '*' to force all properties.

        .EXAMPLE
            Watch-Command -ScriptBlock { Get-Process }

            Runs Get-Process and returns the result when the data has changed.

        .EXAMPLE
            Get-Service | Watch-Command -Diff -Cont

            Runs Get-Service and returns any differences in the resultant data, continuously until interrupted
            by CTRL+C.

        .EXAMPLE
            Watch-Command { Get-Content test.txt } -Difference -Verbose -ClearScreen

            Uses Get-Content to monitor test.txt. Shows any changes and clears the screen between changes.

        .EXAMPLE
            Get-ChildItem | Watch-Command -Difference -AsString

            Monitors the result of Get-ChildItem for changes, returns any differences. Treats the input as
            strings not objects.

        .EXAMPLE
            Get-Process | Watch-Command -Difference -Property processname,id -Continuous

            Monitors Get-Process for differences in the specified properties only, continues until interrupted
            by CTRL+C.

        .EXAMPLE
            Get-ChildItem C:\Temp | Watch-Command -ChangeSummary -Key Name -Continuous

            Monitors a folder and reports each change as an 'Added', 'Removed' or 'Modified' object,
            including which properties changed and their previous/current values, continuously until
            interrupted by CTRL+C.
    #>
    # Parameter sets enforce the valid combinations: -Difference and -ChangeSummary are mutually
    # exclusive, -Key implies -ChangeSummary (so can't be combined with -Difference), and -Key can't be
    # combined with -AsString.
    [cmdletbinding(DefaultParameterSetName = 'Default')]
    Param(
        [parameter(ValueFromPipeline, Mandatory, Position = 0)]
        [object]
        $ScriptBlock,

        [parameter(Position = 1)]
        [int]
        $Seconds = 1,

        [parameter(ParameterSetName = 'Difference', Mandatory)]
        [switch]
        $Difference,

        [parameter(ParameterSetName = 'ChangeSummary', Mandatory)]
        [parameter(ParameterSetName = 'ChangeSummaryKey')]
        [switch]
        $ChangeSummary,

        [parameter(ParameterSetName = 'ChangeSummaryKey', Mandatory)]
        [string[]]
        $Key,

        [switch]
        $Continuous,

        [parameter(ParameterSetName = 'Default')]
        [parameter(ParameterSetName = 'Difference')]
        [parameter(ParameterSetName = 'ChangeSummary')]
        [switch]
        $AsString,

        [alias('cls')]
        [switch]
        $ClearScreen,

        [switch]
        $PassThru,

        [parameter(Position = 2)]
        [string[]]
        $Property
    )

    # -Key only has meaning for a change summary, so it turns one on without needing -ChangeSummary too.
    if ($Key) {
        $ChangeSummary = [switch]$true
    }

    if ($ScriptBlock -isnot [scriptblock]) {
        # ExpectingInput rather than PipelinePosition: PipelinePosition only counts commands, so it is 1 for
        # pipelines that start with an expression (e.g. $Items | Watch-Command or 1..5 | Watch-Command).
        if (-not $MyInvocation.ExpectingInput) {
            Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
        }

        $PipelineText = Get-PipelineText -Invocation $MyInvocation

        if (-not $PipelineText) {
            Throw 'Could not determine the commands piped into Watch-Command. Use -ScriptBlock { ... } instead.'
        }

        $ScriptBlock = Get-PipelineScriptBlock -Text $PipelineText -SessionState $PSCmdlet.SessionState
        $Description = $PipelineText
    }
    else {
        $Description = $ScriptBlock.ToString().Trim()
    }

    Write-Verbose "Started executing $Description"

    # The watched properties and the -Key check both need a sample item, which isn't available until the
    # command returns something (e.g. when watching an empty folder for the first file to appear). This is
    # dot-sourced with each result until it has seen an item, so its assignments apply to this scope.
    $UserProperty = $Property
    $Initialized = [bool]$AsString
    $Initialize = {
        param($Items)

        if ($Initialized) {
            return
        }

        $Sample = foreach ($Item in $Items) {
            if ($null -ne $Item) {
                $Item
                break
            }
        }

        if ($null -eq $Sample) {
            return
        }

        if ($Key) {
            $AvailableProperties = $Sample.PSObject.Properties.Name

            foreach ($KeyName in $Key) {
                if ($KeyName -notin $AvailableProperties) {
                    Throw "The property '$KeyName' specified via -Key was not found on the ScriptBlock's result."
                }
            }
        }

        if ($Sample -isnot [string]) {
            $Property = Resolve-WatchedProperty -InputObject $Sample -Property $UserProperty
            Write-Verbose "Watched properties: $($Property -Join ',')"
        }

        $Initialized = $true
    }

    $FirstResult = Invoke-Command $ScriptBlock

    if ($AsString) {
        $FirstResult = $FirstResult | Out-String -Stream
    }

    . $Initialize $FirstResult

    if ($PassThru) {
        if ($ClearScreen) {
            Clear-Host
        }
        Write-Output $FirstResult
    }

    # Warn about each duplicated -Key value only once, rather than on every check.
    $WarnedKey = [System.Collections.Generic.HashSet[string]]::new()
    $IsFirstCheck = $true

    do {
        do {
            # The first check runs straight away; every later one waits, including when the command returned
            # nothing (previously an empty result skipped the wait and re-ran the command without pausing).
            if (-not $IsFirstCheck) {
                Start-Sleep $Seconds
            }
            $IsFirstCheck = $false

            $Result = Invoke-Command $ScriptBlock

            if ($AsString) {
                $Result = $Result | Out-String -Stream
            }

            . $Initialize $Result

            $CompareParams = @{
                ReferenceObject  = @($FirstResult | Select-Object)
                DifferenceObject = @($Result | Select-Object)
            }

            if ($Property) {
                $CompareParams.Add('Property', $Property)
            }

            $Diff = Compare-Object @CompareParams -PassThru
        }
        until ($Diff)

        # Captured once per check so every change found in the same check shares one timestamp.
        $DetectedAt = Get-Date

        $Output = @(
            if ($ChangeSummary) {
                if ($Key) {
                    # Compare-Object -PassThru attaches SideIndicator to the original objects it returns. Remove
                    # it so it isn't reported as part of PreviousItem/CurrentItem.
                    foreach ($DiffItem in $Diff) {
                        $DiffItem.PSObject.Properties.Remove('SideIndicator')
                    }

                    Get-KeyedChange -PreviousResult @($FirstResult) -CurrentResult @($Result) -Key $Key -Property $Property -DetectedAt $DetectedAt -WarnedKey $WarnedKey
                }
                else {
                    Get-UnkeyedChange -Difference @($Diff) -DetectedAt $DetectedAt
                }
            }
            elseif ($Difference) {
                $Diff | Where-Object { $_.SideIndicator -eq '=>' }
            }
            else {
                $Result
            }
        )

        # A change summary compares items itself (pairing them up by -Key), so in rare cases it can find
        # nothing to report for a difference Compare-Object found. Treat that as no change and keep watching,
        # rather than returning with no output.
        $Reported = -not $ChangeSummary -or $Output.Count -gt 0

        if ($Reported) {
            if ($ClearScreen) {
                Clear-Host
            }

            Write-Verbose "Change occurred at $DetectedAt"

            $Output
        }
        else {
            Write-Verbose "A difference was detected at $DetectedAt but no change could be summarised. Still watching."
        }

        $FirstResult = $Result
    }
    until ($Reported -and -not $Continuous)
}
