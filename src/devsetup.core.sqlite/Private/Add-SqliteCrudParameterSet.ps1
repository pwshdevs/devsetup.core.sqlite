function Add-SqliteCrudParameterSet {
    <#
    .SYNOPSIS
        Adds a dictionary of normalized values to a SQLite command.
    .DESCRIPTION
        Enumerates a parameter dictionary and binds every entry through Add-SqliteCrudParameter.
    .PARAMETER Command
        SQLite command that receives the parameters.
    .PARAMETER Parameters
        Parameter names and values to bind.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteCommand]$Command,

        [System.Collections.IDictionary]$Parameters
    )

    if ($null -eq $Parameters) {
        return
    }
    foreach ($entry in $Parameters.GetEnumerator()) {
        [void](Add-SqliteCrudParameter -Command $Command -Name ([string]$entry.Key) -Value $entry.Value)
    }
}
