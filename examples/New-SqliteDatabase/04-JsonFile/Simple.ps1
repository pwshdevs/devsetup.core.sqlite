[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'json-file-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schemaPath = Join-Path $PSScriptRoot 'Simple.schema.json'
New-SqliteDatabase -Path $DatabasePath -SchemaPath $schemaPath
Add-SqliteRow -DataSource $DatabasePath -On Customers -Data @{ Name = 'Ada Lovelace' }

Get-SqliteRow -DataSource $DatabasePath -On Customers
