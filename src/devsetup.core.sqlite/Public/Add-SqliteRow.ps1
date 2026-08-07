function Add-SqliteRow {
    <#
    .SYNOPSIS
        Inserts one or more rows into a SQLite table.

    .DESCRIPTION
        Inserts dictionaries or PowerShell objects with one prepared statement and one transaction.
        The union of all supplied property names becomes the insert column list; a property missing
        from a row is inserted as NULL. Identifiers are quoted and values are always parameterized.

    .PARAMETER DataSource
        Path to the SQLite database file, or :MEMORY: for an in-memory database.

    .PARAMETER SQLiteConnection
        An existing SQLite connection. The command opens it if needed and never closes it.

    .PARAMETER Table
        Name of the table receiving the rows. On is an alias for this parameter.

    .PARAMETER Data
        Dictionaries or objects containing column names and values. Data accepts pipeline input.

    .PARAMETER ConflictAction
        SQLite conflict action used by the INSERT statement. The default is Abort.

    .PARAMETER QueryTimeout
        Number of seconds before an insert times out. The default is 600.

    .PARAMETER PassThru
        Returns each input row that SQLite reports as inserted.

    .INPUTS
        System.Object

    .OUTPUTS
        System.Object

    .EXAMPLE
        Add-SqliteRow -DataSource ./app.sqlite -On Users -Data @(@{ Name = 'Ada' }, @{ Name = 'Grace' })

        Inserts two rows in a single transaction.

    .EXAMPLE
        Import-Csv ./users.csv | Add-SqliteRow -DataSource ./app.sqlite -Table Users

        Inserts objects received from the pipeline.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite
    #>
    [CmdletBinding(DefaultParameterSetName = 'DataSource', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'DataSource')]
        [Alias('Path', 'File', 'Database')]
        [ValidateNotNullOrEmpty()]
        [string]$DataSource,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Connection')]
        [Alias('Connection', 'Conn')]
        [System.Data.SQLite.SQLiteConnection]$SQLiteConnection,

        [Parameter(Mandatory, Position = 1)]
        [Alias('On')]
        [ValidateNotNullOrEmpty()]
        [string]$Table,

        [Parameter(Mandatory, Position = 2, ValueFromPipeline)]
        [Alias('InputObject')]
        [object[]]$Data,

        [ValidateSet('Abort', 'Fail', 'Ignore', 'Replace', 'Rollback')]
        [string]$ConflictAction = 'Abort',

        [ValidateRange(0, [int]::MaxValue)]
        [int]$QueryTimeout = 600,

        [switch]$PassThru
    )

    begin {
        $records = New-Object 'System.Collections.Generic.List[object]'
        $columnNames = New-Object 'System.Collections.Generic.List[string]'
        $knownColumns = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($item in $Data) {
            $record = ConvertTo-SqliteRecord -InputRecord $item
            $records.Add($record)
            foreach ($columnName in $record.Keys) {
                if ($knownColumns.Add($columnName)) {
                    $columnNames.Add($columnName)
                }
            }
        }
    }

    end {
        if ($records.Count -eq 0) {
            return
        }
        if (-not $PSCmdlet.ShouldProcess($Table, "Insert $($records.Count) SQLite row(s)")) {
            return
        }

        $tableName = ConvertTo-SqliteQuotedIdentifier -Name $Table
        $quotedColumns = @($columnNames | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
        $parameterNames = @(0..($columnNames.Count - 1) | ForEach-Object { '@__crud_value{0}' -f $_ })
        $conflictSql = if ($ConflictAction -eq 'Abort') { '' } else { ' OR {0}' -f $ConflictAction.ToUpperInvariant() }
        $query = 'INSERT{0} INTO {1} ({2}) VALUES ({3})' -f @(
            $conflictSql
            $tableName
            ($quotedColumns -join ', ')
            ($parameterNames -join ', ')
        )

        $context = $null
        $transaction = $null
        $command = $null
        $insertedRecords = New-Object 'System.Collections.Generic.List[object]'
        try {
            $context = Get-SqliteCrudConnectionContext -DataSource $DataSource -SQLiteConnection $SQLiteConnection
            $transaction = $context.Connection.BeginTransaction()
            $command = $context.Connection.CreateCommand()
            $command.CommandText = $query
            $command.CommandTimeout = $QueryTimeout
            $command.Transaction = $transaction
            foreach ($parameterName in $parameterNames) {
                [void](Add-SqliteCrudParameter -Command $command -Name $parameterName -Value $null)
            }

            foreach ($record in $records) {
                for ($index = 0; $index -lt $columnNames.Count; $index++) {
                    $columnName = $columnNames[$index]
                    $recordKey = @($record.Keys | Where-Object {
                        [string]::Equals([string]$_, $columnName, [System.StringComparison]::OrdinalIgnoreCase)
                    } | Select-Object -First 1)
                    $value = if ($recordKey.Count -eq 1) { $record[$recordKey[0]] } else { $null }
                    $command.Parameters[$index].Value = ConvertTo-SqliteCrudValue -Value $value
                }
                if ($command.ExecuteNonQuery() -gt 0) {
                    $insertedRecords.Add($record)
                }
            }
            $transaction.Commit()

            if ($PassThru) {
                $insertedRecords
            }
        } catch {
            if ($null -ne $transaction) {
                try {
                    $transaction.Rollback()
                } catch {
                    Write-Verbose "The SQLite insert transaction could not be rolled back: $($_.Exception.Message)"
                }
            }
            throw
        } finally {
            if ($null -ne $command) {
                $command.Dispose()
            }
            if ($null -ne $transaction) {
                $transaction.Dispose()
            }
            Close-SqliteCrudConnectionContext -Context $context
        }
    }
}
