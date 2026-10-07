[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'inline-json-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schemaJson = @'
{
  "tables": [
    {
      "name": "Notes",
      "columns": [
        { "name": "Id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
        { "name": "Body", "type": "TEXT", "nullable": false }
      ]
    }
  ]
}
'@

New-SqliteDatabase -Path $DatabasePath -Schema $schemaJson
Add-SqliteRow -DataSource $DatabasePath -On Notes -Data @{ Body = 'Created from inline JSON.' }

Get-SqliteRow -DataSource $DatabasePath -On Notes
