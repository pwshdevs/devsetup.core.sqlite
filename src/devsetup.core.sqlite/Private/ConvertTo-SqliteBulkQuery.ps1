function ConvertTo-SqliteBulkQuery {
    <#
    .SYNOPSIS
        Builds the prepared INSERT statement used by SQLite bulk copy.
    .DESCRIPTION
        Escapes table and column identifiers and pairs them with generated parameter placeholders.
    .PARAMETER Table
        Destination SQLite table.
    .PARAMETER Columns
        Destination column names.
    .PARAMETER Parameters
        Parameter names paired with the columns.
    .PARAMETER ConflictClause
        Optional SQLite INSERT conflict behavior.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Table,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Columns,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Parameters,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ConflictClause = ''
    )

    begin {
        $escapeSingleQuote = "'", "''"
        $delimiter = ', '
        $queryTemplate = 'INSERT{0} INTO {1} ({2}) VALUES ({3})'
    }

    process {
        $formattedConflictClause = if ($ConflictClause) { " OR $ConflictClause" }
        $formattedTable = "'{0}'" -f ($Table -replace $escapeSingleQuote)
        $formattedColumns = ($Columns | ForEach-Object { "'{0}'" -f ($_ -replace $escapeSingleQuote) }) -join $delimiter
        $formattedParameters = ($Parameters | ForEach-Object { "@$_" }) -join $delimiter
        $queryTemplate -f $formattedConflictClause, $formattedTable, $formattedColumns, $formattedParameters
    }
}
