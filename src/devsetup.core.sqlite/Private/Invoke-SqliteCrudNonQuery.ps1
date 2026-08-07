function Invoke-SqliteCrudNonQuery {
    <#
    .SYNOPSIS
        Executes one parameterized SQLite statement and returns its affected-row count.

    .DESCRIPTION
        Creates and disposes a SQLite command while leaving ownership of the connection with the caller.
    .PARAMETER Connection
        Open SQLite connection used for the statement.
    .PARAMETER Query
        Generated UPDATE or DELETE statement.
    .PARAMETER Parameters
        Parameter names and values to bind.
    .PARAMETER QueryTimeout
        Command timeout in seconds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Query,

        [System.Collections.IDictionary]$Parameters,

        [int]$QueryTimeout = 600
    )

    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $Query
        $command.CommandTimeout = $QueryTimeout
        Add-SqliteCrudParameterSet -Command $command -Parameters $Parameters
        $command.ExecuteNonQuery()
    } finally {
        $command.Dispose()
    }
}
