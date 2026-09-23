if (-not (Test-Path alias:Watch)) {
    New-Alias -Name 'Watch' -Value 'Watch-Command'
    Export-ModuleMember -Alias 'Watch'
}

if (-not (Test-Path alias:wc)) {
    New-Alias -Name 'wc' -Value 'Watch-Command'
    Export-ModuleMember -Alias 'wc'
}
