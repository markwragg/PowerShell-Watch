function New-ChangeSummary {
    <#
        .SYNOPSIS
            Creates a Watch.ChangeSummary object, the single definition of the objects -ChangeSummary outputs.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only creates an in-memory object.')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [datetime]
        $DetectedAt,

        [Parameter(Mandatory)]
        [ValidateSet('Added', 'Removed', 'Modified')]
        [string]
        $ChangeType,

        [object]
        $Key,

        [object[]]
        $Changes,

        [object]
        $PreviousItem,

        [object]
        $CurrentItem
    )

    [PSCustomObject]@{
        PSTypeName        = 'Watch.ChangeSummary'
        DetectedAt        = $DetectedAt
        ChangeType        = $ChangeType
        Key               = $Key
        # The leading comma stops the if-expression unrolling a one-item array into a single object.
        ChangedProperties = if ($Changes) { , @($Changes.Property) } else { $null }
        Changes           = if ($Changes) { , @($Changes) } else { $null }
        PreviousItem      = $PreviousItem
        CurrentItem       = $CurrentItem
    }
}
