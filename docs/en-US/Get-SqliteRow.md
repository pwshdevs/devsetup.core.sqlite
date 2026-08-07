---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# Get-SqliteRow

## SYNOPSIS
Reads rows from a SQLite table without requiring handwritten SELECT SQL.

## SYNTAX

### DataSource (Default)
```
Get-SqliteRow [-DataSource] <String> [-Table] <String> [-Column <String[]>] [-Where <IDictionary>]
 [-WhereSql <String>] [-SqlParameters <IDictionary>] [-OrderBy <String[]>] [-Descending] [-Limit <Int32>]
 [-Offset <Int32>] [-QueryTimeout <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Connection
```
Get-SqliteRow [-SQLiteConnection] <SQLiteConnection> [-Table] <String> [-Column <String[]>]
 [-Where <IDictionary>] [-WhereSql <String>] [-SqlParameters <IDictionary>] [-OrderBy <String[]>] [-Descending]
 [-Limit <Int32>] [-Offset <Int32>] [-QueryTimeout <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Builds a parameterized SELECT statement from table, column, filter, ordering, and paging
arguments.
Table and column names are quoted as SQLite identifiers.
Use Where for simple
equality filters or WhereSql with SqlParameters for advanced predicates.

## EXAMPLES

### EXAMPLE 1
```
Get-SqliteRow -DataSource ./app.sqlite -On Users -Where @{ Active = $true } -OrderBy Name -Limit 20
```

Returns the first 20 active users ordered by name.

### EXAMPLE 2
```
= @since' -SqlParameters @{ since = $cutoff }
```

Uses a parameterized custom predicate for an advanced filter.

## PARAMETERS

### -DataSource
Path to the SQLite database file, or :MEMORY: for an in-memory database.

```yaml
Type: String
Parameter Sets: DataSource
Aliases: Path, File, Database

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SQLiteConnection
An existing SQLite connection.
The command opens it if needed and never closes it.

```yaml
Type: SQLiteConnection
Parameter Sets: Connection
Aliases: Connection, Conn

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Table
Name of the table to read.
On is an alias for this parameter.

```yaml
Type: String
Parameter Sets: (All)
Aliases: On

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Column
Column names to return.
The default is all columns.
Columns is an alias.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Columns

Required: False
Position: Named
Default value: @('*')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Where
Dictionary of column/value equality filters joined with AND.
A null value generates IS NULL.

```yaml
Type: IDictionary
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhereSql
Advanced SQL predicate without the WHERE keyword.
Values should be supplied through SqlParameters.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SqlParameters
Dictionary of values used by placeholders in WhereSql.

```yaml
Type: IDictionary
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrderBy
One or more column names used to order the result.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Descending
Sorts every OrderBy column in descending order.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
Maximum number of rows to return.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Offset
Number of ordered rows to skip.
Limit is required when Offset is used.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -QueryTimeout
Number of seconds before the query times out.
The default is 600.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 600
Accept pipeline input: False
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

## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

