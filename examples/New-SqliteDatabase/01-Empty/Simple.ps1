[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'empty-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

New-SqliteDatabase -Path $DatabasePath

Get-Item -LiteralPath $DatabasePath
