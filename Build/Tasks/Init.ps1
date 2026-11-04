# Show build variables
Task 'Init' {
    $lines

    Set-Location $ProjectRoot

    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}
