function Get-SqliteTargetIdentity {
    <#
    .SYNOPSIS
        Finds a stable SQLite row identity for a limited mutation.
    .DESCRIPTION
        Uses primary-key columns when present and otherwise selects an available rowid alias.
    .PARAMETER Connection
        Open SQLite connection used to inspect table metadata.
    .PARAMETER Table
        Table whose identity columns are inspected.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Table
    )

    $command = $Connection.CreateCommand()
    $reader = $null
    try {
        $command.CommandText = 'SELECT name, pk FROM pragma_table_info(@__crud_table) ORDER BY pk, cid'
        [void](Add-SqliteCrudParameter -Command $command -Name '@__crud_table' -Value $Table)
        $reader = $command.ExecuteReader()
        $columns = New-Object 'System.Collections.Generic.List[object]'
        while ($reader.Read()) {
            $columns.Add([pscustomobject]@{
                Name = $reader.GetString(0)
                PrimaryKeyOrder = $reader.GetInt32(1)
            })
        }
    } finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
        $command.Dispose()
    }

    if ($columns.Count -eq 0) {
        throw "SQLite table '$Table' was not found or has no columns."
    }

    $keyColumns = @($columns | Where-Object PrimaryKeyOrder -GT 0 | Sort-Object PrimaryKeyOrder)
    if ($keyColumns.Count -gt 0) {
        $quoted = @($keyColumns | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_.Name })
        if ($quoted.Count -eq 1) {
            return [pscustomobject]@{
                OuterExpression = $quoted[0]
                SelectExpression = $quoted[0]
            }
        }
        return [pscustomobject]@{
            OuterExpression = '({0})' -f ($quoted -join ', ')
            SelectExpression = $quoted -join ', '
        }
    }

    $columnNames = @($columns | ForEach-Object Name)
    $rowIdName = @('rowid', '_rowid_', 'oid') |
        Where-Object { $_ -notin $columnNames } |
        Select-Object -First 1
    if ($null -eq $rowIdName) {
        throw "SQLite table '$Table' hides every rowid alias and has no primary key; ordered limited mutations are not possible."
    }

    [pscustomobject]@{
        OuterExpression = $rowIdName
        SelectExpression = $rowIdName
    }
}
