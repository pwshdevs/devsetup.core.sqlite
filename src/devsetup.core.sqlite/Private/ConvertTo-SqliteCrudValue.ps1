function ConvertTo-SqliteCrudValue {
    <#
    .SYNOPSIS
        Normalizes a PowerShell value for a SQLite parameter.
    .DESCRIPTION
        Converts null, DateTime, and Boolean values to stable provider representations.
    .PARAMETER Value
        Value to normalize.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return [System.DBNull]::Value
    }
    if ($Value -is [datetime]) {
        $dateTimeValue = $Value
        if ($dateTimeValue.Kind -ne [System.DateTimeKind]::Unspecified) {
            $dateTimeValue = $dateTimeValue.ToUniversalTime()
        }
        return $dateTimeValue.ToString('yyyy-MM-dd HH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [bool]) {
        return [int]$Value
    }

    $Value
}
