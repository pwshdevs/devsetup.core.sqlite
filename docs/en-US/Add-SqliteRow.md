---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# Add-SqliteRow

## SYNOPSIS
Inserts one or more rows into a SQLite table.

## SYNTAX

### DataSource (Default)
```
Add-SqliteRow [-DataSource] <String> [-Table] <String> [-Data] <Object[]> [-ConflictAction <String>]
 [-QueryTimeout <Int32>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### Connection
```
Add-SqliteRow [-SQLiteConnection] <SQLiteConnection> [-Table] <String> [-Data] <Object[]>
 [-ConflictAction <String>] [-QueryTimeout <Int32>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Inserts dictionaries or PowerShell objects with one prepared statement and one transaction.
The union of all supplied property names becomes the insert column list; a property missing
from a row is inserted as NULL.
Identifiers are quoted and values are always parameterized.

## EXAMPLES

### EXAMPLE 1
```
Add-SqliteRow -DataSource ./app.sqlite -On Users -Data @(@{ Name = 'Ada' }, @{ Name = 'Grace' })
```

Inserts two rows in a single transaction.

### EXAMPLE 2
```
Import-Csv ./users.csv | Add-SqliteRow -DataSource ./app.sqlite -Table Users
```

Inserts objects received from the pipeline.

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
Name of the table receiving the rows.
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

### -Data
Dictionaries or objects containing column names and values.
Data accepts pipeline input.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases: InputObject

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ConflictAction
SQLite conflict action used by the INSERT statement.
The default is Abort.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Abort
Accept pipeline input: False
Accept wildcard characters: False
```

### -QueryTimeout
Number of seconds before an insert times out.
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
Returns each input row that SQLite reports as inserted.

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

### System.Object
## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

