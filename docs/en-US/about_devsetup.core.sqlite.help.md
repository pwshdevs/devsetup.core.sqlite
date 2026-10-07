# devsetup.core.sqlite

## about_devsetup.core.sqlite

# SHORT DESCRIPTION

Query SQLite databases and efficiently import data from PowerShell.

# LONG DESCRIPTION

devsetup.core.sqlite is a cross-platform PowerShell module built on
System.Data.SQLite. It bundles managed and native SQLite runtime assets for
supported Windows, Linux, and macOS architectures.

The module can explicitly create persistent databases from structured schemas or SQL,
create reusable SQLite connections, execute parameterized SQL,
return several PowerShell and ADO.NET output shapes, manage rows through safe
high-level commands, and insert DataTable rows inside a transaction.

Structured row operations quote identifiers and parameterize values. Updates
and deletes require a filter or the explicit `-All` switch. Arbitrary SQL
remains available through Invoke-SqliteQuery.

Connections use culture-independent date/time parsing and normalize
offset-aware values to UTC by default. Provider date/time behavior can be
customized for databases that use fixed or non-standard timestamp formats.

# EXAMPLES

Create a database and query it:

```powershell
$database = Join-Path $PWD 'example.sqlite'
New-SqliteDatabase -Path $database -Schema @{
    Tables = @(
        @{
            Name = 'Items'
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true }
                @{ Name = 'Name'; Type = 'TEXT' }
            )
        }
    )
}

Invoke-SqliteQuery -DataSource $database -Query @'
INSERT INTO Items (Id, Name) VALUES (@Id, @Name);
'@ -SqlParameters @{ Id = 1; Name = 'example' }

Invoke-SqliteQuery -DataSource $database -Query 'SELECT * FROM Items'
```

Insert and safely update rows without writing routine SQL:

```powershell
Add-SqliteRow -DataSource $database -On Items -Data @{ Id = 2; Name = 'second' }
Get-SqliteRow -DataSource $database -On Items -Where @{ Id = 2 }
Set-SqliteRow -DataSource $database -On Items -Values @{ Name = 'renamed' } -Where @{ Id = 2 }
```

# NOTE

SQLite uses dynamic typing and does not have a native DateTime storage class.
The declared column type and connection date/time settings determine how the
provider materializes stored values.

# SEE ALSO

- New-SqliteConnection
- New-SqliteDatabase
- Add-SqliteRow
- Get-SqliteRow
- Invoke-SqliteQuery
- Invoke-SqliteBulkCopy
- Set-SqliteRow
- Remove-SqliteRow
- ConvertTo-SqliteDataTable

# KEYWORDS

- SQLite
- SQL
- database
- PowerShell
