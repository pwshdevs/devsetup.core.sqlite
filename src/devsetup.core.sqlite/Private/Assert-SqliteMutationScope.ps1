function Assert-SqliteMutationScope {
    <#
    .SYNOPSIS
        Validates update and delete safety rules.
    .DESCRIPTION
        Rejects unscoped mutations and invalid combinations of filtering, ordering, paging, and All.
    .PARAMETER WhereClause
        Compiled filter metadata.
    .PARAMETER All
        Indicates that an unfiltered mutation was explicitly requested.
    .PARAMETER WhereWasBound
        Indicates whether Where was supplied.
    .PARAMETER WhereSqlWasBound
        Indicates whether WhereSql was supplied.
    .PARAMETER LimitWasBound
        Indicates whether Limit was supplied.
    .PARAMETER OrderByWasBound
        Indicates whether OrderBy was supplied.
    .PARAMETER OffsetWasBound
        Indicates whether Offset was supplied.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$WhereClause,

        [switch]$All,

        [bool]$WhereWasBound,

        [bool]$WhereSqlWasBound,

        [bool]$LimitWasBound,

        [bool]$OrderByWasBound,

        [bool]$OffsetWasBound
    )

    if ($All -and ($WhereWasBound -or $WhereSqlWasBound)) {
        throw 'All cannot be combined with Where or WhereSql.'
    }
    if (-not $All -and -not $WhereClause.HasPredicate) {
        throw 'Refusing an unscoped mutation. Supply Where, WhereSql, or the explicit All switch.'
    }
    if ($LimitWasBound -and -not $OrderByWasBound) {
        throw 'OrderBy is required when Limit is used for an update or delete.'
    }
    if ($OrderByWasBound -and -not $LimitWasBound) {
        throw 'Limit is required when OrderBy is used for an update or delete.'
    }
    if ($OffsetWasBound -and -not $LimitWasBound) {
        throw 'Limit is required when Offset is used.'
    }
}
