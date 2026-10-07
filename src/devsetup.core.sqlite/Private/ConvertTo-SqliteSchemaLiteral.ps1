function ConvertTo-SqliteSchemaLiteral {
    <#
    .SYNOPSIS
        Converts a schema default value to a SQLite literal.
    .DESCRIPTION
        Formats null, Boolean, numeric, binary, date/time, and text values as safe SQLite literals
        for use while generating CREATE TABLE statements.
    .PARAMETER Value
        Value to convert to a SQLite literal.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return 'NULL'
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { '1' } else { '0' })
    }
    if ($Value -is [byte[]]) {
        return "X'$([System.BitConverter]::ToString($Value).Replace('-', ''))'"
    }
    if ($Value -is [datetime]) {
        $dateTimeValue = $Value
        if ($dateTimeValue.Kind -ne [System.DateTimeKind]::Unspecified) {
            $dateTimeValue = $dateTimeValue.ToUniversalTime()
        }
        $Value = $dateTimeValue.ToString(
            'yyyy-MM-dd HH:mm:ss.fff',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } elseif ($Value -is [datetimeoffset]) {
        $Value = $Value.ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    } elseif (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64] -or
        $Value -is [decimal]
    ) {
        return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    } elseif ($Value -is [double] -or $Value -is [single]) {
        if ([double]::IsNaN([double]$Value) -or [double]::IsInfinity([double]$Value)) {
            throw 'NaN and infinity cannot be used as SQLite schema defaults.'
        }
        return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    } elseif (
        $Value -is [System.Collections.IDictionary] -or
        $Value -is [pscustomobject] -or
        ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
    ) {
        throw 'SQLite schema defaults must be scalar values.'
    }

    "'$(([string]$Value).Replace("'", "''"))'"
}
