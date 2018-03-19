$Public  = @( Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse )
$Private = @( Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse )

@($Public + $Private) | ForEach-Object {
    try
    {
        . $_.FullName
    }
    catch
    {
        Write-Error -Message "Failed to import function $($_.FullName): $_"
    }
}

if (-not (Test-Path alias:Watch)) 
{
    New-Alias -Name 'Watch' -Value 'Watch-Command'
    Export-ModuleMember -Function $Public.BaseName -Alias 'Watch'
}

if (-not (Test-Path alias:wc)) 
{
    New-Alias -Name 'wc' -Value 'Watch-Command'
    Export-ModuleMember -Function $Public.BaseName -Alias 'wc'
}

