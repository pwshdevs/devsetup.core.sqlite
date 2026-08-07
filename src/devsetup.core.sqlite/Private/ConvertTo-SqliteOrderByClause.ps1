function ConvertTo-SqliteOrderByClause {
    <#
    .SYNOPSIS
        Builds a quoted SQLite ORDER BY clause.
    .DESCRIPTION
        Quotes each supplied column and applies one ascending or descending direction.
    .PARAMETER OrderBy
        Column names used for sorting.
    .PARAMETER Descending
        Uses descending rather than ascending order.
    #>
    [CmdletBinding()]
    param(
        [string[]]$OrderBy,

        [switch]$Descending
    )

    if ($null -eq $OrderBy -or $OrderBy.Count -eq 0) {
        return ''
    }

    $direction = if ($Descending) { ' DESC' } else { ' ASC' }
    $terms = foreach ($column in $OrderBy) {
        '{0}{1}' -f (ConvertTo-SqliteQuotedIdentifier -Name $column), $direction
    }
    ' ORDER BY {0}' -f ($terms -join ', ')
}
