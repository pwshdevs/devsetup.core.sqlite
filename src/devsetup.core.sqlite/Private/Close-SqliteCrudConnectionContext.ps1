function Close-SqliteCrudConnectionContext {
    <#
    .SYNOPSIS
        Disposes a module-owned CRUD connection.
    .DESCRIPTION
        Disposes the connection only when the context says it was created by the current command.
    .PARAMETER Context
        Connection ownership context returned by Get-SqliteCrudConnectionContext.
    #>
    [CmdletBinding()]
    param([AllowNull()][psobject]$Context)

    if ($null -ne $Context -and $Context.OwnsConnection -and $null -ne $Context.Connection) {
        $Context.Connection.Dispose()
    }
}
