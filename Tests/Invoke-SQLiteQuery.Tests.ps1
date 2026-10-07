BeforeAll {
    $script:PSVersion = $PSVersionTable.PSVersion.Major
    $script:VerboseParameters = @{}

    $sourceManifest = if ($env:BHPSModuleManifest) {
        $env:BHPSModuleManifest
    } else {
        Join-Path $PSScriptRoot '../src/devsetup.core.sqlite/devsetup.core.sqlite.psd1'
    }

    $manifestData = Import-PowerShellDataFile -Path $sourceManifest
    $script:ExpectedModuleVersion = [string]$manifestData.ModuleVersion
    $projectRoot = if ($env:BHProjectPath) {
        $env:BHProjectPath
    } else {
        Split-Path $PSScriptRoot -Parent
    }
    $script:SQLiteDependencies = Import-PowerShellDataFile `
        -LiteralPath (Join-Path $projectRoot 'tools/SQLiteDependencies.psd1')
    $providerPackageVersion = [version]$script:SQLiteDependencies.ProviderVersion
    $providerBuild = if ($providerPackageVersion.Build -lt 0) { 0 } else { $providerPackageVersion.Build }
    $providerRevision = if ($providerPackageVersion.Revision -lt 0) { 0 } else { $providerPackageVersion.Revision }
    $script:ExpectedProviderAssemblyVersion = '{0}.{1}.{2}.{3}' -f `
        $providerPackageVersion.Major,
        $providerPackageVersion.Minor,
        $providerBuild,
        $providerRevision
    $outputManifest = Join-Path $projectRoot "Output/devsetup.core.sqlite/$($manifestData.ModuleVersion)/devsetup.core.sqlite.psd1"
    $moduleManifest = if (Test-Path -LiteralPath $outputManifest -PathType Leaf) {
        $outputManifest
    } else {
        $sourceManifest
    }

    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
    Import-Module $moduleManifest -Force -ErrorAction Stop

    $script:SQLiteFile = Join-Path $TestDrive 'Working.SQLite'
    Copy-Item (Join-Path $PSScriptRoot 'Names.SQLite') $script:SQLiteFile -Force

    $script:NewTestDataTable = {
        1..1000 | ForEach-Object {
            [pscustomobject]@{
                fullname  = "Name $_"
                surname   = 'Name'
                givenname = "$_"
                BirthDate = (Get-Date).AddDays(-$_)
            }
        } | ConvertTo-SqliteDataTable
    }
}

AfterAll {
    [System.Data.SQLite.SQLiteConnection]::ClearAllPools()
    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
}

Describe "New-SQLiteConnection PS$script:PSVersion" {
    Context 'Strict mode' {
        BeforeAll {
            Set-StrictMode -Version Latest
        }

        It 'creates an open connection with sane date/time defaults' {
            $connection = New-SQLiteConnection @script:VerboseParameters -DataSource :MEMORY:
            try {
                $connection.ConnectionString | Should -Be 'Data Source=:MEMORY:;DateTimeFormat=InvariantCulture;DateTimeKind=Utc'
                $connection.State | Should -Be 'Open'
            } finally {
                $connection.Dispose()
            }
        }

        It 'exposes configurable date/time parsing options' {
            $connection = New-SQLiteConnection -DataSource :MEMORY: `
                -DateTimeFormat ISO8601 `
                -DateTimeKind Local `
                -DateTimeFormatString 'yyyyMMdd-HHmmss' `
                -Open $false

            try {
                $builder = New-Object System.Data.SQLite.SQLiteConnectionStringBuilder($connection.ConnectionString)
                $builder.DateTimeFormat | Should -Be ([System.Data.SQLite.SQLiteDateFormats]::ISO8601)
                $builder.DateTimeKind | Should -Be ([System.DateTimeKind]::Local)
                $builder.DateTimeFormatString | Should -Be 'yyyyMMdd-HHmmss'
                $connection.State | Should -Be 'Closed'
            } finally {
                $connection.Dispose()
            }
        }

        It 'loads the expected provider and SQLite engine' {
            [System.Data.SQLite.SQLiteConnection].Assembly.GetName().Version.ToString() |
                Should -Be $script:ExpectedProviderAssemblyVersion

            $connection = New-SQLiteConnection -DataSource :MEMORY:
            $command = $connection.CreateCommand()
            try {
                $command.CommandText = 'SELECT sqlite_version()'
                $command.ExecuteScalar() | Should -Be $script:SQLiteDependencies.SQLiteVersion
            } finally {
                $command.Dispose()
                $connection.Dispose()
            }
        }
    }
}

Describe "devsetup.core.sqlite runtime assets PS$script:PSVersion" {
    Context 'Supported runtimes' {
        It 'loads under the devsetup.core.sqlite identity' {
            $module = Get-Module devsetup.core.sqlite
            $module.Name | Should -Be 'devsetup.core.sqlite'
            $module.Version.ToString() | Should -Be $script:ExpectedModuleVersion
            $module.Guid.ToString() | Should -Be '94cc58ab-63cf-43d0-9978-bb124a56691b'
            @(Get-Module PSSQLite).Count | Should -Be 0
            (Get-Command ConvertTo-SqliteDataTable -Module devsetup.core.sqlite).Name | Should -Be 'ConvertTo-SqliteDataTable'
            @(Get-Command Out-DataTable -Module devsetup.core.sqlite -ErrorAction SilentlyContinue).Count | Should -Be 0
            @(Get-Command Update-Sqlite -Module devsetup.core.sqlite -ErrorAction SilentlyContinue).Count | Should -Be 0
        }

        It 'loads the precompiled portable support assembly' {
            $module = Get-Module devsetup.core.sqlite
            $supportAssemblyPath = Join-Path $module.ModuleBase 'lib/devsetup.core.sqlite.Support.dll'

            Test-Path -LiteralPath $supportAssemblyPath -PathType Leaf | Should -Be $true
            [System.Reflection.AssemblyName]::GetAssemblyName($supportAssemblyPath).Name |
                Should -Be 'devsetup.core.sqlite.Support'
            ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]).Assembly.GetName().Name |
                Should -Be 'devsetup.core.sqlite.Support'
        }

        It 'bundles every supported PowerShell Core runtime' {
            $module = Get-Module devsetup.core.sqlite
            $runtimeFiles = @{
                'linux-arm'   = 'libe_sqlite3.so'
                'linux-arm64' = 'libe_sqlite3.so'
                'linux-x64'   = 'libe_sqlite3.so'
                'osx-arm64'   = 'libe_sqlite3.dylib'
                'osx-x64'     = 'libe_sqlite3.dylib'
                'win-arm64'   = 'e_sqlite3.dll'
                'win-x64'     = 'e_sqlite3.dll'
                'win-x86'     = 'e_sqlite3.dll'
            }

            foreach ($runtimeIdentifier in $runtimeFiles.Keys) {
                $runtimePath = Join-Path $module.ModuleBase "core/$runtimeIdentifier"
                Test-Path -LiteralPath (Join-Path $runtimePath 'System.Data.SQLite.dll') -PathType Leaf | Should -Be $true
                Test-Path -LiteralPath (Join-Path $runtimePath $runtimeFiles[$runtimeIdentifier]) -PathType Leaf | Should -Be $true
                [System.Reflection.AssemblyName]::GetAssemblyName((Join-Path $runtimePath 'System.Data.SQLite.dll')).Version.ToString() |
                    Should -Be $script:ExpectedProviderAssemblyVersion
            }
        }

        It 'resolves supported ARM runtime identifiers' {
            $module = Get-Module devsetup.core.sqlite
            $runtimeCases = @(
                @{ Platform = 'linux'; Architecture = 'Arm'; Expected = 'linux-arm' }
                @{ Platform = 'linux'; Architecture = 'Arm64'; Expected = 'linux-arm64' }
                @{ Platform = 'osx'; Architecture = 'Arm64'; Expected = 'osx-arm64' }
                @{ Platform = 'win'; Architecture = 'Arm64'; Expected = 'win-arm64' }
            )

            foreach ($runtimeCase in $runtimeCases) {
                & $module {
                    Get-DevSetupSQLiteRuntimeIdentifier -Platform $args[0] -Architecture $args[1]
                } $runtimeCase.Platform $runtimeCase.Architecture | Should -Be $runtimeCase.Expected
            }
        }

        It 'rejects runtime identifiers without bundled native assets' {
            $module = Get-Module devsetup.core.sqlite
            { & $module { Get-DevSetupSQLiteRuntimeIdentifier -Platform osx -Architecture Arm } } |
                Should -Throw
        }
    }
}

Describe "Invoke-SQLiteQuery PS$script:PSVersion" {
    Context 'Strict mode' {
        BeforeAll {
            Set-StrictMode -Version Latest
        }

        It 'accepts file input' {
            $output = @(Invoke-SqliteQuery @script:VerboseParameters -DataSource $script:SQLiteFile -InputFile (Join-Path $PSScriptRoot 'Test.SQL'))
            $output.Count | Should -Be 2
            $output[1].OrderID | Should -Be 500
        }

        It 'accepts query input' {
            $output = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query 'PRAGMA table_info(NAMES)' -ErrorAction Stop)
            $output.Count | Should -Be 4
            $output[0].Name | Should -Be 'fullname'
        }

        It 'reuses the precompiled DBNull scrubber without compiling per query' {
            ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]).FullName |
                Should -Be 'DevSetup.Core.SQLite.DBNullScrubber'

            Mock -CommandName Add-Type -ModuleName devsetup.core.sqlite -MockWith {}

            $connection = New-SQLiteConnection -DataSource :MEMORY:
            try {
                $first = Invoke-SQLiteQuery -SQLiteConnection $connection -Query 'SELECT NULL AS NullableValue' -ErrorAction Stop
                $second = Invoke-SQLiteQuery -SQLiteConnection $connection -Query 'SELECT 1 AS Value' -ErrorAction Stop

                @($first).Count | Should -Be 1
                $first.NullableValue | Should -BeNullOrEmpty
                $second.Value | Should -Be 1
                Should -Invoke -CommandName Add-Type -ModuleName devsetup.core.sqlite -Times 0 -Exactly
            } finally {
                $connection.Dispose()
            }
        }

        It 'parses offset timestamps using invariant UTC defaults' {
            $dateTimeSQLiteFile = Join-Path $TestDrive 'DateTime.Working.SQLite'

            Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile -Query 'CREATE TABLE Events (OccurredAt DATETIME)' -ErrorAction Stop
            Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile -Query @'
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02 04:59:18.578 +00:00');
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02T05:59:18.578Z');
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02 04:59:18.578 -05:00');
'@ -ErrorAction Stop

            $output = @(Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile -Query 'SELECT OccurredAt FROM Events ORDER BY rowid' -ErrorAction Stop)

            $output.Count | Should -Be 3
            $output[0].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should -Be '2019-07-02T04:59:18.578'
            $output[1].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should -Be '2019-07-02T05:59:18.578'
            $output[2].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should -Be '2019-07-02T09:59:18.578'

            Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile -Query 'CREATE TABLE CustomEvents (OccurredAt DATETIME)' -ErrorAction Stop
            Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile -Query "INSERT INTO CustomEvents VALUES ('20190702-045918')" -ErrorAction Stop

            $customOutput = Invoke-SQLiteQuery -DataSource $dateTimeSQLiteFile `
                -Query 'SELECT OccurredAt FROM CustomEvents' `
                -DateTimeFormatString 'yyyyMMdd-HHmmss' `
                -ErrorAction Stop

            $customOutput.OccurredAt.ToString('yyyyMMdd-HHmmss') | Should -Be '20190702-045918'
        }

        It 'supports parameterized queries' {
            $output = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query 'SELECT * FROM NAMES WHERE BirthDate >= @Date' -SqlParameters @{
                Date = Get-Date '2012-03-13'
            } -ErrorAction Stop)
            $output.Count | Should -Be 1
            $output[0].fullname | Should -Be 'Cookie Monster'

            $output = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query 'SELECT * FROM NAMES WHERE BirthDate >= @Date' -SqlParameters @{
                Date = Get-Date '2012-03-15'
            } -ErrorAction Stop)
            $output.Count | Should -Be 0
        }

        It 'uses existing SQLite connections without closing them' {
            $connection = New-SQLiteConnection -DataSource :MEMORY:
            try {
                Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query 'CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);'
                Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
                @(Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query "SELECT name AS [table] FROM sqlite_master WHERE type = 'table' AND name = 'OrdersToNames'") |
                    Select-Object -First 1 -ExpandProperty table |
                    Should -Be 'OrdersToNames'

                $connection.State | Should -Be Open
            } finally {
                $connection.Dispose()
            }
        }

        It 'uses PowerShell null semantics for PSObject output' {
            $connection = New-SQLiteConnection -DataSource :MEMORY:
            try {
                Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query 'CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);'
                Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
                Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query 'INSERT INTO OrdersToNames (OrderID) VALUES (2);'

                @(Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query 'SELECT * FROM OrdersToNames' -As DataRow | Where-Object fullname).Count |
                    Should -Be 2
                @(Invoke-SqliteQuery @script:VerboseParameters -SQLiteConnection $connection -Query 'SELECT * FROM OrdersToNames' | Where-Object fullname).Count |
                    Should -Be 1
            } finally {
                $connection.Dispose()
            }
        }
    }
}

Describe "ConvertTo-SqliteDataTable PS$script:PSVersion" {
    It 'creates a typed DataTable' {
        $dataTable = & $script:NewTestDataTable

        $dataTable.GetType().FullName | Should -Be 'System.Data.DataTable'
        @($dataTable.Rows).Count | Should -Be 1000
        $columns = $dataTable.Columns | Select-Object -ExpandProperty ColumnName
        $columns[0] | Should -Be 'fullname'
        $columns[3] | Should -Be 'BirthDate'
        $dataTable.Columns[3].DataType.FullName | Should -Be 'System.DateTime'
    }
}

Describe "Invoke-SQLiteBulkCopy PS$script:PSVersion" {
    BeforeAll {
        $script:BulkDataTable = & $script:NewTestDataTable
        Invoke-SQLiteBulkCopy @script:VerboseParameters -DataTable $script:BulkDataTable -DataSource $script:SQLiteFile -Table Names -NotifyAfter 100 -Force
    }

    It 'inserts data' {
        @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query "SELECT fullname FROM NAMES WHERE surname = 'Name'").Count |
            Should -Be 1000
    }

    It 'honors conflict clauses' {
        { Invoke-SQLiteBulkCopy @script:VerboseParameters -DataTable $script:BulkDataTable -DataSource $script:SQLiteFile -Table Names -NotifyAfter 100 -Force } |
            Should -Throw

        $script:BulkDataTable.Rows[0].surname = 'Name 1'
        { Invoke-SQLiteBulkCopy @script:VerboseParameters -DataTable $script:BulkDataTable -DataSource $script:SQLiteFile -Table Names -NotifyAfter 100 -Force } |
            Should -Throw

        $result = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
        $result[0].surname | Should -Be 'Name'

        { Invoke-SQLiteBulkCopy @script:VerboseParameters -DataTable $script:BulkDataTable -DataSource $script:SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Rollback -Force } |
            Should -Throw

        $result = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
        $result[0].surname | Should -Be 'Name'

        Invoke-SQLiteBulkCopy @script:VerboseParameters -DataTable $script:BulkDataTable -DataSource $script:SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Replace -Force

        $result = @(Invoke-SQLiteQuery @script:VerboseParameters -Database $script:SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
        $result[0].surname | Should -Be 'Name 1'
    }
}
