---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# New-SQLiteConnection

## SYNOPSIS
Creates a SQLiteConnection to a SQLite data source

## SYNTAX

```
New-SQLiteConnection [-DataSource] <String[]> [[-Password] <SecureString>] [-ReadOnly]
 [-DateTimeFormat <SQLiteDateFormats>] [-DateTimeKind <DateTimeKind>] [-DateTimeFormatString <String>]
 [[-Open] <Boolean>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates a SQLiteConnection to a SQLite data source

## EXAMPLES

### EXAMPLE 1
```
$Connection = New-SQLiteConnection -DataSource C:\NAMES.SQLite
Invoke-SQLiteQuery -SQLiteConnection $Connection -query $Query
```

Connects to C:\NAMES.SQLite and invokes a query against it.

### EXAMPLE 2
```
$Connection = New-SQLiteConnection -DataSource :MEMORY:
Invoke-SqliteQuery -SQLiteConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
Invoke-SqliteQuery -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
Invoke-SqliteQuery -SQLiteConnection $Connection -Query "PRAGMA STATS"
```

Creates an in-memory SQLite database, adds a table and row, and inspects its statistics.

### EXAMPLE 3
```
$Connection = New-SQLiteConnection -DataSource C:\Events.SQLite `
    -DateTimeFormatString 'yyyy-MM-dd HH:mm:ss.FFF zzz' `
    -DateTimeKind Utc
```

Uses an exact format for a database with a fixed timestamp representation.

## PARAMETERS

### -DataSource
SQLite Data Source to connect to.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Instance, Instances, ServerInstance, Server, Servers, cn, Path, File, FullName, Database

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Password
Specifies A Secure String password to use in the SQLite connection string.

SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ReadOnly
If specified, open SQLite data source as read only

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DateTimeFormat
Controls how System.Data.SQLite parses and serializes DateTime values.
The default is
InvariantCulture, which accepts common SQLite timestamps as well as timestamps containing
a separated UTC offset, such as "2019-07-02 04:59:18.578 +00:00".

```yaml
Type: SQLiteDateFormats
Parameter Sets: (All)
Aliases:
Accepted values: Ticks, ISO8601, Default, JulianDay, UnixEpoch, InvariantCulture, CurrentCulture, Binary

Required: False
Position: Named
Default value: InvariantCulture
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DateTimeKind
Specifies the DateTime kind used by System.Data.SQLite while parsing values.
The default is
Utc so timestamps with offsets preserve the represented instant consistently across hosts.

```yaml
Type: DateTimeKind
Parameter Sets: (All)
Aliases:
Accepted values: Unspecified, Utc, Local

Required: False
Position: Named
Default value: Utc
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DateTimeFormatString
An optional exact .NET DateTime format string for databases with a fixed, non-standard
timestamp representation.
Leave this unset to use the broader DateTimeFormat behavior.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Open
We open the connection by default.
You can use this parameter to create a connection without opening it.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: True
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

## OUTPUTS

### System.Data.SQLite.SQLiteConnection
## NOTES

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

[Invoke-SQLiteQuery]()

