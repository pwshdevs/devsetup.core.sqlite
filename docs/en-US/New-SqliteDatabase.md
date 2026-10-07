---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# New-SqliteDatabase

## SYNOPSIS
Creates and optionally initializes a persistent SQLite database.

## SYNTAX

### Empty (Default)
```
New-SqliteDatabase [-Path] <String> [-QueryTimeout <Int32>] [-PassThru] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Schema
```
New-SqliteDatabase [-Path] <String> -Schema <Object> [-QueryTimeout <Int32>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### SchemaFile
```
New-SqliteDatabase [-Path] <String> -SchemaPath <String> [-QueryTimeout <Int32>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Query
```
New-SqliteDatabase [-Path] <String> -Query <String> [-QueryTimeout <Int32>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### QueryFile
```
New-SqliteDatabase [-Path] <String> -InputFile <String> [-QueryTimeout <Int32>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Creates a new SQLite database file without overwriting an existing path.
The database can
be initialized from a structured PowerShell or JSON schema, a JSON schema file, inline SQL, or
a SQL file.
Initialization runs in one transaction.
If it fails, the incomplete database and
its SQLite sidecar files are removed.

Structured schemas support tables, columns, literal defaults, primary and unique keys,
foreign keys, indexes, STRICT tables, WITHOUT ROWID tables, and PRAGMA user_version.

## EXAMPLES

### EXAMPLE 1
```
New-SqliteDatabase -Path ./inventory.sqlite
```

Creates an empty, valid SQLite database without replacing an existing file.

### EXAMPLE 2
```
New-SqliteDatabase -Path ./inventory.sqlite -Schema @{
    UserVersion = 1
    Tables = @(
        @{
            Name = 'Items'
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false }
                @{ Name = 'CreatedAt'; Type = 'TEXT'; DefaultExpression = 'CURRENT_TIMESTAMP' }
            )
            Indexes = @(
                @{ Name = 'IX_Items_Name'; Columns = @('Name'); Unique = $true }
            )
        }
    )
}
```

Creates and initializes a database from a native PowerShell schema object.

### EXAMPLE 3
```
New-SqliteDatabase -Path ./inventory.sqlite -SchemaPath ./schema.json
```

Creates and initializes a database from a portable JSON schema document.

### EXAMPLE 4
```
$connection = New-SqliteDatabase -Path ./inventory.sqlite -InputFile ./schema.sql -PassThru
try {
    Get-SqliteRow -SQLiteConnection $connection -On Items
} finally {
    $connection.Dispose()
}
```

Initializes a database with raw SQL and returns its open connection for reuse.

## PARAMETERS

### -Path
Path of the new persistent SQLite database.
The parent directory must already exist.

```yaml
Type: String
Parameter Sets: (All)
Aliases: DataSource, Database, File, FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Schema
Hashtable, PSCustomObject, or JSON text describing the database schema.
Native PowerShell schema objects preserve scalar Default values such as byte arrays, DateTime, and
DateTimeOffset. The root requires a Tables array and accepts an optional non-negative 32-bit integer
UserVersion.

```yaml
Type: Object
Parameter Sets: Schema
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SchemaPath
Path to a JSON file containing the structured database schema.

```yaml
Type: String
Parameter Sets: SchemaFile
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Query
SQL used to initialize the database.
Use Schema for safely generated routine DDL.

```yaml
Type: String
Parameter Sets: Query
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputFile
Path to a SQL file used to initialize the database.

```yaml
Type: String
Parameter Sets: QueryFile
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -QueryTimeout
Number of seconds to wait for each initialization command.
The default is 600 seconds.
Specify zero to use the provider's unlimited timeout behavior.

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
Returns the open SQLiteConnection.
The caller is responsible for disposing it.
Without this
switch, the command closes the connection and returns no output.

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

### System.Data.SQLite.SQLiteConnection when PassThru is specified. Otherwise, no output.
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

