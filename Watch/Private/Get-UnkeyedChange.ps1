function Get-UnkeyedChange {
    <#
        .SYNOPSIS
            Turns Compare-Object -PassThru output into 'Added'/'Removed' change summaries, for -ChangeSummary
            without -Key.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $Difference,

        [Parameter(Mandatory)]
        [datetime]
        $DetectedAt,

        [object]
        $Key
    )

    foreach ($DiffItem in $Difference) {
        # Read SideIndicator before removing it: for .NET objects (e.g. FileInfo), PSObject.Copy() shares note
        # properties with the original, so removing it from the copy removes it from $DiffItem too, which
        # would turn every 'Added' item into 'Removed'.
        $SideIndicator = $DiffItem.SideIndicator

        $Clean = $DiffItem.PSObject.Copy()
        $Clean.PSObject.Properties.Remove('SideIndicator')

        if ($SideIndicator -eq '=>') {
            New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Added' -Key $Key -CurrentItem $Clean
        }
        else {
            New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Removed' -Key $Key -PreviousItem $Clean
        }
    }
}
