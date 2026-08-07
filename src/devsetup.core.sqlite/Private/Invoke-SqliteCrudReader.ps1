function Invoke-SqliteCrudReader {
    <#
    .SYNOPSIS
        Runs a generated SELECT statement and emits PowerShell objects.
    .DESCRIPTION
        Executes a parameterized reader query, scrubs database nulls, and disposes temporary ADO.NET objects.
    .PARAMETER Connection
        Open SQLite connection used for the query.
    .PARAMETER Query
        Generated SELECT statement.
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
    $adapter = $null
    $dataSet = New-Object System.Data.DataSet
    try {
        $command.CommandText = $Query
        $command.CommandTimeout = $QueryTimeout
        Add-SqliteCrudParameterSet -Command $command -Parameters $Parameters
        $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($command)
        [void]$adapter.Fill($dataSet)
        if ($dataSet.Tables.Count -gt 0) {
            foreach ($row in $dataSet.Tables[0].Rows) {
                [DevSetup.Core.SQLite.DBNullScrubber]::DataRowToPSObject($row)
            }
        }
    } finally {
        if ($null -ne $adapter) {
            $adapter.Dispose()
        }
        $command.Dispose()
        $dataSet.Dispose()
    }
}
