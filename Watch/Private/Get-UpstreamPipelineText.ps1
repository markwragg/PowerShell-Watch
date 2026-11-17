function Get-UpstreamPipelineText {
    <#
        .SYNOPSIS
            Returns the source text of the pipeline elements that precede the command starting at the given
            line and column of a parsed script, or nothing if there is no such command or nothing precedes it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast]
        $Ast,

        [Parameter(Mandatory)]
        [int]
        $LineNumber,

        [Parameter(Mandatory)]
        [int]
        $ColumnNumber
    )

    # Copied to locals because PSScriptAnalyzer doesn't count uses inside the predicate ScriptBlock.
    $TargetLine = $LineNumber
    $TargetColumn = $ColumnNumber

    $Command = $Ast.Find({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.Extent.StartLineNumber -eq $TargetLine -and
            $Node.Extent.StartColumnNumber -eq $TargetColumn
        }, $true)

    if (-not $Command -or $Command.Parent -isnot [System.Management.Automation.Language.PipelineAst]) {
        return
    }

    $Elements = $Command.Parent.PipelineElements
    $Index = $Elements.IndexOf($Command)

    if ($Index -lt 1) {
        return
    }

    ($Elements[0..($Index - 1)] | ForEach-Object { $_.Extent.Text }) -join ' | '
}
