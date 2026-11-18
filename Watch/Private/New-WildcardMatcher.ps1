function New-WildcardMatcher {
    <#
        .SYNOPSIS
            Returns a case-insensitive [WildcardPattern] for each pattern, throwing straight away if one is
            invalid.

        .DESCRIPTION
            [WildcardPattern] only parses a pattern when it is first used, so each one is used once here. That
            way an invalid pattern fails when Watch-Command starts, rather than on the first check.
            -ParameterName is the parameter the patterns came from, for the error message.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only creates in-memory objects.')]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.WildcardPattern])]
    param(
        [Parameter(Mandatory)]
        [string[]]
        $Pattern,

        [Parameter(Mandatory)]
        [string]
        $ParameterName
    )

    foreach ($Item in $Pattern) {
        $Wildcard = [System.Management.Automation.WildcardPattern]::new($Item, 'IgnoreCase')

        try {
            $null = $Wildcard.IsMatch('')
        }
        catch {
            Throw "$ParameterName contains an invalid wildcard pattern '$Item': $($_.Exception.InnerException.Message)"
        }

        $Wildcard
    }
}
