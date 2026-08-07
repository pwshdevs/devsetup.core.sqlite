function ConvertTo-SqliteRecord {
    <#
    .SYNOPSIS
        Converts row input to an ordered column dictionary.
    .DESCRIPTION
        Reads a dictionary or object's readable properties and validates that it contains usable column names.
    .PARAMETER InputRecord
        Dictionary or object representing one SQLite row.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputRecord
    )

    if ($null -eq $InputRecord) {
        throw 'SQLite row data cannot be null.'
    }

    $record = [ordered]@{}
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if ($InputRecord -is [System.Collections.IDictionary]) {
        foreach ($key in $InputRecord.Keys) {
            $name = [string]$key
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'SQLite row data contains an empty column name.'
            }
            if (-not $names.Add($name)) {
                throw "SQLite row data contains the column '$name' more than once."
            }
            $record[$name] = $InputRecord[$key]
        }
    } else {
        if ($InputRecord -is [string] -or $InputRecord.GetType().IsValueType) {
            throw 'SQLite row data must be a dictionary or an object with readable properties.'
        }
        foreach ($property in $InputRecord.PSObject.Properties) {
            if (-not $property.IsGettable -or $property.MemberType -eq 'Method') {
                continue
            }
            if (-not $names.Add($property.Name)) {
                throw "SQLite row data contains the column '$($property.Name)' more than once."
            }
            $record[$property.Name] = $property.Value
        }
    }

    if ($record.Count -eq 0) {
        throw 'SQLite row data must contain at least one column.'
    }
    $record
}
