Describe 'New-SqliteDatabase' {
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

BeforeEach {
    $script:databaseConnection = $null
}

AfterEach {
    if ($null -ne $script:databaseConnection) {
        $script:databaseConnection.Dispose()
        $script:databaseConnection = $null
    }
    [System.Data.SQLite.SQLiteConnection]::ClearAllPools()
}

It 'creates a valid empty SQLite database without returning output' {
    $path = Join-Path $TestDrive 'empty.sqlite'

    $result = New-SqliteDatabase -Path $path

    $result | Should -BeNullOrEmpty
    Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
    $header = [System.IO.File]::ReadAllBytes($path)[0..15]
    [System.Text.Encoding]::ASCII.GetString($header) | Should -Be "SQLite format 3`0"
    Invoke-SqliteQuery -DataSource $path -Query 'PRAGMA user_version' -As SingleValue | Should -Be 0
}

    It 'creates a rich schema from a PowerShell object' {
    $path = Join-Path $TestDrive 'object schema.sqlite'
    $schema = @{
        UserVersion = 7
        Tables = @(
            @{
                Name = 'Owners'
                Strict = $true
                Columns = @(
                    @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true }
                    @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false; Unique = $true }
                )
            }
            @{
                Name = 'Items'
                Strict = $true
                Columns = @(
                    @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                    @{ Name = 'OwnerId'; Type = 'INTEGER'; Nullable = $false }
                    @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false; Default = "owner's item"; Collation = 'NOCASE' }
                    @{ Name = 'CreatedAt'; Type = 'TEXT'; DefaultExpression = 'CURRENT_TIMESTAMP' }
                )
                UniqueConstraints = @(
                    @{ Name = 'UQ_Items_OwnerName'; Columns = @('OwnerId', 'Name') }
                )
                ForeignKeys = @(
                    @{
                        Name = 'FK_Items_Owners'
                        Columns = @('OwnerId')
                        References = @{ Table = 'Owners'; Columns = @('Id') }
                        OnDelete = 'CASCADE'
                        OnUpdate = 'NO ACTION'
                    }
                )
                Indexes = @(
                    @{ Name = 'IX_Items_CreatedAt'; Columns = @('CreatedAt') }
                )
            }
        )
    }

    New-SqliteDatabase -Path $path -Schema $schema
    Invoke-SqliteQuery -DataSource $path -Query 'PRAGMA user_version' -As SingleValue | Should -Be 7
    Invoke-SqliteQuery -DataSource $path -Query "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('Owners', 'Items')" -As SingleValue |
        Should -Be 2
    Invoke-SqliteQuery -DataSource $path -Query "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = 'IX_Items_CreatedAt'" -As SingleValue |
        Should -Be 1

    Add-SqliteRow -DataSource $path -Table Owners -Data @{ Id = 1; Name = 'Ada' }
    Add-SqliteRow -DataSource $path -Table Items -Data @{ OwnerId = 1 }
    $item = Get-SqliteRow -DataSource $path -Table Items
    $item.Name | Should -Be "owner's item"
    $item.CreatedAt | Should -Not -BeNullOrEmpty

    $foreignKey = Invoke-SqliteQuery -DataSource $path -Query 'PRAGMA foreign_key_list("Items")' -As PSObject
    $foreignKey.table | Should -Be 'Owners'
        $foreignKey.on_delete | Should -Be 'CASCADE'
    }

    It 'preserves native PowerShell scalar defaults without JSON coercion' {
        $path = Join-Path $TestDrive 'native-defaults.sqlite'
        $dateDefault = [datetime]::SpecifyKind(
            [datetime]'2026-08-07T12:34:56.789',
            [System.DateTimeKind]::Unspecified
        )
        $offsetDefault = [datetimeoffset]'2026-08-07T07:34:56.0000000-05:00'
        $blobDefault = [byte[]]@(0xCA, 0xFE)
        $schema = [ordered]@{
            UserVersion = [uint16]3
            Tables = @(
                [ordered]@{
                    Name = 'NativeDefaults'
                    Columns = @(
                        [ordered]@{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true }
                        [ordered]@{ Name = 'Enabled'; Type = 'INTEGER'; Default = $true }
                        [ordered]@{ Name = 'Amount'; Type = 'REAL'; Default = [decimal]12.50 }
                        [ordered]@{ Name = 'CreatedAt'; Type = 'TEXT'; Default = $dateDefault }
                        [ordered]@{ Name = 'ObservedAt'; Type = 'TEXT'; Default = $offsetDefault }
                        [ordered]@{ Name = 'Signature'; Type = 'BLOB'; Default = $blobDefault }
                    )
                }
            )
        }

        New-SqliteDatabase -Path $path -Schema $schema
        Add-SqliteRow -DataSource $path -Table NativeDefaults -Data @{ Id = 1 }
        $row = Get-SqliteRow -DataSource $path -Table NativeDefaults

        $row.Enabled | Should -Be 1
        $row.Amount | Should -Be 12.5
        $row.CreatedAt | Should -Be '2026-08-07 12:34:56.789'
        $row.ObservedAt | Should -Be '2026-08-07T12:34:56.0000000+00:00'
        [System.BitConverter]::ToString([byte[]]$row.Signature) | Should -Be 'CA-FE'
    }

It 'creates a schema from JSON text and safely quotes identifiers' {
    $path = Join-Path $TestDrive 'json.sqlite'
    $json = @'
{
  "tables": [
    {
      "name": "Order \"Lines",
      "columns": [
        { "name": "select", "type": "INTEGER", "primaryKey": true },
        { "name": "Display Name", "type": "TEXT", "nullable": false }
      ]
    }
  ]
}
'@

    New-SqliteDatabase -Path $path -Schema $json
    Add-SqliteRow -DataSource $path -Table 'Order "Lines' -Data @{ select = 1; 'Display Name' = 'safe' }

    (Get-SqliteRow -DataSource $path -Table 'Order "Lines').'Display Name' | Should -Be 'safe'
}

It 'creates a schema from a JSON file' {
    $path = Join-Path $TestDrive 'schema-file.sqlite'
    $schemaPath = Join-Path $TestDrive 'schema.json'
    @'
{
  "userVersion": 2,
  "tables": [
    {
      "name": "Settings",
      "withoutRowId": true,
      "strict": true,
      "columns": [
        { "name": "Name", "type": "TEXT" },
        { "name": "Value", "type": "TEXT", "default": null }
      ],
      "primaryKey": ["Name"]
    }
  ]
}
'@ | Set-Content -LiteralPath $schemaPath -NoNewline

    New-SqliteDatabase -Path $path -SchemaPath $schemaPath

    Invoke-SqliteQuery -DataSource $path -Query 'PRAGMA user_version' -As SingleValue | Should -Be 2
    Add-SqliteRow -DataSource $path -Table Settings -Data @{ Name = 'theme' }
    (Get-SqliteRow -DataSource $path -Table Settings).Value | Should -BeNullOrEmpty
}

It 'initializes from inline SQL and a SQL file' {
    $inlinePath = Join-Path $TestDrive 'inline.sqlite'
    New-SqliteDatabase -Path $inlinePath -Query 'CREATE TABLE InlineTable (Id INTEGER); INSERT INTO InlineTable VALUES (1);'
    Invoke-SqliteQuery -DataSource $inlinePath -Query 'SELECT Id FROM InlineTable' -As SingleValue | Should -Be 1

    $filePath = Join-Path $TestDrive 'file.sqlite'
    $sqlPath = Join-Path $TestDrive 'schema.sql'
    'CREATE TABLE FileTable (Id INTEGER); INSERT INTO FileTable VALUES (2);' |
        Set-Content -LiteralPath $sqlPath -NoNewline
    New-SqliteDatabase -Path $filePath -InputFile $sqlPath
    Invoke-SqliteQuery -DataSource $filePath -Query 'SELECT Id FROM FileTable' -As SingleValue | Should -Be 2
}

It 'returns an open caller-owned connection with PassThru' {
    $path = Join-Path $TestDrive 'passthru.sqlite'

    $script:databaseConnection = New-SqliteDatabase -Path $path -Query 'CREATE TABLE People (Id INTEGER)' -PassThru

    $databaseConnection | Should -BeOfType System.Data.SQLite.SQLiteConnection
    $databaseConnection.State | Should -Be 'Open'
    Invoke-SqliteQuery -SQLiteConnection $databaseConnection -Query 'SELECT COUNT(*) FROM People' -As SingleValue |
        Should -Be 0
}

It 'refuses to overwrite an existing file and preserves its contents' {
    $path = Join-Path $TestDrive 'existing.sqlite'
    [System.IO.File]::WriteAllText($path, 'keep this exact content')

    { New-SqliteDatabase -Path $path -ErrorAction Stop } | Should -Throw '*Refusing to overwrite*'

    [System.IO.File]::ReadAllText($path) | Should -Be 'keep this exact content'
}

It 'removes the database and sidecars when SQL initialization fails' {
    $path = Join-Path $TestDrive 'invalid.sqlite'

    { New-SqliteDatabase -Path $path -Query 'CREATE TABLE Broken (' -ErrorAction Stop } | Should -Throw

    Test-Path -LiteralPath $path | Should -BeFalse
    Test-Path -LiteralPath "$path-journal" | Should -BeFalse
    Test-Path -LiteralPath "$path-wal" | Should -BeFalse
    Test-Path -LiteralPath "$path-shm" | Should -BeFalse
}

It 'validates structured schemas before creating the file' {
    $path = Join-Path $TestDrive 'invalid-schema.sqlite'
    $schema = @{
        Tables = @(
            @{
                Name = 'People'
                Columns = @(@{ Name = 'Id'; Type = 'INTEGER' })
                Indexes = @(@{ Name = 'IX_Bad'; Columns = @('Missing') })
            }
        )
    }

    { New-SqliteDatabase -Path $path -Schema $schema -ErrorAction Stop } | Should -Throw '*unknown column*'
    Test-Path -LiteralPath $path | Should -BeFalse
}

    It 'rejects misspelled schema properties before creating the file' {
    $path = Join-Path $TestDrive 'misspelled-schema.sqlite'
    $schema = @{
        Tables = @(
            @{
                Name = 'People'
                Columns = @(@{ Name = 'Id'; Type = 'INTEGER'; Nullible = $false })
            }
        )
    }

    { New-SqliteDatabase -Path $path -Schema $schema -ErrorAction Stop } |
        Should -Throw "*unsupported property 'Nullible'*"
        Test-Path -LiteralPath $path | Should -BeFalse
    }

    It 'rejects scalar collection properties before creating the file' {
        $path = Join-Path $TestDrive 'scalar-tables.sqlite'
        $schema = @{
            Tables = @{
                Name = 'People'
                Columns = @(@{ Name = 'Id'; Type = 'INTEGER' })
            }
        }

        { New-SqliteDatabase -Path $path -Schema $schema -ErrorAction Stop } |
            Should -Throw "*property 'Tables' must be an array*"
        Test-Path -LiteralPath $path | Should -BeFalse
    }

    It 'rejects non-integer user versions before creating the file' {
        foreach ($invalidVersion in @('1', 1.5, $true, -1, ([uint64][int]::MaxValue + [uint64]1))) {
            $path = Join-Path $TestDrive "invalid-version-$([guid]::NewGuid()).sqlite"
            $schema = @{
                UserVersion = $invalidVersion
                Tables = @(
                    @{
                        Name = 'People'
                        Columns = @(@{ Name = 'Id'; Type = 'INTEGER' })
                    }
                )
            }

            { New-SqliteDatabase -Path $path -Schema $schema -ErrorAction Stop } |
                Should -Throw "*UserVersion*non-negative 32-bit integer*"
            Test-Path -LiteralPath $path | Should -BeFalse
        }
    }

    It 'rejects case-insensitive duplicate schema properties' {
        $path = Join-Path $TestDrive 'duplicate-properties.sqlite'
        $schema = [System.Collections.Generic.Dictionary[string, object]]::new(
            [System.StringComparer]::Ordinal
        )
        $schema['Tables'] = @(
            @{
                Name = 'People'
                Columns = @(@{ Name = 'Id'; Type = 'INTEGER' })
            }
        )
        $schema['tables'] = @()

        { New-SqliteDatabase -Path $path -Schema $schema -ErrorAction Stop } |
            Should -Throw '*duplicate property*'
        Test-Path -LiteralPath $path | Should -BeFalse
    }

It 'requires an existing parent directory' {
    $path = Join-Path (Join-Path $TestDrive 'missing') 'database.sqlite'

    { New-SqliteDatabase -Path $path -ErrorAction Stop } | Should -Throw '*parent directory*'
    Test-Path -LiteralPath $path | Should -BeFalse
}

It 'does not create a database under WhatIf' {
    $path = Join-Path $TestDrive 'whatif.sqlite'

    New-SqliteDatabase -Path $path -WhatIf

    Test-Path -LiteralPath $path | Should -BeFalse
}

It 'directs in-memory callers to New-SqliteConnection' {
    { New-SqliteDatabase -Path :MEMORY: -ErrorAction Stop } |
        Should -Throw '*New-SqliteConnection -DataSource :MEMORY:*'
}
}
