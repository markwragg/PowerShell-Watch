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

        .PARAMETER ExcludeProperty
            One or more property names to leave out of the comparison, so changes to them are ignored.
            Wildcards are supported (case-insensitive, e.g. 'Last*Time'). They are removed from whichever
            properties would otherwise be compared (see -Property), so they can be combined with -Property *.
            The properties are still output, as only the comparison changes. Cannot be used with -AsString.

        .PARAMETER Exclude
            One or more wildcard patterns (case-insensitive, e.g. '*Lease*'). Items whose text matches any of
            them are dropped from every result before comparing, so they are neither watched nor output. Each
            pattern must match the whole text, so use * either side to match part of it. For text output
            (e.g. from a native command, or with -AsString) this excludes matching lines. For objects it
            matches each object's string form; for files and folders that is their full path. This drops
            whole items: to ignore some of an object's properties, use -ExcludeProperty. Cannot be combined
            with -ExcludePattern.

        .PARAMETER ExcludePattern
            One or more regular expressions (case-insensitive). Works like -Exclude, but matches with regular
            expressions instead of wildcards, which match anywhere in the text unless anchored with ^ or $.
            Cannot be combined with -Exclude.

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

        .EXAMPLE
            ipconfig /all | Watch-Command -ChangeSummary -Continuous -Exclude '*Lease*'

            Monitors the network configuration for changes, excluding the lease times, which ipconfig can show
            shifting back and forth by a second between runs.

        .EXAMPLE
            ipconfig /all | Watch-Command -ChangeSummary -Continuous -ExcludePattern 'Lease (Obtained|Expires)'

            As above, but uses a regular expression to exclude only the lease time lines.

        .EXAMPLE
            Get-ChildItem C:\Temp | Watch-Command -ChangeSummary -Key Name -ExcludeProperty LastWriteTime*

            Monitors a folder like the example above, but ignores changes that only affect when the files were
            last written to.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '', Justification = 'Piped input only selects the pipeline shorthand: the piped values are discarded and the upstream commands are re-run from their source text, so there must be one watch, not one per item.')]
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

        [parameter(ParameterSetName = 'ChangeSummary')]
        [switch]
        $ChangeSummary,

        [parameter(ParameterSetName = 'ChangeSummary')]
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
        $Property,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $ExcludeProperty,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $Exclude,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $ExcludePattern
    )

    if ($Exclude -and $ExcludePattern) {
        Throw '-Exclude and -ExcludePattern cannot be used together. Use -Exclude for wildcards or -ExcludePattern for regular expressions.'
    }

    if ($ExcludeProperty) {
        if ($AsString) {
            Throw '-ExcludeProperty cannot be used with -AsString, as strings have no properties to compare.'
        }

        # Only checks the patterns are valid, so a bad one fails straight away. Resolve-WatchedProperty uses -like.
        $null = New-WildcardMatcher -Pattern $ExcludeProperty -ParameterName '-ExcludeProperty'
    }

    # Built up front, so an invalid pattern fails straight away rather than on the first check. Both
    # [WildcardPattern] and [regex] have IsMatch(). The regexes are combined into one so each item is only
    # matched once.
    $ExcludeMatchers = if ($Exclude) {
        New-WildcardMatcher -Pattern $Exclude -ParameterName '-Exclude'
    }
    elseif ($ExcludePattern) {
        try {
            [regex]::new((($ExcludePattern | ForEach-Object { "(?:$_)" }) -join '|'), 'IgnoreCase')
        }
        catch {
            Throw "-ExcludePattern contains an invalid regular expression: $($_.Exception.InnerException.Message)"
        }
    }

    # -Key only has meaning for a change summary, so it turns one on without needing -ChangeSummary too.
    if ($Key) {
        if ($AsString) {
            Throw '-Key cannot be used with -AsString, as strings have no properties to pair items up by.'
        }

        $ChangeSummary = [switch]$true
    }

    if ($ScriptBlock -isnot [scriptblock]) {
        # ExpectingInput rather than PipelinePosition: PipelinePosition only counts commands, so it is 1 for
        # pipelines that start with an expression (e.g. $Items | Watch-Command or 1..5 | Watch-Command).
        if (-not $MyInvocation.ExpectingInput) {
            Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
        }

        $CallerExtent = (Get-PSCallStack | Select-Object -Skip 1 -First 1).Position
        $PipelineText = Get-PipelineText -Invocation $MyInvocation -CallerExtent $CallerExtent

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

    $WarnedAllExcluded = $false
    $InvokeParams = @{
        ScriptBlock          = $ScriptBlock
        AsString             = $AsString
        ExcludeMatcher       = $ExcludeMatchers
        ExcludeParameterName = if ($Exclude) { '-Exclude' } else { '-ExcludePattern' }
        WarnedAllExcluded    = [ref]$WarnedAllExcluded
    }

    # The watched properties and the -Key check both need an item, which isn't available until the command
    # returns something (e.g. when watching an empty folder for the first file to appear), so they're worked
    # out from each result until there is one. -AsString results are strings, so there's nothing to work out.
    $PropertyParams = @{
        Property        = $Property
        ExcludeProperty = $ExcludeProperty
        Key             = $Key
    }
    $Initialized = [bool]$AsString

    $FirstResult = Invoke-WatchedCommand @InvokeParams

    if (-not $Initialized) {
        $Watched = Get-WatchedProperty -InputObject $FirstResult @PropertyParams

        if ($Watched) {
            $Property = $Watched.Property
            $Initialized = $true
        }
    }

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

            $Result = Invoke-WatchedCommand @InvokeParams

            if (-not $Initialized) {
                $Watched = Get-WatchedProperty -InputObject $Result @PropertyParams

                if ($Watched) {
                    $Property = $Watched.Property
                    $Initialized = $true
                }
            }

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
