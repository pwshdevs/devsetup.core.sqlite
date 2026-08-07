function ConvertTo-SqliteUserParameterMap {
    <#
    .SYNOPSIS
        Normalizes custom predicate parameter names.
    .DESCRIPTION
        Validates user parameter names, adds the SQLite marker, and protects names reserved by the CRUD builder.
    .PARAMETER SqlParameters
        User-provided parameter names and values.
    #>
    [CmdletBinding()]
    param([System.Collections.IDictionary]$SqlParameters)

    $result = [ordered]@{}
    if ($null -eq $SqlParameters) {
        return $result
    }

    foreach ($entry in $SqlParameters.GetEnumerator()) {
        $name = ([string]$entry.Key).TrimStart('@', ':', '$')
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "'$($entry.Key)' is not a supported SQLite parameter name."
        }
        if ($name.StartsWith('__crud_', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "SQLite parameter names beginning with '__crud_' are reserved by this module."
        }

        $parameterName = '@{0}' -f $name
        if ($result.Contains($parameterName)) {
            throw "SQLite parameter '$parameterName' was supplied more than once."
        }
        $result[$parameterName] = $entry.Value
    }
    $result
}
