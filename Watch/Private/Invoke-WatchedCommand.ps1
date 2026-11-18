function Invoke-WatchedCommand {
    <#
        .SYNOPSIS
            Runs the watched command once and returns its result, converted to strings for -AsString and with
            the items -Exclude/-ExcludePattern match left out.

        .DESCRIPTION
            If the matchers exclude every item the command returned, there is nothing to compare, so
            Watch-Command would wait without saying why. A warning explains this the first time it happens:
            pass the same -WarnedAllExcluded reference on every call so it isn't repeated on each check.
            -ExcludeParameterName is the parameter the matchers came from, for the warning.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $AsString,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $ExcludeMatcher,

        [string]
        $ExcludeParameterName,

        [Parameter(Mandatory)]
        [ref]
        $WarnedAllExcluded
    )

    $RawResult = @(Invoke-Command $ScriptBlock)

    if ($AsString) {
        $RawResult = @($RawResult | Out-String -Stream)
    }

    $KeptResult = @(Skip-ExcludedItem -InputObject $RawResult -Matcher $ExcludeMatcher)

    if ($ExcludeMatcher -and $RawResult.Count -and -not $KeptResult.Count -and -not $WarnedAllExcluded.Value) {
        $FirstItem = $RawResult[0]
        $FirstText = if ($FirstItem -is [System.IO.FileSystemInfo]) { $FirstItem.FullName } else { "$FirstItem" }

        Write-Warning "$ExcludeParameterName excluded every item the command returned, so there is nothing to watch until it returns something else. It matches each item's text (e.g. '$FirstText'), not its property names: to ignore some of an object's properties, use -ExcludeProperty."
        $WarnedAllExcluded.Value = $true
    }

    $KeptResult
}
