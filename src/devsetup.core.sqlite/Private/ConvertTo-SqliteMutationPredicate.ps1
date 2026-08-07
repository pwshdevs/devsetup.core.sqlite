function ConvertTo-SqliteMutationPredicate {
    <#
    .SYNOPSIS
        Builds the final predicate for an update or delete.
    .DESCRIPTION
        Returns the direct filter or a portable identity subquery for an ordered limited mutation.
    .PARAMETER Connection
        Open SQLite connection used to inspect target identity.
    .PARAMETER Table
        Target table name.
    .PARAMETER WhereClause
        Compiled filter metadata.
    .PARAMETER OrderByClause
        Generated ORDER BY clause.
    .PARAMETER Offset
        Number of target rows to skip.
    .PARAMETER LimitWasBound
        Indicates whether a limited mutation was requested.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Table,

        [Parameter(Mandatory)]
        [psobject]$WhereClause,

        [string]$OrderByClause,

        [int]$Offset,

        [bool]$LimitWasBound
    )

    if (-not $LimitWasBound) {
        return $WhereClause.Sql
    }

    $identity = Get-SqliteTargetIdentity -Connection $Connection -Table $Table
    $tableName = ConvertTo-SqliteQuotedIdentifier -Name $Table
    $innerWhere = if ($WhereClause.HasPredicate) { ' WHERE {0}' -f $WhereClause.Sql } else { '' }
    $offsetSql = if ($Offset -gt 0) { ' OFFSET @__crud_offset' } else { '' }
    '{0} IN (SELECT {1} FROM {2}{3}{4} LIMIT @__crud_limit{5})' -f @(
        $identity.OuterExpression
        $identity.SelectExpression
        $tableName
        $innerWhere
        $OrderByClause
        $offsetSql
    )
}
