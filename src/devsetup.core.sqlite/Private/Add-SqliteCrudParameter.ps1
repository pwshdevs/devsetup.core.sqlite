function Add-SqliteCrudParameter {
    <#
    .SYNOPSIS
        Adds one normalized value to a SQLite command.
    .DESCRIPTION
        Creates a provider parameter, converts its value to a SQLite-friendly representation, and adds it to the command.
    .PARAMETER Command
        SQLite command that receives the parameter.
    .PARAMETER Name
        Parameter placeholder name.
    .PARAMETER Value
        Value to normalize and bind.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteCommand]$Command,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    $parameter = $Command.CreateParameter()
    $parameter.ParameterName = $Name
    $parameter.Value = ConvertTo-SqliteCrudValue -Value $Value
    [void]$Command.Parameters.Add($parameter)
    $parameter
}
