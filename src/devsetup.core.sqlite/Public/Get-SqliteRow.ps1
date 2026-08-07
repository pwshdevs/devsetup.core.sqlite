function Get-SqliteRow {
    <#
    .SYNOPSIS
        Reads rows from a SQLite table without requiring handwritten SELECT SQL.

    .DESCRIPTION
        Builds a parameterized SELECT statement from table, column, filter, ordering, and paging
        arguments. Table and column names are quoted as SQLite identifiers. Use Where for simple
        equality filters or WhereSql with SqlParameters for advanced predicates.

    .PARAMETER DataSource
        Path to the SQLite database file, or :MEMORY: for an in-memory database.

    .PARAMETER SQLiteConnection
        An existing SQLite connection. The command opens it if needed and never closes it.

    .PARAMETER Table
        Name of the table to read. On is an alias for this parameter.

    .PARAMETER Column
        Column names to return. The default is all columns. Columns is an alias.

    .PARAMETER Where
        Dictionary of column/value equality filters joined with AND. A null value generates IS NULL.

    .PARAMETER WhereSql
        Advanced SQL predicate without the WHERE keyword. Values should be supplied through SqlParameters.

    .PARAMETER SqlParameters
        Dictionary of values used by placeholders in WhereSql.

    .PARAMETER OrderBy
        One or more column names used to order the result.

    .PARAMETER Descending
        Sorts every OrderBy column in descending order.

    .PARAMETER Limit
        Maximum number of rows to return.

    .PARAMETER Offset
        Number of ordered rows to skip. Limit is required when Offset is used.

    .PARAMETER QueryTimeout
        Number of seconds before the query times out. The default is 600.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        Get-SqliteRow -DataSource ./app.sqlite -On Users -Where @{ Active = $true } -OrderBy Name -Limit 20

        Returns the first 20 active users ordered by name.

    .EXAMPLE
        Get-SqliteRow -DataSource ./app.sqlite -Table Events -WhereSql 'CreatedAt >= @since' -SqlParameters @{ since = $cutoff }

        Uses a parameterized custom predicate for an advanced filter.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite
    #>
    [CmdletBinding(DefaultParameterSetName = 'DataSource')]
    [OutputType([System.Management.Automation.PSCustomObject])]
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

        [Alias('Columns')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Column = @('*'),

        [System.Collections.IDictionary]$Where,

        [string]$WhereSql,

        [System.Collections.IDictionary]$SqlParameters,

        [ValidateNotNullOrEmpty()]
        [string[]]$OrderBy,

        [switch]$Descending,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$Offset,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$QueryTimeout = 600
    )

    if ($PSBoundParameters.ContainsKey('Offset') -and -not $PSBoundParameters.ContainsKey('Limit')) {
        throw 'Limit is required when Offset is used.'
    }

    $whereClause = ConvertTo-SqliteWhereClause `
        -Where $Where `
        -WhereSql $WhereSql `
        -SqlParameters $SqlParameters `
        -WhereWasBound $PSBoundParameters.ContainsKey('Where') `
        -WhereSqlWasBound $PSBoundParameters.ContainsKey('WhereSql')
    $columns = @($Column | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ -AllowWildcard })
    $tableName = ConvertTo-SqliteQuotedIdentifier -Name $Table
    $query = 'SELECT {0} FROM {1}' -f ($columns -join ', '), $tableName
    if ($whereClause.HasPredicate) {
        $query += ' WHERE {0}' -f $whereClause.Sql
    }
    $query += ConvertTo-SqliteOrderByClause -OrderBy $OrderBy -Descending:$Descending

    $parameters = [ordered]@{}
    foreach ($entry in $whereClause.Parameters.GetEnumerator()) {
        $parameters[$entry.Key] = $entry.Value
    }
    if ($PSBoundParameters.ContainsKey('Limit')) {
        $query += ' LIMIT @__crud_limit'
        $parameters['@__crud_limit'] = $Limit
        if ($PSBoundParameters.ContainsKey('Offset')) {
            $query += ' OFFSET @__crud_offset'
            $parameters['@__crud_offset'] = $Offset
        }
    }

    $context = $null
    try {
        $context = Get-SqliteCrudConnectionContext -DataSource $DataSource -SQLiteConnection $SQLiteConnection
        Invoke-SqliteCrudReader -Connection $context.Connection -Query $query -Parameters $parameters -QueryTimeout $QueryTimeout
    } finally {
        Close-SqliteCrudConnectionContext -Context $context
    }
}
