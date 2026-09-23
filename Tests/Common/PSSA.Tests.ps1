if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

# Fall back to locally-derived values when not running under the BuildHelpers-driven build (which sets
# these as real environment variables so they survive Pester's Discovery/Run split, unlike plain variables).
if (-not $env:BHProjectPath) { $env:BHProjectPath = (Resolve-Path "$PSScriptRoot/../..").ProviderPath }
if (-not $env:BHProjectName) {
    $env:BHProjectName = (Get-ChildItem -Path $env:BHProjectPath -Filter '*.psd1' -Recurse -Depth 1 |
        Where-Object { $_.BaseName -eq $_.Directory.Name }).BaseName
}
if (-not $env:BHModulePath) { $env:BHModulePath = Join-Path $env:BHProjectPath $env:BHProjectName }

# Vars
$ScriptAnalyzerSettingsPath = Join-Path -Path $env:BHProjectPath -ChildPath 'PSScriptAnalyzerSettings.psd1'
$analysis = Invoke-ScriptAnalyzer -Path $env:BHModulePath -Recurse -Settings $ScriptAnalyzerSettingsPath

# Bundle each rule together with its own failures (pre-computed here, at Discovery time) so the -ForEach
# below has everything it needs via $_ alone -- calling Invoke-ScriptAnalyzer itself from inside a BeforeAll
# trips a Pester bug (https://github.com/pester/Pester/issues/2669), so it can't be computed there instead.
$scriptAnalyzerRules = Get-ScriptAnalyzerRule | ForEach-Object {
    [pscustomobject]@{
        Rule     = $_.RuleName
        Failures = @($analysis | Where-Object RuleName -EQ $_.RuleName)
    }
}

Describe 'Testing against PSSA rules' {
    Context 'PSSA Standard Rules' {

        It 'Should pass <_.Rule>' -ForEach $scriptAnalyzerRules {
            $_.Failures.Count | Should -Be 0
        }
    }
}
