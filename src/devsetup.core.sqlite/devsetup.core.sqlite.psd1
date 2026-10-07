@{
    RootModule = 'devsetup.core.sqlite.psm1'
    ModuleVersion = '1.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = '94cc58ab-63cf-43d0-9978-bb124a56691b'
    Author = 'PwshDevs'
    CompanyName = 'PwshDevs'
    Copyright = '(c) 2026 PwshDevs. All rights reserved.'
    Description = 'A cross-platform PowerShell module for querying SQLite databases and efficiently importing data on Windows, Linux, and macOS.'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    RequiredModules = @()
    FunctionsToExport = @(
        'Add-SqliteRow'
        'ConvertTo-SqliteDataTable'
        'Get-SqliteRow'
        'Invoke-SqliteBulkCopy'
        'Invoke-SqliteQuery'
        'New-SqliteConnection'
        'New-SqliteDatabase'
        'Remove-SqliteRow'
        'Set-SqliteRow'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'SQLite', 'SQL', 'Database', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'MacOS')
            LicenseUri = 'https://github.com/pwshdevs/devsetup.core.sqlite/blob/main/LICENSE'
            ProjectUri = 'https://github.com/pwshdevs/devsetup.core.sqlite'
            ReleaseNotes = 'See https://github.com/pwshdevs/devsetup.core.sqlite/blob/main/CHANGELOG.md'
        }
    }
}
