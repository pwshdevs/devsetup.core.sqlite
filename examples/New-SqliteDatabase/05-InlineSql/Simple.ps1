[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'inline-sql-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

New-SqliteDatabase -Path $DatabasePath -Query @'
CREATE TABLE Tasks (
    Id INTEGER PRIMARY KEY,
    Description TEXT NOT NULL,
    Completed INTEGER NOT NULL DEFAULT 0
);
'@

Add-SqliteRow -DataSource $DatabasePath -On Tasks -Data @{
    Id = 1
    Description = 'Run the inline SQL example'
}

Get-SqliteRow -DataSource $DatabasePath -On Tasks
