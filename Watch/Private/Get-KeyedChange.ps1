function Get-KeyedChange {
    <#
        .SYNOPSIS
            Compares two results by -Key and returns 'Added', 'Removed' and 'Modified' change summaries.

        .DESCRIPTION
            Items are paired up by their key value (compared case-sensitively, see Get-KeyedLookup). A key
            found only in the previous result is 'Removed', one found only in the current result is 'Added',
            and one found in both is 'Modified' if any watched property (other than the key) differs.

            If several items share a key value, they can't be paired reliably, so that group is compared as a
            set instead (like -ChangeSummary without -Key): changed items appear as 'Removed' and 'Added' rather
            than being missed. A warning is written the first time each duplicated key value is seen; pass the
            same -WarnedKey set on every call so it isn't repeated on each check.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $PreviousResult,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $CurrentResult,

        [Parameter(Mandatory)]
        [string[]]
        $Key,

        [string[]]
        $Property,

        [Parameter(Mandatory)]
        [datetime]
        $DetectedAt,

        [System.Collections.Generic.HashSet[string]]
        $WarnedKey = [System.Collections.Generic.HashSet[string]]::new()
    )

    $Previous = Get-KeyedLookup -InputObject $PreviousResult -Key $Key
    $Current = Get-KeyedLookup -InputObject $CurrentResult -Key $Key

    # Previous keys in order, then keys that are new in this result.
    $AllKeys = [System.Collections.Generic.List[string]]::new($Previous.Keys)
    foreach ($KeyValue in $Current.Keys) {
        if (-not $Previous.Groups.ContainsKey($KeyValue)) {
            $AllKeys.Add($KeyValue)
        }
    }

    foreach ($KeyValue in $AllKeys) {
        # @() keeps these as arrays: an if-expression unrolls the list, and on Windows PowerShell 5.1 a single
        # [pscustomobject] has no .Count, so a one-item group would otherwise look empty.
        $PreviousItems = @(if ($Previous.Groups.ContainsKey($KeyValue)) { $Previous.Groups[$KeyValue] })
        $CurrentItems = @(if ($Current.Groups.ContainsKey($KeyValue)) { $Current.Groups[$KeyValue] })

        $KeySource = if ($CurrentItems.Count) { $CurrentItems[0] } else { $PreviousItems[0] }

        $KeyOutput = if ($Key.Count -eq 1) {
            $KeySource.($Key[0])
        }
        else {
            $KeyProperties = [ordered]@{}
            foreach ($KeyName in $Key) {
                $KeyProperties[$KeyName] = $KeySource.$KeyName
            }
            [PSCustomObject]$KeyProperties
        }

        $CompareProperties = if ($Property) { $Property } else { Get-DefaultWatchProperty -InputObject $KeySource }

        if ($PreviousItems.Count -gt 1 -or $CurrentItems.Count -gt 1) {
            if ($WarnedKey.Add($KeyValue)) {
                Write-Warning ("Several items share the -Key value '{0}', so changes to them can't be paired up and are reported as 'Removed' and 'Added' instead of 'Modified'. Use -Key with a property (or properties) that is unique to each item." -f ($KeyValue -replace "`0", ', '))
            }

            if (-not $PreviousItems.Count) {
                foreach ($Item in $CurrentItems) {
                    New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Added' -Key $KeyOutput -CurrentItem $Item
                }
            }
            elseif (-not $CurrentItems.Count) {
                foreach ($Item in $PreviousItems) {
                    New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Removed' -Key $KeyOutput -PreviousItem $Item
                }
            }
            else {
                $GroupDiff = @(Compare-Object -ReferenceObject @($PreviousItems) -DifferenceObject @($CurrentItems) -Property $CompareProperties -PassThru)
                $GroupChanges = @(Get-UnkeyedChange -Difference $GroupDiff -DetectedAt $DetectedAt -Key $KeyOutput)

                # Compare-Object -PassThru added SideIndicator to these items, which are still part of the results. Remove it so it isn't reported with them on a later check.
                foreach ($Item in $GroupDiff) {
                    $Item.PSObject.Properties.Remove('SideIndicator')
                }

                $GroupChanges
            }
        }
        elseif (-not $PreviousItems.Count) {
            New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Added' -Key $KeyOutput -CurrentItem $CurrentItems[0]
        }
        elseif (-not $CurrentItems.Count) {
            New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Removed' -Key $KeyOutput -PreviousItem $PreviousItems[0]
        }
        else {
            $Changes = @(Get-PropertyChange -PreviousItem $PreviousItems[0] -CurrentItem $CurrentItems[0] -Property $CompareProperties -ExcludeProperty $Key)

            if ($Changes.Count) {
                New-ChangeSummary -DetectedAt $DetectedAt -ChangeType 'Modified' -Key $KeyOutput -Changes $Changes -PreviousItem $PreviousItems[0] -CurrentItem $CurrentItems[0]
            }
        }
    }
}
