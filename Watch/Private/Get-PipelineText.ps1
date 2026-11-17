function Get-PipelineText {
    <#
        .SYNOPSIS
            Returns the source text of the commands that were piped into the invoked command, or nothing if
            they can't be determined.

        .DESCRIPTION
            Parses the source of the invocation and takes only the pipeline elements that precede the command,
            so anything else on the line (an assignment such as '$r = ', earlier ';'-separated statements, or
            commands after it in the pipeline) is excluded. When invoked from a script file, the whole file is
            parsed so a pipeline split across several lines is recovered in full. Works on Windows PowerShell
            5.1 and PowerShell 7.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.InvocationInfo]
        $Invocation
    )

    $Parser = [System.Management.Automation.Language.Parser]
    $Sources = @()

    # From a script file: parse the whole file, so pipelines that span several lines are seen in full. Only
    # trusted if the file's line still matches the invocation (e.g. the code wasn't built with
    # [scriptblock]::Create inside that file, and the file hasn't changed since it was run).
    if ($Invocation.ScriptName -and (Test-Path -LiteralPath $Invocation.ScriptName -PathType Leaf)) {
        $FileAst = $Parser::ParseFile($Invocation.ScriptName, [ref]$null, [ref]$null)
        $FileLines = $FileAst.Extent.Text -split '\r?\n'
        $LineIndex = $Invocation.ScriptLineNumber - 1

        if ($LineIndex -ge 0 -and $LineIndex -lt $FileLines.Count -and
            $FileLines[$LineIndex].TrimEnd() -eq "$($Invocation.Line)".TrimEnd()) {
            $Sources += , @($FileAst, $Invocation.ScriptLineNumber)
        }
    }

    # Interactive or -Command input (or as a fallback): parse just the line the command is on.
    if ($Invocation.Line) {
        $Sources += , @($Parser::ParseInput($Invocation.Line, [ref]$null, [ref]$null), 1)
    }

    foreach ($Source in $Sources) {
        $Text = Get-UpstreamPipelineText -Ast $Source[0] -LineNumber $Source[1] -ColumnNumber $Invocation.OffsetInLine

        if ($Text) {
            return $Text
        }
    }

    # PowerShell 7.4+ exposes the full text of the statement, which covers multi-line pipelines typed
    # interactively. Its position relative to the line isn't known, so only use it if exactly one pipeline
    # in it ends in a command of this name.
    $Statement = if ($Invocation.PSObject.Properties['Statement']) { $Invocation.Statement }

    if ($Statement) {
        $StatementAst = $Parser::ParseInput($Statement, [ref]$null, [ref]$null)
        $Matched = @($StatementAst.FindAll({
                    param($Node)
                    $Node -is [System.Management.Automation.Language.CommandAst] -and
                    $Node.GetCommandName() -eq $Invocation.InvocationName -and
                    $Node.Parent -is [System.Management.Automation.Language.PipelineAst] -and
                    $Node.Parent.PipelineElements.IndexOf($Node) -gt 0
                }, $true))

        if ($Matched.Count -eq 1) {
            $Text = Get-UpstreamPipelineText -Ast $StatementAst -LineNumber $Matched[0].Extent.StartLineNumber -ColumnNumber $Matched[0].Extent.StartColumnNumber

            if ($Text) {
                return $Text
            }
        }
    }
}
