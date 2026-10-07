[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'json-file-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schemaPath = Join-Path $PSScriptRoot 'Advanced.schema.json'
New-SqliteDatabase -Path $DatabasePath -SchemaPath $schemaPath

Add-SqliteRow -DataSource $DatabasePath -On Warehouses -Data @{ Id = 1; Name = 'Central' }
Add-SqliteRow -DataSource $DatabasePath -On Products -Data @{ Sku = 'SQLITE-001'; DisplayName = 'SQLite Toolkit' }
Add-SqliteRow -DataSource $DatabasePath -On Inventory -Data @{
    WarehouseId = 1
    Sku = 'SQLITE-001'
    Quantity = 25
}

Get-SqliteRow -DataSource $DatabasePath -On Inventory -Where @{ WarehouseId = 1 }
