function Get-KeyedLookup {
    <#
        .SYNOPSIS
            Groups items by the value of their -Key property (or properties), keeping every item that shares a
            key value.

        .DESCRIPTION
            Returns an object with:
            - Keys: the key values, in the order they were first seen.
            - Groups: a dictionary of key value -> list of the items with that key value.

            Keys are compared case-sensitively (ordinal), so items whose keys differ only by case (e.g. readme
            and README on a case-sensitive filesystem, or a file renamed from a.txt to A.TXT) are kept apart
            rather than merged or matched with each other. A composite key is joined with a NUL character.

            A Dictionary[string, ...] is used rather than an OrderedDictionary because the latter also has a
            positional indexer, which Windows PowerShell 5.1 picks for numeric-looking keys such as '1'.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $InputObject,

        [Parameter(Mandatory)]
        [string[]]
        $Key
    )

    $Keys = [System.Collections.Generic.List[string]]::new()
    $Groups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::Ordinal)

    foreach ($Item in $InputObject) {
        if ($null -eq $Item) {
            continue
        }

        $KeyParts = foreach ($KeyName in $Key) {
            "$($Item.$KeyName)"
        }
        $KeyValue = $KeyParts -join "`0"

        if (-not $Groups.ContainsKey($KeyValue)) {
            $Groups.Add($KeyValue, [System.Collections.Generic.List[object]]::new())
            $Keys.Add($KeyValue)
        }

        $Groups[$KeyValue].Add($Item)
    }

    [PSCustomObject]@{
        Keys   = $Keys
        Groups = $Groups
    }
}
