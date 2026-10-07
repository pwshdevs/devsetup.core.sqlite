# devsetup.core.sqlite examples

These examples cover every `New-SqliteDatabase` creation mode in both minimal and advanced forms.
Every script accepts `-DatabasePath`, creates a new database without overwriting an existing path,
and can be run directly after importing the module:

```powershell
Import-Module devsetup.core.sqlite
./examples/New-SqliteDatabase/02-PowerShellSchema/Simple.ps1 -DatabasePath ./books.sqlite
```

The default output path is beside each script. Remove that example database or pass a new path before
running the same example again; `New-SqliteDatabase` intentionally refuses to overwrite it.

| Creation mode | Minimal example | Advanced example |
| --- | --- | --- |
| Empty database | [Simple.ps1](New-SqliteDatabase/01-Empty/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/01-Empty/Advanced.ps1) |
| PowerShell schema object | [Simple.ps1](New-SqliteDatabase/02-PowerShellSchema/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/02-PowerShellSchema/Advanced.ps1) |
| Inline JSON schema | [Simple.ps1](New-SqliteDatabase/03-InlineJson/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/03-InlineJson/Advanced.ps1) |
| JSON schema file | [Simple.ps1](New-SqliteDatabase/04-JsonFile/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/04-JsonFile/Advanced.ps1) |
| Inline SQL | [Simple.ps1](New-SqliteDatabase/05-InlineSql/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/05-InlineSql/Advanced.ps1) |
| SQL file | [Simple.ps1](New-SqliteDatabase/06-SqlFile/Simple.ps1) | [Advanced.ps1](New-SqliteDatabase/06-SqlFile/Advanced.ps1) |

Use a structured PowerShell or JSON schema for portable routine DDL. Use SQL when you need SQLite
features outside the structured model, such as views, triggers, expression indexes, or check
constraints. The empty form is useful when another component owns migrations or initialization.

The repository test suite executes every script against a fresh temporary path and verifies the
result with SQLite's `PRAGMA integrity_check`.
