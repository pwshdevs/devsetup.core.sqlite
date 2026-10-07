---
external help file: devsetup.core.sqlite-help.xml
Module Name: devsetup.core.sqlite
online version: https://github.com/pwshdevs/devsetup.core.sqlite
schema: 2.0.0
---

# ConvertTo-SqliteDataTable

## SYNOPSIS
Creates a DataTable for an object

## SYNTAX

```
ConvertTo-SqliteDataTable [-InputObject] <PSObject[]> [-NonNullable <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates a DataTable based on an object's properties.

## EXAMPLES

### EXAMPLE 1
```
$dt = Get-psdrive | ConvertTo-SqliteDataTable
```

Creates a DataTable from the properties returned by Get-PSDrive and assigns it to $dt.

### EXAMPLE 2
```
$dataTable = Get-Process | Select-Object Name, CPU | ConvertTo-SqliteDataTable
Invoke-SQLiteBulkCopy -DataTable $dataTable -DataSource C:\Processes.sqlite -Table Processes -Force
```

Converts selected process properties to a DataTable and inserts the rows into SQLite.

## PARAMETERS

### -InputObject
One or more objects to convert into a DataTable

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -NonNullable
A list of columns to set disable AllowDBNull on

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @()
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

### Object
### Any object can be piped to ConvertTo-SqliteDataTable
## OUTPUTS

### System.Data.DataTable
## NOTES
Adapted from script by Marc van Orsouw and function from Chad Miller
Version History
v1.0  - Chad Miller - Initial Release
v1.1  - Chad Miller - Fixed Issue with Properties
v1.2  - Chad Miller - Added setting column datatype by property as suggested by emp0
v1.3  - Chad Miller - Corrected issue with setting datatype on empty properties
v1.4  - Chad Miller - Corrected issue with DBNull
v1.5  - Chad Miller - Updated example
v1.6  - Chad Miller - Added column datatype logic with default to string
v1.7  - Chad Miller - Fixed issue with IsArray
v1.8  - ramblingcookiemonster - Removed if($Value) logic.
This would not catch empty strings, zero, $false and other non-null items
                              - Added perhaps pointless error handling

## RELATED LINKS

[https://github.com/pwshdevs/devsetup.core.sqlite](https://github.com/pwshdevs/devsetup.core.sqlite)

[Invoke-SQLiteBulkCopy]()

[New-SQLiteConnection]()

