function Get-PropertyChange {
    <#
        .SYNOPSIS
            Compares two versions of the same item and returns a Watch.PropertyChange object (Property,
            PreviousValue, CurrentValue) for each property whose value differs.

        .DESCRIPTION
            Mirrors Compare-Object's semantics: values that aren't IComparable (e.g. the DirectoryInfo in a
            FileSystemInfo's Parent/Root/Directory) are compared by their string form, since -ne would otherwise
            compare them by reference and flag every freshly re-queried object as changed. Properties named in
            -ExcludeProperty (the -Key properties) are skipped, since they are what pairs the two versions up.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]
        $PreviousItem,

        [Parameter(Mandatory)]
        [object]
        $CurrentItem,

        [Parameter(Mandatory)]
        [string[]]
        $Property,

        [string[]]
        $ExcludeProperty
    )

    foreach ($PropertyName in $Property) {
        if ($PropertyName -in $ExcludeProperty) {
            continue
        }

        $PreviousValue = $PreviousItem.$PropertyName
        $CurrentValue = $CurrentItem.$PropertyName

        $IsDifferent = if ($null -eq $PreviousValue -or $null -eq $CurrentValue) {
            ($null -eq $PreviousValue) -ne ($null -eq $CurrentValue)
        }
        elseif ($PreviousValue -is [System.IComparable]) {
            $PreviousValue -ne $CurrentValue
        }
        else {
            "$PreviousValue" -ne "$CurrentValue"
        }

        if ($IsDifferent) {
            # Displays as e.g. 'Length: 5 -> 10' via the ToString defined in Watch.types.ps1xml.
            [PSCustomObject]@{
                PSTypeName    = 'Watch.PropertyChange'
                Property      = $PropertyName
                PreviousValue = $PreviousValue
                CurrentValue  = $CurrentValue
            }
        }
    }
}
