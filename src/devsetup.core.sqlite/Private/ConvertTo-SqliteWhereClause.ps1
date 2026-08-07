function ConvertTo-SqliteWhereClause {
    <#
    .SYNOPSIS
        Compiles structured or custom SQLite filter input.
    .DESCRIPTION
        Creates a parameterized equality predicate or validates a custom predicate and its parameter map.
    .PARAMETER Where
        Column/value equality filters.
    .PARAMETER WhereSql
        Custom SQL predicate without the WHERE keyword.
    .PARAMETER SqlParameters
        Values referenced by the custom predicate.
    .PARAMETER WhereWasBound
        Indicates whether Where was supplied.
    .PARAMETER WhereSqlWasBound
        Indicates whether WhereSql was supplied.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$Where,

        [string]$WhereSql,

        [System.Collections.IDictionary]$SqlParameters,

        [bool]$WhereWasBound,

        [bool]$WhereSqlWasBound
    )

    if ($WhereWasBound -and $WhereSqlWasBound) {
        throw 'Where and WhereSql cannot be used together.'
    }
    if ($null -ne $SqlParameters -and -not $WhereSqlWasBound) {
        throw 'SqlParameters can only be used with WhereSql.'
    }

    $parameters = [ordered]@{}
    if ($WhereSqlWasBound) {
        if ([string]::IsNullOrWhiteSpace($WhereSql)) {
            throw 'WhereSql cannot be empty.'
        }
        return [pscustomobject]@{
            Sql = '({0})' -f $WhereSql
            Parameters = ConvertTo-SqliteUserParameterMap -SqlParameters $SqlParameters
            HasPredicate = $true
        }
    }

    $predicates = New-Object 'System.Collections.Generic.List[string]'
    if ($null -ne $Where) {
        $index = 0
        foreach ($entry in $Where.GetEnumerator()) {
            $column = ConvertTo-SqliteQuotedIdentifier -Name ([string]$entry.Key)
            if ($null -eq $entry.Value -or $entry.Value -is [System.DBNull]) {
                $predicates.Add("$column IS NULL")
            } else {
                if (($entry.Value -is [System.Collections.IEnumerable]) -and
                    -not ($entry.Value -is [string]) -and
                    -not ($entry.Value -is [byte[]])) {
                    throw "Where value for '$($entry.Key)' is a collection. Use WhereSql for advanced predicates."
                }
                $parameterName = '@__crud_where{0}' -f $index
                $predicates.Add("$column = $parameterName")
                $parameters[$parameterName] = $entry.Value
                $index++
            }
        }
    }

    [pscustomobject]@{
        Sql = $predicates -join ' AND '
        Parameters = $parameters
        HasPredicate = ($predicates.Count -gt 0)
    }
}
