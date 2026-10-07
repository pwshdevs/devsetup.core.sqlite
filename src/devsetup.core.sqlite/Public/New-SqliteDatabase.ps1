function New-SqliteDatabase {
    <#
    .SYNOPSIS
        Creates and optionally initializes a persistent SQLite database.
    .DESCRIPTION
        Creates a new SQLite database file without overwriting an existing path. The database can
        be initialized from a structured PowerShell or JSON schema, a JSON schema file, inline SQL, or
        a SQL file. Initialization runs in one transaction. If it fails, the incomplete database and
        its SQLite sidecar files are removed.

        Structured schemas support tables, columns, literal defaults, primary and unique keys,
        foreign keys, indexes, STRICT tables, WITHOUT ROWID tables, and PRAGMA user_version.
    .PARAMETER Path
        Path of the new persistent SQLite database. The parent directory must already exist.
    .PARAMETER Schema
        Hashtable, PSCustomObject, or JSON text describing the database schema. Native PowerShell
        schema objects preserve scalar Default values such as byte arrays, DateTime, and
        DateTimeOffset. The root contains a required Tables array and an optional non-negative
        32-bit integer UserVersion. Each table contains Name and a Columns array, with optional
        PrimaryKey, UniqueConstraints, ForeignKeys, Indexes, Strict, and WithoutRowId properties.
        Each column requires Name and Type and can specify PrimaryKey, AutoIncrement, Nullable,
        Unique, Collation, Default, or DefaultExpression.
    .PARAMETER SchemaPath
        Path to a JSON file containing the structured database schema.
    .PARAMETER Query
        SQL used to initialize the database. Use Schema for safely generated routine DDL.
    .PARAMETER InputFile
        Path to a SQL file used to initialize the database.
    .PARAMETER QueryTimeout
        Number of seconds to wait for each initialization command. The default is 600 seconds.
        Specify zero to use the provider's unlimited timeout behavior.
    .PARAMETER PassThru
        Returns the open SQLiteConnection. The caller is responsible for disposing it. Without this
        switch, the command closes the connection and returns no output.
    .OUTPUTS
        System.Data.SQLite.SQLiteConnection when PassThru is specified. Otherwise, no output.
    .EXAMPLE
        New-SqliteDatabase -Path ./inventory.sqlite

        Creates an empty, valid SQLite database without replacing an existing file.
    .EXAMPLE
        New-SqliteDatabase -Path ./inventory.sqlite -Schema @{
            UserVersion = 1
            Tables = @(
                @{
                    Name = 'Items'
                    Columns = @(
                        @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                        @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false }
                        @{ Name = 'CreatedAt'; Type = 'TEXT'; DefaultExpression = 'CURRENT_TIMESTAMP' }
                    )
                    Indexes = @(
                        @{ Name = 'IX_Items_Name'; Columns = @('Name'); Unique = $true }
                    )
                }
            )
        }

        Creates and initializes a database from a native PowerShell schema object.
    .EXAMPLE
        New-SqliteDatabase -Path ./inventory.sqlite -SchemaPath ./schema.json

        Creates and initializes a database from a portable JSON schema document.
    .EXAMPLE
        $connection = New-SqliteDatabase -Path ./inventory.sqlite -InputFile ./schema.sql -PassThru
        try {
            Get-SqliteRow -SQLiteConnection $connection -On Items
        } finally {
            $connection.Dispose()
        }

        Initializes a database with raw SQL and returns its open connection for reuse.
    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite
    .FUNCTIONALITY
        SQL
    #>
    [CmdletBinding(DefaultParameterSetName = 'Empty', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Data.SQLite.SQLiteConnection])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('DataSource', 'Database', 'File', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Schema')]
        [ValidateNotNull()]
        [object]$Schema,

        [Parameter(Mandatory, ParameterSetName = 'SchemaFile')]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory, ParameterSetName = 'Query')]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter(Mandatory, ParameterSetName = 'QueryFile')]
        [ValidateNotNullOrEmpty()]
        [string]$InputFile,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$QueryTimeout = 600,

        [switch]$PassThru
    )

    if ($Path -eq ':MEMORY:') {
        throw 'New-SqliteDatabase creates persistent files. Use New-SqliteConnection -DataSource :MEMORY: for an in-memory database.'
    }

    $databasePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if ([System.IO.File]::Exists($databasePath) -or [System.IO.Directory]::Exists($databasePath)) {
        throw "Refusing to overwrite existing path '$databasePath'."
    }
    $parentPath = [System.IO.Path]::GetDirectoryName($databasePath)
    if ([string]::IsNullOrWhiteSpace($parentPath) -or -not [System.IO.Directory]::Exists($parentPath)) {
        throw "The parent directory for '$databasePath' does not exist."
    }

    $initializationStatements = @()
    switch ($PSCmdlet.ParameterSetName) {
        'Schema' {
            $initializationStatements = @(ConvertTo-SqliteSchemaStatement -Schema $Schema)
        }
        'SchemaFile' {
            $resolvedSchemaPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SchemaPath)
            if (-not [System.IO.File]::Exists($resolvedSchemaPath)) {
                throw "Schema file '$resolvedSchemaPath' does not exist."
            }
            if ([System.IO.Path]::GetExtension($resolvedSchemaPath) -ne '.json') {
                throw "SchemaPath must identify a JSON file. Use InputFile for SQL files."
            }
            $schemaJson = [System.IO.File]::ReadAllText($resolvedSchemaPath)
            $initializationStatements = @(ConvertTo-SqliteSchemaStatement -Schema $schemaJson)
        }
        'Query' {
            if ([string]::IsNullOrWhiteSpace($Query)) {
                throw 'Query cannot be empty or whitespace.'
            }
            $initializationStatements = @($Query)
        }
        'QueryFile' {
            $resolvedInputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputFile)
            if (-not [System.IO.File]::Exists($resolvedInputFile)) {
                throw "SQL input file '$resolvedInputFile' does not exist."
            }
            $sql = [System.IO.File]::ReadAllText($resolvedInputFile)
            if ([string]::IsNullOrWhiteSpace($sql)) {
                throw "SQL input file '$resolvedInputFile' is empty."
            }
            $initializationStatements = @($sql)
        }
    }

    if (-not $PSCmdlet.ShouldProcess($databasePath, 'Create SQLite database')) {
        return
    }

    $created = $false
    $succeeded = $false
    $connection = $null
    $transaction = $null
    $command = $null
    try {
        $placeholder = [System.IO.File]::Open(
            $databasePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $placeholder.Dispose()
        $created = $true

        $connection = New-SqliteConnection -DataSource $databasePath -ErrorAction Stop
        if ($null -eq $connection) {
            throw "The SQLite provider did not return a connection for '$databasePath'."
        }

        $transaction = $connection.BeginTransaction()
        $command = $connection.CreateCommand()
        $command.Transaction = $transaction
        $command.CommandTimeout = $QueryTimeout
        $command.CommandText = 'PRAGMA user_version = 0;'
        [void]$command.ExecuteNonQuery()

        foreach ($statement in $initializationStatements) {
            $command.CommandText = $statement
            [void]$command.ExecuteNonQuery()
        }
        $transaction.Commit()
        $succeeded = $true
    } catch {
        if ($null -ne $transaction) {
            try { $transaction.Rollback() } catch { Write-Verbose "Unable to roll back failed database initialization: $($_.Exception.Message)" }
        }
        throw
    } finally {
        if ($null -ne $command) {
            $command.Dispose()
        }
        if ($null -ne $transaction) {
            $transaction.Dispose()
        }
        if ($null -ne $connection -and (-not $succeeded -or -not $PassThru)) {
            $connection.Dispose()
            if (-not $succeeded) {
                [System.Data.SQLite.SQLiteConnection]::ClearPool($connection)
            }
        }
        if ($created -and -not $succeeded) {
            foreach ($candidate in @($databasePath, "$databasePath-journal", "$databasePath-wal", "$databasePath-shm")) {
                if ([System.IO.File]::Exists($candidate)) {
                    [System.IO.File]::Delete($candidate)
                }
            }
        }
    }

    if ($PassThru) {
        $connection
    }
}
