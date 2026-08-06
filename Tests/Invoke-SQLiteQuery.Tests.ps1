#handle PS2
if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\devsetup.core.sqlite -Force

$SQLiteFile = "$PSScriptRoot\Working.SQLite"
Remove-Item $SQLiteFile  -force -ErrorAction SilentlyContinue
Copy-Item $PSScriptRoot\Names.SQLite $PSScriptRoot\Working.SQLite -force

Describe "New-SQLiteConnection PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a connection' {
            $Script:Connection = New-SQLiteConnection @Verbose -DataSource :MEMORY:
            $Script:Connection.ConnectionString | Should be "Data Source=:MEMORY:;DateTimeFormat=InvariantCulture;DateTimeKind=Utc"
            $Script:Connection.State | Should be "Open"
        }

        It 'should expose configurable date and time parsing options' {
            $Connection = New-SQLiteConnection -DataSource :MEMORY: `
                -DateTimeFormat ISO8601 `
                -DateTimeKind Local `
                -DateTimeFormatString 'yyyyMMdd-HHmmss' `
                -Open $false

            try {
                $Builder = New-Object System.Data.SQLite.SQLiteConnectionStringBuilder($Connection.ConnectionString)
                $Builder.DateTimeFormat | Should Be ([System.Data.SQLite.SQLiteDateFormats]::ISO8601)
                $Builder.DateTimeKind | Should Be ([System.DateTimeKind]::Local)
                $Builder.DateTimeFormatString | Should Be 'yyyyMMdd-HHmmss'
                $Connection.State | Should Be 'Closed'
            }
            finally {
                $Connection.Dispose()
            }
        }

        It 'should load the current provider and SQLite engine' {
            [System.Data.SQLite.SQLiteConnection].Assembly.GetName().Version.ToString() | Should Be '2.0.4.0'

            $Command = $Script:Connection.CreateCommand()
            try {
                $Command.CommandText = 'SELECT sqlite_version()'
                $Command.ExecuteScalar() | Should Be '3.53.4'
            }
            finally {
                $Command.Dispose()
            }
        }
    }
}

Describe "devsetup.core.sqlite runtime assets PS$PSVersion" {

    Context 'Supported runtimes' {

        It 'should load under the devsetup.core.sqlite identity' {
            $Module = Get-Module devsetup.core.sqlite
            $Module.Name | Should Be 'devsetup.core.sqlite'
            $Module.Guid.ToString() | Should Be '1616685c-c7c0-457c-b156-a00a52e9890f'
            (Get-Module PSSQLite).Count | Should Be 0
            (Get-Command ConvertTo-SqliteDataTable -Module devsetup.core.sqlite).Name | Should Be 'ConvertTo-SqliteDataTable'
            @(Get-Command Out-DataTable -Module devsetup.core.sqlite -ErrorAction SilentlyContinue).Count | Should Be 0
        }

        It 'should load the precompiled portable support assembly' {
            $SupportAssemblyPath = Join-Path $PSScriptRoot '..\devsetup.core.sqlite\lib\devsetup.core.sqlite.Support.dll'

            (Test-Path -LiteralPath $SupportAssemblyPath -PathType Leaf) | Should Be $true
            [System.Reflection.AssemblyName]::GetAssemblyName($SupportAssemblyPath).Name |
                Should Be 'devsetup.core.sqlite.Support'
            ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]).Assembly.GetName().Name |
                Should Be 'devsetup.core.sqlite.Support'
        }

        It 'should bundle every supported PowerShell Core runtime' {
            $RuntimeFiles = @{
                'linux-arm'   = 'libe_sqlite3.so'
                'linux-arm64' = 'libe_sqlite3.so'
                'linux-x64'   = 'libe_sqlite3.so'
                'osx-arm64'   = 'libe_sqlite3.dylib'
                'osx-x64'     = 'libe_sqlite3.dylib'
                'win-arm64'   = 'e_sqlite3.dll'
                'win-x64'     = 'e_sqlite3.dll'
                'win-x86'     = 'e_sqlite3.dll'
            }

            foreach($RuntimeIdentifier in $RuntimeFiles.Keys)
            {
                $RuntimePath = Join-Path $PSScriptRoot "..\devsetup.core.sqlite\core\$RuntimeIdentifier"
                (Test-Path -LiteralPath (Join-Path $RuntimePath 'System.Data.SQLite.dll') -PathType Leaf) | Should Be $true
                (Test-Path -LiteralPath (Join-Path $RuntimePath $RuntimeFiles[$RuntimeIdentifier]) -PathType Leaf) | Should Be $true
                [System.Reflection.AssemblyName]::GetAssemblyName((Join-Path $RuntimePath 'System.Data.SQLite.dll')).Version.ToString() | Should Be '2.0.4.0'
            }
        }

        It 'should resolve supported ARM runtime identifiers' {
            $Module = Get-Module devsetup.core.sqlite
            $RuntimeCases = @(
                @{ Platform = 'linux'; Architecture = 'Arm'; Expected = 'linux-arm' },
                @{ Platform = 'linux'; Architecture = 'Arm64'; Expected = 'linux-arm64' },
                @{ Platform = 'osx'; Architecture = 'Arm64'; Expected = 'osx-arm64' },
                @{ Platform = 'win'; Architecture = 'Arm64'; Expected = 'win-arm64' }
            )

            foreach($RuntimeCase in $RuntimeCases)
            {
                & $Module {
                    Get-DevSetupSQLiteRuntimeIdentifier -Platform $args[0] -Architecture $args[1]
                } $RuntimeCase.Platform $RuntimeCase.Architecture | Should Be $RuntimeCase.Expected
            }
        }

        It 'should reject runtime identifiers without bundled native assets' {
            $Module = Get-Module devsetup.core.sqlite
            { & $Module { Get-DevSetupSQLiteRuntimeIdentifier -Platform osx -Architecture Arm } } | Should Throw
        }
    }
}

Describe "Invoke-SQLiteQuery PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should take file input' {
            $Out = @( Invoke-SqliteQuery @Verbose -DataSource $SQLiteFile -InputFile $PSScriptRoot\Test.SQL )
            $Out.count | Should be 2
            $Out[1].OrderID | Should be 500
        }

        It 'should take query input' {
            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "PRAGMA table_info(NAMES)" -ErrorAction Stop )
            $Out.count | Should Be 4
            $Out[0].Name | SHould Be "fullname"
        }

        It 'should reuse the module-level DBNull scrubber without compiling per query' {
            ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]).FullName |
                Should Be 'DevSetup.Core.SQLite.DBNullScrubber'

            Mock -CommandName Add-Type -ModuleName devsetup.core.sqlite -MockWith {}

            $Connection = New-SQLiteConnection -DataSource :MEMORY:
            try {
                $First = Invoke-SQLiteQuery -SQLiteConnection $Connection -Query 'SELECT NULL AS NullableValue' -ErrorAction Stop
                $Second = Invoke-SQLiteQuery -SQLiteConnection $Connection -Query 'SELECT 1 AS Value' -ErrorAction Stop

                @($First).Count | Should Be 1
                $First.NullableValue | Should BeNullOrEmpty
                $Second.Value | Should Be 1
                Assert-MockCalled -CommandName Add-Type -ModuleName devsetup.core.sqlite -Times 0 -Exactly
            }
            finally {
                $Connection.Dispose()
            }
        }

        It 'should parse offset timestamps using invariant UTC defaults' {
            $DateTimeSQLiteFile = Join-Path $PSScriptRoot 'DateTime.Working.SQLite'
            Remove-Item $DateTimeSQLiteFile -Force -ErrorAction SilentlyContinue

            try {
                Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile -Query 'CREATE TABLE Events (OccurredAt DATETIME)' -ErrorAction Stop
                Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile -Query @'
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02 04:59:18.578 +00:00');
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02T05:59:18.578Z');
INSERT INTO Events (OccurredAt) VALUES ('2019-07-02 04:59:18.578 -05:00');
'@ -ErrorAction Stop

                $Out = @(Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile -Query 'SELECT OccurredAt FROM Events ORDER BY rowid' -ErrorAction Stop)

                $Out.Count | Should Be 3
                $Out[0].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should Be '2019-07-02T04:59:18.578'
                $Out[1].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should Be '2019-07-02T05:59:18.578'
                $Out[2].OccurredAt.ToString('yyyy-MM-ddTHH:mm:ss.fff') | Should Be '2019-07-02T09:59:18.578'

                Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile -Query 'CREATE TABLE CustomEvents (OccurredAt DATETIME)' -ErrorAction Stop
                Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile -Query "INSERT INTO CustomEvents VALUES ('20190702-045918')" -ErrorAction Stop

                $CustomOut = Invoke-SQLiteQuery -DataSource $DateTimeSQLiteFile `
                    -Query 'SELECT OccurredAt FROM CustomEvents' `
                    -DateTimeFormatString 'yyyyMMdd-HHmmss' `
                    -ErrorAction Stop

                $CustomOut.OccurredAt.ToString('yyyyMMdd-HHmmss') | Should Be '20190702-045918'
            }
            finally {
                Remove-Item $DateTimeSQLiteFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'should support parameterized queries' {
            
            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/13/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 1
            $Out[0].fullname | Should Be "Cookie Monster"

            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/15/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 0
        }

        It 'should use existing SQLiteConnections' {
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "SELECT name AS [table] FROM sqlite_master WHERE type = 'table' AND name = 'OrdersToNames'" ) |
                Select -first 1 -ExpandProperty table |
                Should be 'OrdersToNames'

            $Script:COnnection.State | Should Be Open

            $Script:Connection.close()
        }

        It 'should respect PowerShell expectations for null' {
            
            #The SQL folks out there might be annoyed by this, but we want to treat DBNulls as null to allow expected PowerShell operator behavior.

            $Connection = New-SQLiteConnection -DataSource :MEMORY: 
            try {
                Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
                Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
                Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID) VALUES (2);"

                @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "SELECT * FROM OrdersToNames" -As DataRow | Where{$_.fullname}).count |
                    Should Be 2

                @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "SELECT * FROM OrdersToNames" | Where{$_.fullname} ).count |
                    Should Be 1
            }
            finally {
                $Connection.Dispose()
            }
        }
    }
}

Describe "ConvertTo-SqliteDataTable PS$PSVersion" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a DataTable' {
            
            $Script:DataTable = 1..1000 | %{
                New-Object -TypeName PSObject -property @{
                    fullname = "Name $_"
                    surname = "Name"
                    givenname = "$_"
                    BirthDate = (Get-Date).Adddays(-$_)
                } | Select fullname, surname, givenname, birthdate
            } | ConvertTo-SqliteDataTable @Verbose

            $Script:DataTable.GetType().Fullname | Should Be 'System.Data.DataTable'
            @($Script:DataTable.Rows).Count | Should Be 1000
            $Columns = $Script:DataTable.Columns | Select -ExpandProperty ColumnName
            $Columns[0] | Should Be 'fullname'
            $Columns[3] | Should Be 'BirthDate'
            $Script:DataTable.columns[3].datatype.fullname | Should Be 'System.DateTime'
            
        }
    }
}

Describe "Invoke-SQLiteBulkCopy PS$PSVersion" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should insert data' {
            Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force
            
            @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT fullname FROM NAMES WHERE surname = 'Name'" ).count | Should Be 1000
        }
        It "should adhere to ConflictCause" {
            
            #Basic set of tests, need more...

            #Try adding same data
            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force } | Should Throw
            
            #Change a known row's prop we can test to ensure it does or does not change
            $Script:DataTable.Rows[0].surname = "Name 1"
            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force } | Should Throw

            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'

            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Rollback -Force } | Should Throw
            
            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'

            Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Replace -Force

            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name 1'


        }
    }
}

Remove-Item $SQLiteFile -force -ErrorAction SilentlyContinue
