# devsetup.core.sqlite

**Github**

[![GitHub Actions Status][github-actions-badge]][github-actions-build] [![GitHub Actions Status][github-actions-badge-publish]][github-actions-build] [![GitHub Actions Status][github-actions-badge-canary]][github-actions-build] [![GitHub Open Issues Status][github-open-issues-badge]][github-open-issues] [![GitHub Closed Issues Status][github-closed-issues-badge]][github-closed-issues] [![License][license-badge]][license]

**PSGallery**

[![PowerShell Gallery][psgallery-badge]][psgallery] [![PSGallery Version][psgallery-version-badge]][psgallery] [![PSGallery Playform][psgallery-platform-badge]][psgallery] [![PSGallery Playform][ps-desktop-badge]][psgallery]

A cross-platform PowerShell module for querying SQLite databases and efficiently importing data on Windows, Linux, and macOS.

## Features

- Execute SQL from a query string or file.
- Create persistent databases from PowerShell objects, JSON schemas, or SQL.
- Read, insert, update, and delete table rows without writing routine SQL.
- Use parameterized queries and reusable SQLite connections.
- Return results as PowerShell objects, data rows, data tables, data sets, or scalar values.
- Convert PowerShell objects into a `DataTable` and bulk insert them in a transaction.
- Parse common SQLite timestamps using culture-independent UTC defaults.
- Override the provider's date/time format for databases with custom timestamp representations.
- Run natively on supported Windows, Linux, and macOS x64 and ARM architectures.

Version 1.0.0 bundles System.Data.SQLite 2.0.4 and SQLite 3.53.4. Windows PowerShell 5.1 requires .NET Framework 4.7.2 or later; PowerShell 7+ is supported across platforms.

## Installation

Install from the PowerShell Gallery:

```powershell
Install-PSResource -Name devsetup.core.sqlite
```

For Windows PowerShell 5.1:

```powershell
Install-Module -Name devsetup.core.sqlite
```

## Quick start

```powershell
Import-Module devsetup.core.sqlite

$database = Join-Path $PWD 'example.sqlite'

New-SqliteDatabase -Path $database -Schema @{
    UserVersion = 1
    Tables = @(
        @{
            Name = 'Items'
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true }
                @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false }
                @{ Name = 'CreatedAt'; Type = 'TEXT' }
            )
        }
    )
}

Invoke-SqliteQuery -DataSource $database -Query @'
INSERT INTO Items (Id, Name, CreatedAt)
VALUES (@Id, @Name, @CreatedAt);
'@ -SqlParameters @{
    Id = 1
    Name = 'example'
    CreatedAt = [datetime]::UtcNow
}

Invoke-SqliteQuery -DataSource $database -Query 'SELECT * FROM Items'

Add-SqliteRow -DataSource $database -On Items -Data @(
    @{ Id = 2; Name = 'second'; CreatedAt = [datetime]::UtcNow }
    @{ Id = 3; Name = 'third'; CreatedAt = [datetime]::UtcNow }
)

Get-SqliteRow -DataSource $database -On Items -OrderBy Id -Limit 10
```

## Creating databases

`New-SqliteDatabase` never overwrites an existing path, and the parent directory must already exist.
Schema initialization is transactional; a failure removes the incomplete database and its `-journal`,
`-wal`, and `-shm` sidecars. Use `-PassThru` when you want the open connection after creation.

`-Schema` accepts the same model as a hashtable, `PSCustomObject`, or JSON text. Native PowerShell
schemas preserve scalar defaults such as `byte[]`, `DateTime`, and `DateTimeOffset`. `-SchemaPath`
reads the portable form from a `.json` file. The JSON form looks like this:

```json
{
  "userVersion": 1,
  "tables": [
    {
      "name": "Items",
      "strict": true,
      "columns": [
        { "name": "Id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
        { "name": "Name", "type": "TEXT", "nullable": false, "collation": "NOCASE" },
        { "name": "CreatedAt", "type": "TEXT", "defaultExpression": "CURRENT_TIMESTAMP" }
      ],
      "uniqueConstraints": [
        { "name": "UQ_Items_Name", "columns": ["Name"] }
      ],
      "indexes": [
        { "name": "IX_Items_CreatedAt", "columns": ["CreatedAt"] }
      ]
    }
  ]
}
```

At the root, `tables` is required and `userVersion` is optional. A table requires `name` and
`columns`; it can also define a composite `primaryKey`, `uniqueConstraints`, `foreignKeys`, `indexes`,
`strict`, and `withoutRowId`. A column requires `name` and `type`; optional settings are `primaryKey`,
`autoIncrement`, `nullable` (default `$true`), `unique`, `collation`, `default`, and
`defaultExpression`. Default expressions are limited to SQLite's `CURRENT_TIME`, `CURRENT_DATE`, and
`CURRENT_TIMESTAMP`. Foreign-key actions support `NO ACTION`, `RESTRICT`, `SET NULL`, `SET DEFAULT`,
and `CASCADE`. Collection properties are arrays, and names and schema properties are unique without
regard to case.

For database-specific DDL that is not represented by the structured model, use `-Query` or
`-InputFile`.

Runnable [minimal and advanced creation examples](examples/README.md) cover every input mode and are
executed by the repository test suite.

## Commands

| Command | Purpose |
| --- | --- |
| `Add-SqliteRow` | Insert dictionaries or objects with a prepared statement and transaction. |
| `New-SqliteDatabase` | Safely create a database from a PowerShell object, JSON schema, or SQL. |
| `New-SqliteConnection` | Create and optionally open a reusable SQLite connection. |
| `Get-SqliteRow` | Select rows with structured filters, projection, ordering, and paging. |
| `Invoke-SqliteQuery` | Execute SQL and return PowerShell or ADO.NET results. |
| `ConvertTo-SqliteDataTable` | Convert pipeline objects into a `DataTable`. |
| `Invoke-SqliteBulkCopy` | Insert a `DataTable` using a transaction. |
| `Set-SqliteRow` | Update safely scoped rows, including deterministic ordered limits. |
| `Remove-SqliteRow` | Delete safely scoped rows, including deterministic ordered limits. |

Use `Get-Help <command> -Full` for complete command documentation.

## Structured row operations

Use `-Where` for common equality filters. Column names are quoted, values are parameterized, multiple
entries are joined with `AND`, and `$null` becomes `IS NULL`:

```powershell
Set-SqliteRow -DataSource $database -On Items `
    -Values @{ Name = 'renamed' } `
    -Where @{ Id = 2 }

Remove-SqliteRow -DataSource $database -On Items `
    -Where @{ Id = 3 } `
    -Confirm:$false
```

`Set-SqliteRow` and `Remove-SqliteRow` refuse an empty filter. Use `-All` when the broad scope is
intentional. A limited mutation also requires `-OrderBy`, giving it deterministic behavior on normal
rowid tables and tables with single or composite primary keys, including `WITHOUT ROWID` tables.

For predicates beyond equality, use `-WhereSql` with `-SqlParameters`. The original
`Invoke-SqliteQuery` remains available for arbitrary SQL.

## Date and time behavior

Connections created by `New-SqliteConnection` and `Invoke-SqliteQuery` default to `InvariantCulture` parsing and UTC normalization. This supports common SQLite timestamps, including offset values such as `2019-07-02 04:59:18.578 +00:00`.

For a fixed custom representation, supply an exact .NET format string:

```powershell
$connection = New-SqliteConnection -DataSource $database `
    -DateTimeFormatString 'yyyy-MM-dd HH:mm:ss.FFF zzz' `
    -DateTimeKind Utc
```

## Supported runtimes

PowerShell 7 uses bundled runtime-specific assets for:

- Windows x86, x64, and ARM64
- Linux x64, ARM, and ARM64
- macOS x64 and ARM64

Windows PowerShell 5.1 uses the bundled Windows x86 or x64 .NET Framework provider.

## Development

This repository uses the Lath project layout. Module source is under `src/devsetup.core.sqlite`; build, test, documentation, and CI files live at the project root.

Bootstrap the pinned development dependencies and run the complete build:

```powershell
./build.ps1 -Task Test -Bootstrap
```

The DBNull conversion helper is a committed, architecture-neutral .NET Standard 2.0 assembly. Rebuild it only when its C# source changes:

```powershell
dotnet build ./src/devsetup.core.sqlite.Support/devsetup.core.sqlite.Support.csproj -c Release
```

The project build copies the helper to `src/devsetup.core.sqlite/lib`. The same managed DLL is used by Windows PowerShell 5.1 and PowerShell 7 on every supported operating system and architecture.

Bundled SQLite versions are pinned in `tools/SQLiteDependencies.psd1`. Maintainers can refresh one runtime or every runtime from a single NuGet download:

```powershell
./tools/Update-SqliteRuntime.ps1 -All
```

The scheduled dependency canary uses the shared `PSDependencyCanary` task to
baseline-test the committed build, stage newer PowerShell dependencies, bootstrap
the candidate, and run the same test task again. Build-only updates change only
`requirements.psd1`; runtime dependency updates also patch-bump the module and
update its changelog. Bundled SQLite runtime refreshes remain an explicit
maintainer operation through `Update-SqliteRuntime.ps1`.

PlatyPS source documentation is stored under `docs/en-US`. GitHub Actions validates PowerShell 7 on Windows, Linux, and macOS, plus Windows PowerShell 5.1.

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

devsetup.core.sqlite is available under the [MIT License](LICENSE).

[github-actions-badge]: https://img.shields.io/github/actions/workflow/status/pwshdevs/devsetup.core.sqlite/test.yml?label=build&style=for-the-badge
[github-actions-badge-publish]: https://img.shields.io/github/actions/workflow/status/pwshdevs/devsetup.core.sqlite/publish.yml?label=publish&style=for-the-badge
[github-actions-badge-canary]: https://img.shields.io/github/actions/workflow/status/pwshdevs/devsetup.core.sqlite/canary.yml?label=canary&style=for-the-badge
[github-actions-build]: https://github.com/pwshdevs/devsetup.core.sqlite/actions
[psgallery-badge]: https://img.shields.io/powershellgallery/dt/devsetup.core.sqlite?label=downloads&style=for-the-badge
[psgallery]: https://www.powershellgallery.com/packages/devsetup.core.sqlite
[psgallery-version-badge]: https://img.shields.io/powershellgallery/v/devsetup.core.sqlite?label=version&style=for-the-badge
[license-badge]: https://img.shields.io/github/license/pwshdevs/devsetup.core.sqlite?style=for-the-badge
[license]: https://raw.githubusercontent.com/pwshdevs/devsetup.core.sqlite/main/LICENSE
[github-open-issues-badge]: https://img.shields.io/github/issues/pwshdevs/devsetup.core.sqlite?style=for-the-badge
[github-closed-issues-badge]: https://img.shields.io/github/issues-closed/pwshdevs/devsetup.core.sqlite?style=for-the-badge
[github-closed-issues]: https://github.com/pwshdevs/devsetup.core.sqlite/issues?q=is%3Aissue%20state%3Aclosed
[github-open-issues]: https://github.com/pwshdevs/devsetup.core.sqlite/issues
[psgallery-platform-badge]: https://img.shields.io/powershellgallery/p/devsetup.core.sqlite?style=for-the-badge
[ps-desktop-badge]: https://img.shields.io/badge/powershell-5.1,_7.0+-blue?style=for-the-badge
[ps-core-badge]: https://img.shields.io/badge/powershell-5.1,_7.0+-blue?style=for-the-badge
