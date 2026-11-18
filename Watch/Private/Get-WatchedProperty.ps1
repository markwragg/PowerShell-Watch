function Get-WatchedProperty {
    <#
        .SYNOPSIS
            Works out which properties to compare from the first non-null item of a result, after checking
            the -Key properties exist on it.

        .DESCRIPTION
            Returns nothing if the result has no item yet (e.g. when watching an empty folder for the first
            file to appear), so call it with each result until it returns something. Then it returns an object
            whose Property is the list of properties to compare:
            - For text, which has no properties: -Property, unchanged. -ExcludeProperty has no effect, which
              is warned about.
            - Otherwise: as chosen by Resolve-WatchedProperty. If -ExcludeProperty leaves nothing, this throws,
              as Compare-Object would otherwise compare whole objects instead.

            The result is an object rather than the list itself because an empty list is a valid answer, and
            must be told apart from "no item yet".
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $InputObject,

        [string[]]
        $Property,

        [string[]]
        $ExcludeProperty,

        [string[]]
        $Key
    )

    $Sample = foreach ($Item in $InputObject) {
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

    if ($Sample -is [string]) {
        if ($ExcludeProperty) {
            Write-Warning '-ExcludeProperty has no effect here, as the command returns text, which has no properties. To leave out lines of text, use -Exclude or -ExcludePattern.'
        }

        return [PSCustomObject]@{ Property = $Property }
    }

    $Resolved = @(Resolve-WatchedProperty -InputObject $Sample -Property $Property -ExcludeProperty $ExcludeProperty)

    if ($ExcludeProperty -and -not $Resolved.Count) {
        Throw '-ExcludeProperty excludes every property that would be compared, so there is nothing left to watch.'
    }

    Write-Verbose "Watched properties: $($Resolved -join ',')"

    [PSCustomObject]@{ Property = $Resolved }
}
