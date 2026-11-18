function Get-PipelineText {
    <#
        .SYNOPSIS
            Returns the source text of the commands that were piped into the invoked command, or nothing if
            they can't be determined.

        .DESCRIPTION
            Parses the source of the invocation and takes only the pipeline elements that precede the command,
            so anything else on the line (an assignment such as '$r = ', earlier ';'-separated statements, or
            commands after it in the pipeline) is excluded. When invoked from a script file, the whole file is
            parsed so a pipeline split across several lines is recovered in full. Otherwise, a multi-line
            pipeline is recovered from -CallerExtent: the Position of the caller's call stack frame
            ((Get-PSCallStack)[1].Position from within the invoked command), whose script position gives the
            full source that was run.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.InvocationInfo]
        $Invocation,

        [System.Management.Automation.Language.IScriptExtent]
        $CallerExtent
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

    # A pipeline split over several lines that wasn't run from a script file (e.g. typed interactively):
    # .Line holds only the last line, so parse the full source the caller ran instead. The invocation's line
    # and column are relative to that source, so they locate the command exactly.
    # (InvocationInfo.Statement in PowerShell 7.4+ can't be used for this: it holds only the command itself.)
    $FullScript = if ($CallerExtent) { $CallerExtent.StartScriptPosition.GetFullScript() }

    if ($FullScript) {
        $FullAst = $Parser::ParseInput($FullScript, [ref]$null, [ref]$null)
        Get-UpstreamPipelineText -Ast $FullAst -LineNumber $Invocation.ScriptLineNumber -ColumnNumber $Invocation.OffsetInLine
    }
}
