function Skip-ExcludedItem {
    <#
        .SYNOPSIS
            Drops the items that any of the -Exclude/-ExcludePattern matchers match.

        .DESCRIPTION
            Each matcher is a [WildcardPattern] or [regex] (both have IsMatch()). When there are no matchers,
            the input is returned unchanged.

            FileSystemInfo.ToString() is the full path on .NET (PS 7) but only the name on .NET Framework
            (PS 5.1), so files are matched by FullName on both.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $InputObject,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $Matcher
    )

    if (-not $Matcher) {
        return $InputObject
    }

    foreach ($Item in $InputObject) {
        $Text = if ($Item -is [System.IO.FileSystemInfo]) { $Item.FullName } else { "$Item" }
        $IsExcluded = $false

        foreach ($Pattern in $Matcher) {
            if ($Pattern.IsMatch($Text)) {
                $IsExcluded = $true
                break
            }
        }

        if (-not $IsExcluded) {
            $Item
        }
    }
}
