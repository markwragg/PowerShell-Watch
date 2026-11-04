# Import new module
Task 'ImportStagingModule' -Depends 'Init' {
    $lines
    Write-Output "Reloading staged module from path: [$StagingModulePath]`n"

    # Reload module
    if (Get-Module -Name $env:BHProjectName) {
        Remove-Module -Name $env:BHProjectName
    }
    # Global scope used for UpdateDocumentation / UpdateWiki (PlatyPS)
    Import-Module -Name $StagingModulePath -ErrorAction 'Stop' -Force -Global
}
