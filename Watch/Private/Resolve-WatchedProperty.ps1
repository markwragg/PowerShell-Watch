function Resolve-WatchedProperty {
    <#
        .SYNOPSIS
            Works out which properties to compare, from what was passed to -Property and a sample of the
            watched output.

        .DESCRIPTION
            1. -Property *: every property of the sample.
            2. -Property with names: those names, as given.
            3. Otherwise the sample's default display property set (the properties shown by default), if it
               has one.
            4. Otherwise its regular properties, as chosen by Get-DefaultWatchProperty.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]
        $InputObject,

        [string[]]
        $Property
    )

    if ($Property -contains '*') {
        return $InputObject.PSObject.Properties.Name
    }

    if ($Property) {
        return $Property
    }

    $DefaultDisplay = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames

    if ($DefaultDisplay) {
        return $DefaultDisplay
    }

    Get-DefaultWatchProperty -InputObject $InputObject
}
