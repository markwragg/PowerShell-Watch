function Get-PipelineScriptBlock {
    <#
        .SYNOPSIS
            Turns the source text of the commands that were piped into a command (from Get-PipelineText) into a
            ScriptBlock that re-runs them, for the pipeline shorthand (e.g. Get-ChildItem | Watch-Command).

        .DESCRIPTION
            If -SessionState is given (the caller's, i.e. $PSCmdlet.SessionState), the returned ScriptBlock runs
            the piped commands in that session state, so they can see the caller's local variables (such as
            those of a function that uses the shorthand). Otherwise they would run in this module's scope.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [string]
        $Text,

        [System.Management.Automation.SessionState]
        $SessionState
    )

    $Inner = [scriptblock]::Create($Text)

    if (-not $SessionState) {
        return $Inner
    }

    { $SessionState.InvokeCommand.InvokeScript($SessionState, $Inner, @()) }.GetNewClosure()
}
