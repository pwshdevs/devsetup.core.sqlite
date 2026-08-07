function Remove-SqliteRow {
    <#
    .SYNOPSIS
        Deletes rows from a SQLite table without requiring handwritten DELETE SQL.

    .DESCRIPTION
        Builds a parameterized DELETE statement. A delete must have a non-empty Where/WhereSql
        predicate unless All is explicitly supplied. Ordered limited deletes are implemented portably
        through the table primary key or rowid and do not require a special SQLite compile option.

    .PARAMETER DataSource
        Path to the SQLite database file, or :MEMORY: for an in-memory database.

    .PARAMETER SQLiteConnection
        An existing SQLite connection. The command opens it if needed and never closes it.

    .PARAMETER Table
        Name of the table from which rows are deleted. On is an alias for this parameter.

    .PARAMETER Where
        Dictionary of column/value equality filters joined with AND. A null value generates IS NULL.

    .PARAMETER WhereSql
        Advanced SQL predicate without the WHERE keyword. Values should be supplied through SqlParameters.

    .PARAMETER SqlParameters
        Dictionary of values used by placeholders in WhereSql.

    .PARAMETER All
        Explicitly permits a delete without a filter.

    .PARAMETER OrderBy
        Columns used to select rows deterministically for a limited delete. Limit is required.

    .PARAMETER Descending
        Sorts every OrderBy column in descending order.

    .PARAMETER Limit
        Maximum number of ordered rows to delete. OrderBy is required.

    .PARAMETER Offset
        Number of ordered rows to skip before deleting. Limit is required.

    .PARAMETER QueryTimeout
        Number of seconds before the delete times out. The default is 600.

    .PARAMETER PassThru
        Returns the number of rows deleted.

    .OUTPUTS
        System.Int32

    .EXAMPLE
        Remove-SqliteRow -DataSource ./app.sqlite -On Sessions -Where @{ Expired = $true } -Confirm:$false

        Deletes expired sessions after applying a parameterized equality filter.

    .EXAMPLE
        Remove-SqliteRow -DataSource ./queue.sqlite -Table Queue -All -OrderBy CreatedAt -Limit 100 -Confirm:$false

        Deletes the oldest 100 rows after explicitly allowing an unfiltered operation.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite
    #>
    [CmdletBinding(DefaultParameterSetName = 'DataSource', SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([int])]
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

        [System.Collections.IDictionary]$Where,

        [string]$WhereSql,

        [System.Collections.IDictionary]$SqlParameters,

        [switch]$All,

        [ValidateNotNullOrEmpty()]
        [string[]]$OrderBy,

        [switch]$Descending,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$Offset,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$QueryTimeout = 600,

        [switch]$PassThru
    )

    $whereClause = ConvertTo-SqliteWhereClause `
        -Where $Where `
        -WhereSql $WhereSql `
        -SqlParameters $SqlParameters `
        -WhereWasBound $PSBoundParameters.ContainsKey('Where') `
        -WhereSqlWasBound $PSBoundParameters.ContainsKey('WhereSql')
    $scopeArguments = @{
        WhereClause = $whereClause
        All = $All
        WhereWasBound = $PSBoundParameters.ContainsKey('Where')
        WhereSqlWasBound = $PSBoundParameters.ContainsKey('WhereSql')
        LimitWasBound = $PSBoundParameters.ContainsKey('Limit')
        OrderByWasBound = $PSBoundParameters.ContainsKey('OrderBy')
        OffsetWasBound = $PSBoundParameters.ContainsKey('Offset')
    }
    Assert-SqliteMutationScope @scopeArguments

    if (-not $PSCmdlet.ShouldProcess($Table, 'Delete SQLite row(s)')) {
        return
    }

    $context = $null
    try {
        $context = Get-SqliteCrudConnectionContext -DataSource $DataSource -SQLiteConnection $SQLiteConnection
        $orderByClause = ConvertTo-SqliteOrderByClause -OrderBy $OrderBy -Descending:$Descending
        $predicate = ConvertTo-SqliteMutationPredicate `
            -Connection $context.Connection `
            -Table $Table `
            -WhereClause $whereClause `
            -OrderByClause $orderByClause `
            -Offset $Offset `
            -LimitWasBound $PSBoundParameters.ContainsKey('Limit')
        $query = 'DELETE FROM {0}' -f (ConvertTo-SqliteQuotedIdentifier -Name $Table)
        if (-not [string]::IsNullOrWhiteSpace($predicate)) {
            $query += ' WHERE {0}' -f $predicate
        }

        $parameters = [ordered]@{}
        foreach ($entry in $whereClause.Parameters.GetEnumerator()) {
            $parameters[$entry.Key] = $entry.Value
        }
        if ($PSBoundParameters.ContainsKey('Limit')) {
            $parameters['@__crud_limit'] = $Limit
            if ($PSBoundParameters.ContainsKey('Offset')) {
                $parameters['@__crud_offset'] = $Offset
            }
        }

        $rowsAffected = Invoke-SqliteCrudNonQuery `
            -Connection $context.Connection `
            -Query $query `
            -Parameters $parameters `
            -QueryTimeout $QueryTimeout
        if ($PassThru) {
            $rowsAffected
        }
    } finally {
        Close-SqliteCrudConnectionContext -Context $context
    }
}
