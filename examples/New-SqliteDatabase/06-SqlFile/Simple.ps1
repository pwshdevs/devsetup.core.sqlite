[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'sql-file-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$sqlPath = Join-Path $PSScriptRoot 'Simple.schema.sql'
New-SqliteDatabase -Path $DatabasePath -InputFile $sqlPath
Add-SqliteRow -DataSource $DatabasePath -On Events -Data @{ Id = 1; Message = 'Database initialized from a SQL file.' }

Get-SqliteRow -DataSource $DatabasePath -On Events
