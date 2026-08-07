---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# Set-SqliteRow

## SYNOPSIS
Updates rows in a SQLite table without requiring handwritten UPDATE SQL.

## SYNTAX

### DataSource (Default)
```
Set-SqliteRow [-DataSource] <String> [-Table] <String> [-Values] <Object> [-Where <IDictionary>]
 [-WhereSql <String>] [-SqlParameters <IDictionary>] [-All] [-OrderBy <String[]>] [-Descending]
 [-Limit <Int32>] [-Offset <Int32>] [-QueryTimeout <Int32>] [-PassThru] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Connection
```
Set-SqliteRow [-SQLiteConnection] <SQLiteConnection> [-Table] <String> [-Values] <Object>
 [-Where <IDictionary>] [-WhereSql <String>] [-SqlParameters <IDictionary>] [-All] [-OrderBy <String[]>]
 [-Descending] [-Limit <Int32>] [-Offset <Int32>] [-QueryTimeout <Int32>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Builds a parameterized UPDATE statement from a dictionary or object.
An update must have a
non-empty Where/WhereSql predicate unless All is explicitly supplied.
Ordered limited updates
are implemented portably through the table primary key or rowid.

## EXAMPLES

### EXAMPLE 1
```
Set-SqliteRow -DataSource ./app.sqlite -On Users -Values @{ Active = $false } -Where @{ Id = 42 }
```

Deactivates the user with Id 42.

### EXAMPLE 2
```
Set-SqliteRow -DataSource ./jobs.sqlite -Table Jobs -Values @{ State = 'Queued' } -All -OrderBy CreatedAt -Limit 10
```

Updates the ten oldest jobs after explicitly allowing an unfiltered operation.

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
Name of the table to update.
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

### -Values
Dictionary or object containing the columns and new values.
Data and Set are aliases.

```yaml
Type: Object
Parameter Sets: (All)
Aliases: Data, Set

Required: True
Position: 3
Default value: None
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

### -All
Explicitly permits an update without a filter.

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

### -OrderBy
Columns used to select rows deterministically for a limited update.
Limit is required.

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
Maximum number of ordered rows to update.
OrderBy is required.

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
Number of ordered rows to skip before updating.
Limit is required.

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
Number of seconds before the update times out.
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

### -PassThru
Returns the number of rows updated.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
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

### System.Int32
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

