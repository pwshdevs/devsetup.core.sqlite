function Get-SqliteDataColumnType {
    <#
    .SYNOPSIS
        Selects a supported DataColumn type for a PowerShell property.
    .DESCRIPTION
        Preserves common scalar .NET types and maps other property types to System.String.
    .PARAMETER Type
        Fully qualified .NET type name to inspect.
    #>
    [CmdletBinding()]
    param([string]$Type)

    $types = @(
        'System.Boolean', 'System.Byte[]', 'System.Byte', 'System.Char', 'System.Datetime',
        'System.Decimal', 'System.Double', 'System.Guid', 'System.Int16', 'System.Int32',
        'System.Int64', 'System.Single', 'System.UInt16', 'System.UInt32', 'System.UInt64'
    )
    if ($types -contains $Type) {
        $Type
    } else {
        'System.String'
    }
}
