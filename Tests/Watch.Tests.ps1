$PSVersion = $PSVersionTable.PSVersion.Major
$Module = 'Watch'

Describe "Watch Module Tests PS$PSVersion" {

    BeforeAll {
        $Module = 'Watch'
        $Root = "$PSScriptRoot/.."

        Get-Module $Module | Remove-Module -Force
    }

    It "Should import $Module without errors" {
        { Import-Module (Join-Path $Root $Module) -Force -ErrorAction Stop } | Should -Not -Throw
    }
}
