---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# Invoke-SqliteQuery

## SYNOPSIS
Runs a SQL script against a SQLite database.

## SYNTAX

### Src-Que (Default)
```
Invoke-SqliteQuery [-DataSource] <String[]> [-Query] <String> [[-QueryTimeout] <Int32>] [[-As] <String>]
 [[-SqlParameters] <IDictionary>] [-AppendDataSource] [[-AssemblyPath] <String>]
 [-DateTimeFormat <SQLiteDateFormats>] [-DateTimeKind <DateTimeKind>] [-DateTimeFormatString <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Src-Fil
```
Invoke-SqliteQuery [-DataSource] <String[]> [-InputFile] <String> [[-QueryTimeout] <Int32>] [[-As] <String>]
 [[-SqlParameters] <IDictionary>] [-AppendDataSource] [[-AssemblyPath] <String>]
 [-DateTimeFormat <SQLiteDateFormats>] [-DateTimeKind <DateTimeKind>] [-DateTimeFormatString <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Con-Que
```
Invoke-SqliteQuery [-Query] <String> [[-QueryTimeout] <Int32>] [[-As] <String>]
 [[-SqlParameters] <IDictionary>] [-AppendDataSource] [[-AssemblyPath] <String>]
 [-SQLiteConnection] <SQLiteConnection> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Con-Fil
```
Invoke-SqliteQuery [-InputFile] <String> [[-QueryTimeout] <Int32>] [[-As] <String>]
 [[-SqlParameters] <IDictionary>] [-AppendDataSource] [[-AssemblyPath] <String>]
 [-SQLiteConnection] <SQLiteConnection> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Runs a SQL script against a SQLite database.

Paramaterized queries are supported.

Help details below borrowed from Invoke-Sqlcmd, may be inaccurate here.

## EXAMPLES

### EXAMPLE 1
```
Invoke-SqliteQuery -DataSource C:\Names.sqlite -Query 'SELECT * FROM Names'
```

Runs a query against a SQLite database and returns PowerShell objects.

### EXAMPLE 2
```
$parameters = @{ FullName = 'Cookie Monster' }
Invoke-SqliteQuery -DataSource C:\Names.sqlite -Query 'SELECT * FROM Names WHERE FullName = @FullName' -SqlParameters $parameters
```

Runs a parameterized query.

### EXAMPLE 3
```
Invoke-SqliteQuery -DataSource C:\Names.sqlite -InputFile C:\Query.sql
```

Reads and executes SQL from a file.

### EXAMPLE 4
```
$connection = New-SQLiteConnection -DataSource :MEMORY:
Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE Names (FullName TEXT)'
```

Executes a query using an existing SQLite connection.

## PARAMETERS

### -DataSource
Path to one or more SQLite data sources to query

```yaml
Type: String[]
Parameter Sets: Src-Que, Src-Fil
Aliases: Path, File, FullName, Database

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Query
Specifies a query to be run.

```yaml
Type: String
Parameter Sets: Src-Que, Con-Que
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InputFile
Specifies a file to be used as the query input to Invoke-SqliteQuery.
Specify the full path to the file.

```yaml
Type: String
Parameter Sets: Src-Fil, Con-Fil
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -QueryTimeout
Specifies the number of seconds before the queries time out.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 600
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -As
Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value

PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: PSObject
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SqlParameters
Hashtable of parameters for parameterized SQL queries.
http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

Limited support for conversions to SQLite friendly formats is supported.
    For example, if you pass in a .NET DateTime, we convert it to a string that SQLite will recognize as a datetime

Example:
    -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
    -SqlParameters @{"ServerName = "c-is-hyperv-1"}

```yaml
Type: IDictionary
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AppendDataSource
If specified, append the SQLite data source path to PSObject or DataRow output

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AssemblyPath
Retained for compatibility with earlier versions.
The module automatically loads the bundled provider assembly.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: $SQLiteAssembly
Accept pipeline input: False
Accept wildcard characters: False
```

### -DateTimeFormat
Controls how System.Data.SQLite parses and serializes DateTime values when DataSource is
used.
The default is InvariantCulture, which supports common SQLite timestamp forms and
timestamps containing a separated UTC offset.

```yaml
Type: SQLiteDateFormats
Parameter Sets: Src-Que, Src-Fil
Aliases:
Accepted values: Ticks, ISO8601, Default, JulianDay, UnixEpoch, InvariantCulture, CurrentCulture, Binary

Required: False
Position: Named
Default value: InvariantCulture
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DateTimeKind
Specifies the DateTime kind used while parsing values when DataSource is used.
The default
is Utc.
Configure an existing SQLiteConnection directly when using SQLiteConnection.

```yaml
Type: DateTimeKind
Parameter Sets: Src-Que, Src-Fil
Aliases:
Accepted values: Unspecified, Utc, Local

Required: False
Position: Named
Default value: Utc
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DateTimeFormatString
An optional exact .NET DateTime format string for databases with a fixed timestamp
representation.
This parameter is available with the DataSource parameter sets.

```yaml
Type: String
Parameter Sets: Src-Que, Src-Fil
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SQLiteConnection
An existing SQLiteConnection to use.
We do not close this connection upon completed query.

```yaml
Type: SQLiteConnection
Parameter Sets: Con-Que, Con-Fil
Aliases: Connection, Conn

Required: True
Position: 8
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### DataSource
### You can pipe DataSource paths to Invoke-SQLiteQuery.  The query will execute against each Data Source.
## OUTPUTS

### As PSObject:     System.Management.Automation.PSCustomObject
### As DataRow:      System.Data.DataRow
### As DataTable:    System.Data.DataTable
### As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
### As SingleValue:  Dependent on data type in first column.
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

[New-SQLiteConnection]()

[Invoke-SQLiteBulkCopy]()

[ConvertTo-SqliteDataTable]()

[https://www.sqlite.org/datatype3.html](https://www.sqlite.org/datatype3.html)

[https://www.sqlite.org/lang.html](https://www.sqlite.org/lang.html)

[http://www.sqlite.org/pragma.html](http://www.sqlite.org/pragma.html)

