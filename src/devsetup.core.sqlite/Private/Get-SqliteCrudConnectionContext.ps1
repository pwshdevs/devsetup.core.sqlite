function Get-SqliteCrudConnectionContext {
    <#
    .SYNOPSIS
        Gets an open SQLite connection and records its ownership.
    .DESCRIPTION
        Opens a supplied connection without taking ownership, or creates a module-owned connection from a data source.
    .PARAMETER DataSource
        SQLite database path used when no connection is supplied.
    .PARAMETER SQLiteConnection
        Existing SQLite connection to reuse.
    #>
    [CmdletBinding()]
    param(
        [string]$DataSource,

        [System.Data.SQLite.SQLiteConnection]$SQLiteConnection
    )

    if ($null -ne $SQLiteConnection) {
        if ($SQLiteConnection.State -eq [System.Data.ConnectionState]::Closed) {
            $SQLiteConnection.Open()
        }
        return [pscustomobject]@{
            Connection = $SQLiteConnection
            OwnsConnection = $false
        }
    }

    $connection = New-SQLiteConnection -DataSource $DataSource
    if ($null -eq $connection) {
        throw "Unable to open SQLite data source '$DataSource'."
    }
    [pscustomobject]@{
        Connection = $connection
        OwnsConnection = $true
    }
}
