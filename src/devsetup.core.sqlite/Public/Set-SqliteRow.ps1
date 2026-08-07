function Set-SqliteRow {
    <#
    .SYNOPSIS
        Updates rows in a SQLite table without requiring handwritten UPDATE SQL.

    .DESCRIPTION
        Builds a parameterized UPDATE statement from a dictionary or object. An update must have a
        non-empty Where/WhereSql predicate unless All is explicitly supplied. Ordered limited updates
        are implemented portably through the table primary key or rowid.

    .PARAMETER DataSource
        Path to the SQLite database file, or :MEMORY: for an in-memory database.

    .PARAMETER SQLiteConnection
        An existing SQLite connection. The command opens it if needed and never closes it.

    .PARAMETER Table
        Name of the table to update. On is an alias for this parameter.

    .PARAMETER Values
        Dictionary or object containing the columns and new values. Data and Set are aliases.

    .PARAMETER Where
        Dictionary of column/value equality filters joined with AND. A null value generates IS NULL.

    .PARAMETER WhereSql
        Advanced SQL predicate without the WHERE keyword. Values should be supplied through SqlParameters.

    .PARAMETER SqlParameters
        Dictionary of values used by placeholders in WhereSql.

    .PARAMETER All
        Explicitly permits an update without a filter.

    .PARAMETER OrderBy
        Columns used to select rows deterministically for a limited update. Limit is required.

    .PARAMETER Descending
        Sorts every OrderBy column in descending order.

    .PARAMETER Limit
        Maximum number of ordered rows to update. OrderBy is required.

    .PARAMETER Offset
        Number of ordered rows to skip before updating. Limit is required.

    .PARAMETER QueryTimeout
        Number of seconds before the update times out. The default is 600.

    .PARAMETER PassThru
        Returns the number of rows updated.

    .OUTPUTS
        System.Int32

    .EXAMPLE
        Set-SqliteRow -DataSource ./app.sqlite -On Users -Values @{ Active = $false } -Where @{ Id = 42 }

        Deactivates the user with Id 42.

    .EXAMPLE
        Set-SqliteRow -DataSource ./jobs.sqlite -Table Jobs -Values @{ State = 'Queued' } -All -OrderBy CreatedAt -Limit 10

        Updates the ten oldest jobs after explicitly allowing an unfiltered operation.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite
    #>
    [CmdletBinding(DefaultParameterSetName = 'DataSource', SupportsShouldProcess, ConfirmImpact = 'Medium')]
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

        [Parameter(Mandatory, Position = 2)]
        [Alias('Data', 'Set')]
        [ValidateNotNull()]
        [object]$Values,

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

    $valueRecord = ConvertTo-SqliteRecord -InputRecord $Values
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

    if (-not $PSCmdlet.ShouldProcess($Table, 'Update SQLite row(s)')) {
        return
    }

    $tableName = ConvertTo-SqliteQuotedIdentifier -Name $Table
    $setTerms = New-Object 'System.Collections.Generic.List[string]'
    $parameters = [ordered]@{}
    $index = 0
    foreach ($entry in $valueRecord.GetEnumerator()) {
        $parameterName = '@__crud_set{0}' -f $index
        $setTerm = '{0} = {1}' -f (ConvertTo-SqliteQuotedIdentifier -Name ([string]$entry.Key)), $parameterName
        $setTerms.Add($setTerm)
        $parameters[$parameterName] = $entry.Value
        $index++
    }
    foreach ($entry in $whereClause.Parameters.GetEnumerator()) {
        $parameters[$entry.Key] = $entry.Value
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
        $query = 'UPDATE {0} SET {1}' -f $tableName, ($setTerms -join ', ')
        if (-not [string]::IsNullOrWhiteSpace($predicate)) {
            $query += ' WHERE {0}' -f $predicate
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
