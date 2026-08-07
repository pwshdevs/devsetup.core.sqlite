function ConvertTo-SqliteQuotedIdentifier {
    <#
    .SYNOPSIS
        Quotes one SQLite identifier safely.
    .DESCRIPTION
        Validates an identifier and escapes embedded double quotes using SQLite identifier rules.
    .PARAMETER Name
        Identifier to quote.
    .PARAMETER AllowWildcard
        Leaves a single asterisk unquoted for SELECT projections.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$AllowWildcard
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'SQLite identifiers cannot be empty.'
    }
    if ($Name.IndexOf([char]0) -ge 0) {
        throw 'SQLite identifiers cannot contain a null character.'
    }
    if ($AllowWildcard -and $Name -eq '*') {
        return '*'
    }

    '"{0}"' -f $Name.Replace('"', '""')
}
