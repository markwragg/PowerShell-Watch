# Update the coverage badge in README.md using a coverage percentage computed by an earlier Test task
Task 'UpdateCoverageBadge' -Depends 'Init' {
    $lines

    if (-not $env:CoveragePercent) {
        throw "CoveragePercent environment variable not set. Run the 'Test' task first and pass its coverage output through."
    }

    Set-ShieldsIoBadge -Path (Join-Path $ProjectRoot 'README.md') -Subject 'coverage' -Status $env:CoveragePercent -AsPercentage
}
