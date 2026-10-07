[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'inline-json-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schemaJson = @'
{
  "userVersion": 5,
  "tables": [
    {
      "name": "Accounts",
      "strict": true,
      "columns": [
        { "name": "Id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
        { "name": "Email", "type": "TEXT", "nullable": false, "unique": true, "collation": "NOCASE" },
        { "name": "Enabled", "type": "INTEGER", "nullable": false, "default": true },
        { "name": "CreatedAt", "type": "TEXT", "nullable": false, "defaultExpression": "CURRENT_TIMESTAMP" }
      ]
    },
    {
      "name": "ApiTokens",
      "strict": true,
      "columns": [
        { "name": "AccountId", "type": "INTEGER", "nullable": false },
        { "name": "TokenId", "type": "TEXT", "nullable": false },
        { "name": "Label", "type": "TEXT", "nullable": false, "default": "default" },
        { "name": "ExpiresAt", "type": "TEXT" }
      ],
      "primaryKey": ["AccountId", "TokenId"],
      "foreignKeys": [
        {
          "name": "FK_ApiTokens_Accounts",
          "columns": ["AccountId"],
          "references": { "table": "Accounts", "columns": ["Id"] },
          "onDelete": "CASCADE"
        }
      ],
      "indexes": [
        { "name": "IX_ApiTokens_ExpiresAt", "columns": ["ExpiresAt"] }
      ],
      "withoutRowId": true
    }
  ]
}
'@

New-SqliteDatabase -Path $DatabasePath -Schema $schemaJson
Add-SqliteRow -DataSource $DatabasePath -On Accounts -Data @{ Id = 1; Email = 'admin@example.test' }
Add-SqliteRow -DataSource $DatabasePath -On ApiTokens -Data @{
    AccountId = 1
    TokenId = 'deploy-token'
    ExpiresAt = '2027-01-01 00:00:00.000'
}

Get-SqliteRow -DataSource $DatabasePath -On ApiTokens -Where @{ AccountId = 1 }
