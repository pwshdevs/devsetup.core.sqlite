BeforeDiscovery {
    $projectRoot = if ($env:BHProjectPath) {
        $env:BHProjectPath
    } else {
        Split-Path $PSScriptRoot -Parent
    }
    $exampleRoot = Join-Path $projectRoot 'examples/New-SqliteDatabase'
    $exampleCases = @(
        Get-ChildItem -LiteralPath $exampleRoot -Filter '*.ps1' -File -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.FullName.Substring($exampleRoot.Length).TrimStart([char[]]@('\', '/'))
                    Path = $_.FullName
                }
            }
    )
}

Describe 'Runnable New-SqliteDatabase examples' {
BeforeAll {
    $projectRoot = if ($env:BHProjectPath) {
        $env:BHProjectPath
    } else {
        Split-Path $PSScriptRoot -Parent
    }
    $sourceManifest = Join-Path $projectRoot 'src/devsetup.core.sqlite/devsetup.core.sqlite.psd1'
    $manifest = Import-PowerShellDataFile -LiteralPath $sourceManifest
    $outputManifest = Join-Path $projectRoot "Output/devsetup.core.sqlite/$($manifest.ModuleVersion)/devsetup.core.sqlite.psd1"
    $moduleManifest = if ($env:BHProjectPath -and (Test-Path -LiteralPath $outputManifest -PathType Leaf)) {
        $outputManifest
    } else {
        $sourceManifest
    }

    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
    Import-Module $moduleManifest -Force -ErrorAction Stop
}

AfterAll {
    [System.Data.SQLite.SQLiteConnection]::ClearAllPools()
    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
}

It 'discovers all twelve documented examples' {
    @(Get-ChildItem (Join-Path $projectRoot 'examples/New-SqliteDatabase') -Filter '*.ps1' -File -Recurse) |
        Should -HaveCount 12
}

It '<_.Name> executes and creates an integral SQLite database' -ForEach $exampleCases {
    $scriptPath = $_.Path
    $databasePath = Join-Path $TestDrive (([System.IO.Path]::GetFileNameWithoutExtension($scriptPath)) + '-' + [guid]::NewGuid() + '.sqlite')

    { & $scriptPath -DatabasePath $databasePath } | Should -Not -Throw

    Test-Path -LiteralPath $databasePath -PathType Leaf | Should -BeTrue
    Invoke-SqliteQuery -DataSource $databasePath -Query 'PRAGMA integrity_check' -As SingleValue |
        Should -Be 'ok'
}
}
