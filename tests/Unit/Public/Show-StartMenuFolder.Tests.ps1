BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Show-StartMenuFolder' -Tag 'Unit' {
    It 'Should expose separate Entry ID and Entry Root name parameter sets' {
        $command = Get-Command -Name Show-StartMenuFolder -Module $moduleName
        $parameterSets = $command.ParameterSets | Select-Object -ExpandProperty Name

        $parameterSets | Should -Contain 'ByEntryId'
        $parameterSets | Should -Contain 'ByEntryName'
        ($command.ParameterSets | Where-Object Name -eq 'ByEntryId').Parameters.Name |
            Should -Contain 'EntryId'
        ($command.ParameterSets | Where-Object Name -eq 'ByEntryName').Parameters.Name |
            Should -Contain 'EntryName'
    }

    It 'Should reject a non-STA host before reading content' -Skip:(
        [Threading.Thread]::CurrentThread.GetApartmentState() -eq
            [Threading.ApartmentState]::STA
    ) {
        { Show-StartMenuFolder -EntryName 'Example' } |
            Should -Throw -ExpectedMessage '*STA*'
    }
}