function Close-SqliteBulkCopyResource {
    <#
    .SYNOPSIS
        Disposes resources created by a SQLite bulk copy.
    .DESCRIPTION
        Disposes the transaction and command, and disposes the connection only when the command created it.
    .PARAMETER Connection
        SQLite connection used by the bulk copy.
    .PARAMETER Command
        SQLite command used by the bulk copy.
    .PARAMETER Transaction
        SQLite transaction used by the bulk copy.
    .PARAMETER BoundParameters
        Calling command's bound parameters, used to determine connection ownership.
    #>
    [CmdletBinding()]
    param(
        [System.Data.SQLite.SQLiteConnection]$Connection,
        [System.Data.SQLite.SQLiteCommand]$Command,
        [System.Data.SQLite.SQLiteTransaction]$Transaction,
        [System.Collections.IDictionary]$BoundParameters
    )

    if ($null -ne $Transaction) {
        $Transaction.Dispose()
    }
    if ($null -ne $Command) {
        $Command.Dispose()
    }
    if ($BoundParameters.Keys -notcontains 'SQLiteConnection') {
        $Connection.Close()
        $Connection.Dispose()
        Write-Verbose 'Closed connection'
    }
}
