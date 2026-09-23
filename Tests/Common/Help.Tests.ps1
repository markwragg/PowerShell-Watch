if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

# Fall back to locally-derived values when not running under the BuildHelpers-driven build (which sets
# these as real environment variables so they survive Pester's Discovery/Run split, unlike plain variables).
if (-not $env:BHProjectPath) { $env:BHProjectPath = (Resolve-Path "$PSScriptRoot/../..").ProviderPath }
if (-not $env:BHProjectName) {
    $env:BHProjectName = (Get-ChildItem -Path $env:BHProjectPath -Filter '*.psd1' -Recurse -Depth 1 |
        Where-Object { $_.BaseName -eq $_.Directory.Name }).BaseName
}
if (-not $env:BHModulePath) { $env:BHModulePath = Join-Path $env:BHProjectPath $env:BHProjectName }
if (-not $env:BHPSModuleManifest) { $env:BHPSModuleManifest = Join-Path $env:BHModulePath "$env:BHProjectName.psd1" }

# Import module
if (-not (Get-Module -Name $env:BHProjectName -ListAvailable)) {
    Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
}
$commands = Get-Command -Module $env:BHProjectName -CommandType Cmdlet, Function -ErrorAction 'Stop' # Not alias

## When testing help, remember that help is cached at the beginning of each session.
## To test, restart session.

# $_ is the current command for the whole -ForEach iteration below, in both Discovery and Run. $help is
# recomputed both as plain (Discovery-time) code -- so nested -ForEach blocks below can enumerate over it --
# and again inside BeforeAll (Run-time) so It blocks can assert against it.
Describe "Test help for <_.Name>" -ForEach $commands {

    BeforeAll {
        $commandName = $_.Name
        $help = Get-Help $commandName -ErrorAction SilentlyContinue
    }

    # If help is not found, synopsis in auto-generated help is the syntax diagram
    It 'Should not be auto-generated' {
        $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'Gets description' {
        $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example
    It 'Gets example code' {
        ($help.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example description
    It 'Gets example help' {
        ($help.Examples.Example.Remarks | Select-Object -First 1).Text | Should -Not -BeNullOrEmpty
    }

    Context 'Test parameter help' {

        $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer',
        'OutVariable', 'PipelineVariable', 'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

        $parameters = $_.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object { $_.Name -notin $common }

        BeforeAll {
            $help = Get-Help $commandName -ErrorAction SilentlyContinue
        }

        # Should be a description for every parameter
        It 'Gets help for parameter: <_.Name>' -ForEach $parameters {
            $parameterHelp = $help.parameters.parameter | Where-Object Name -EQ $_.Name
            $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
        }

        # Required value in Help should match IsMandatory property of parameter
        It 'Help for <_.Name> parameter has correct Mandatory value' -ForEach $parameters {
            $codeMandatory = $_.IsMandatory.ToString()
            $parameterHelp = $help.parameters.parameter | Where-Object Name -EQ $_.Name
            $parameterHelp.Required | Should -Be $codeMandatory
        }

        # Parameter type in Help should match code
        # It "help for $commandName has correct parameter type for $parameterName" {
        #     $codeType = $parameter.ParameterType.Name
        #     # To avoid calling Trim method on a null object.
        #     $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        #     $helpType | Should -Be $codeType
        # }
    }

    Context 'Help parameters exist in code' {

        $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer',
        'OutVariable', 'PipelineVariable', 'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

        $help = Get-Help $_.Name -ErrorAction SilentlyContinue

        ## Without the filter, WhatIf and Confirm parameters are still flagged in "finds help parameter in code" test
        $helpParameterNames = ($help.Parameters.Parameter |
            Where-Object { $_.Name -notin $common } |
            Sort-Object -Property Name -Unique).Name

        BeforeAll {
            $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer',
            'OutVariable', 'PipelineVariable', 'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

            $parameterNames = ($_.ParameterSets.Parameters | Where-Object { $_.Name -notin $common }).Name
        }

        # Shouldn't find extra parameters in help.
        It 'Finds help parameter in code: <_>' -ForEach $helpParameterNames {
            $_ -in $parameterNames | Should -Be $true
        }
    }

    Context 'Help Links should be Valid' {

        $links = (Get-Help $_.Name -ErrorAction SilentlyContinue).relatedLinks.navigationLink.uri | Where-Object { $_ }

        # Should have a valid uri if one is provided.
        It '<_> should have 200 Status Code' -ForEach $links -AllowNullOrEmptyForEach {
            $Results = Invoke-WebRequest -Uri $_ -UseBasicParsing
            $Results.StatusCode | Should -Be '200'
        }
    }
}
