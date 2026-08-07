---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# Invoke-SQLiteBulkCopy

## SYNOPSIS
Use a SQLite transaction to quickly insert data

## SYNTAX

### Datasource (Default)
```
Invoke-SQLiteBulkCopy [-DataTable] <DataTable> [-DataSource] <String> [-Table] <String>
 [[-ConflictClause] <String>] [-NotifyAfter <Int32>] [-Force] [-QueryTimeout <Int32>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Connection
```
Invoke-SQLiteBulkCopy [-DataTable] <DataTable> [-SQLiteConnection] <SQLiteConnection> [-Table] <String>
 [[-ConflictClause] <String>] [-NotifyAfter <Int32>] [-Force] [-QueryTimeout <Int32>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Use a SQLite transaction to quickly insert data.
If we run into any errors, we roll back the transaction.

The data source is not limited to SQL Server; any data source can be used, as long as the data can be loaded to a DataTable instance or read with a IDataReader instance.

## EXAMPLES

### EXAMPLE 1
```
$dataTable = Get-Process | Select-Object Name, Id | ConvertTo-SqliteDataTable
Invoke-SQLiteBulkCopy -DataTable $dataTable -DataSource C:\Processes.sqlite -Table Processes -Force
```

Inserts process data into the Processes table within a single transaction.

## PARAMETERS

### -DataTable
The DataTable containing the rows and columns to insert.

```yaml
Type: DataTable
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DataSource
Path to the SQLite data source to update.

```yaml
Type: String
Parameter Sets: Datasource
Aliases: Path, File, FullName, Database

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SQLiteConnection
An existing SQLiteConnection to use.
We do not close this connection upon completed query.

```yaml
Type: SQLiteConnection
Parameter Sets: Connection
Aliases: Connection, Conn

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Table
The name of the destination SQLite table.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConflictClause
The conflict clause to use in case a conflict occurs during insert.
Valid values: Rollback, Abort, Fail, Ignore, Replace

See https://www.sqlite.org/lang_conflict.html for more details

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NotifyAfter
The number of rows to fire the notification event after transferring.
0 means don't notify.
Notifications hit the verbose stream (use -verbose to see them)

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

### -Force
If specified, skip the confirm prompt

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

### -QueryTimeout
Specifies the number of seconds before the queries time out.

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

### System.Data.DataTable
## OUTPUTS

### None
### Produces no output
## NOTES
This function borrows from:
    Chad Miller's Write-Datatable
    jbs534's Invoke-SQLBulkCopy
    Mike Shepard's Invoke-BulkCopy from SQLPSX

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

[New-SQLiteConnection]()

[Invoke-SQLiteBulkCopy]()

[ConvertTo-SqliteDataTable]()

