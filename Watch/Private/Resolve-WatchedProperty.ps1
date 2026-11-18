function Resolve-WatchedProperty {
    <#
        .SYNOPSIS
            Works out which properties to compare, from what was passed to -Property and -ExcludeProperty and
            a sample of the watched output.

        .DESCRIPTION
            1. -Property *: every property of the sample.
            2. -Property with names: those names, as given.
            3. Otherwise the sample's default display property set (the properties shown by default), if it
               has one.
            4. Otherwise its regular properties, as chosen by Get-DefaultWatchProperty.

            Any of those that match an -ExcludeProperty wildcard (case-insensitive) are then left out. This can
            leave nothing, which the caller must handle.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]
        $InputObject,

        [string[]]
        $Property,

        [string[]]
        $ExcludeProperty
    )

    $Names = if ($Property -contains '*') {
        $InputObject.PSObject.Properties.Name
    }
    elseif ($Property) {
        $Property
    }
    else {
        $DefaultDisplay = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames

        if ($DefaultDisplay) {
            $DefaultDisplay
        }
        else {
            Get-DefaultWatchProperty -InputObject $InputObject
        }
    }

    foreach ($Name in $Names) {
        $IsExcluded = $false

        foreach ($Pattern in $ExcludeProperty) {
            if ($Name -like $Pattern) {
                $IsExcluded = $true
                break
            }
        }

        if (-not $IsExcluded) {
            $Name
        }
    }
}
