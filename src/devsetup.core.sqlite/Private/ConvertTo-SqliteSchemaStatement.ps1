function ConvertTo-SqliteSchemaStatement {
    <#
    .SYNOPSIS
        Converts a structured SQLite schema to DDL statements.
    .DESCRIPTION
        Validates a structured PowerShell or JSON schema and emits safely quoted CREATE TABLE and
        CREATE INDEX statements. The model supports columns, literal defaults, primary and unique
        keys, foreign keys, indexes, STRICT tables, WITHOUT ROWID tables, and a database user
        version. Native PowerShell scalar default values are preserved without JSON coercion.
    .PARAMETER Schema
        Hashtable, PSCustomObject, or JSON text containing the structured schema.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Schema
    )

    if ($Schema -is [string]) {
        try {
            if ([string]::IsNullOrWhiteSpace($Schema)) {
                throw 'The structured schema cannot be empty.'
            }
            $schemaObject = $Schema | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "The structured schema is not valid JSON: $($_.Exception.Message)"
        }
    } else {
        $schemaObject = $Schema
    }

    $testSchemaObject = {
        param([AllowNull()][object]$InputObject)
        $null -ne $InputObject -and (
            $InputObject -is [System.Collections.IDictionary] -or
            $InputObject -is [pscustomobject]
        )
    }
    if (-not (& $testSchemaObject $schemaObject)) {
        throw 'The structured schema root must be a dictionary or PSCustomObject.'
    }

    $getPropertyNames = {
        param([object]$InputObject)
        if ($InputObject -is [System.Collections.IDictionary]) {
            @($InputObject.Keys | ForEach-Object { [string]$_ })
        } else {
            @($InputObject.PSObject.Properties | ForEach-Object { $_.Name })
        }
    }
    $getProperty = {
        param([object]$InputObject, [string]$Name)
        if ($InputObject -is [System.Collections.IDictionary]) {
            $matchingKeys = @($InputObject.Keys | Where-Object { [string]$_ -ieq $Name })
            if ($matchingKeys.Count -gt 1) {
                throw "A schema object contains multiple properties named '$Name'."
            }
            if ($matchingKeys.Count -eq 1) {
                return [pscustomobject]@{
                    Name  = [string]$matchingKeys[0]
                    Value = $InputObject[$matchingKeys[0]]
                }
            }
            return $null
        }

        $matchingProperties = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Name })
        if ($matchingProperties.Count -gt 1) {
            throw "A schema object contains multiple properties named '$Name'."
        }
        if ($matchingProperties.Count -eq 1) {
            return $matchingProperties[0]
        }
        $null
    }
    $getArray = {
        param([object]$InputObject, [string]$Name, [string]$Context, [bool]$Required)
        $property = & $getProperty $InputObject $Name
        if ($null -eq $property) {
            if ($Required) {
                throw "$Context requires a non-empty '$Name' array."
            }
            return @()
        }
        if (
            $null -eq $property.Value -or
            $property.Value -is [string] -or
            $property.Value -is [System.Collections.IDictionary] -or
            $property.Value -isnot [System.Collections.IEnumerable]
        ) {
            throw "$Context property '$Name' must be an array."
        }
        $items = @($property.Value)
        if ($Required -and $items.Count -eq 0) {
            throw "$Context requires a non-empty '$Name' array."
        }
        $items
    }
    $getBoolean = {
        param([object]$InputObject, [string]$Name, [bool]$Default)
        $property = & $getProperty $InputObject $Name
        if ($null -eq $property) {
            return $Default
        }
        if ($property.Value -isnot [bool]) {
            throw "Schema property '$Name' must be true or false."
        }
        [bool]$property.Value
    }
    $getRequiredText = {
        param([object]$InputObject, [string]$Name, [string]$Context)
        $property = & $getProperty $InputObject $Name
        if (
            $null -eq $property -or
            $property.Value -isnot [string] -or
            [string]::IsNullOrWhiteSpace($property.Value)
        ) {
            throw "$Context requires a non-empty string '$Name' property."
        }
        $property.Value
    }
    $getNameList = {
        param([object]$InputObject, [string]$Name, [string]$Context, [bool]$Required)
        $names = @(& $getArray $InputObject $Name $Context $Required)
        $nameMap = @{}
        foreach ($item in $names) {
            if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
                throw "$Context property '$Name' must contain only non-empty strings."
            }
            if ($nameMap.ContainsKey($item)) {
                throw "$Context property '$Name' contains duplicate name '$item'."
            }
            $nameMap[$item] = $true
        }
        $names
    }
    $assertKnownColumns = {
        param([string[]]$Names, [hashtable]$ColumnMap, [string]$Context)
        foreach ($name in $Names) {
            if (-not $ColumnMap.ContainsKey($name)) {
                throw "$Context references unknown column '$name'."
            }
        }
    }
    $assertKnownProperties = {
        param([object]$InputObject, [string[]]$Names, [string]$Context)
        if (-not (& $testSchemaObject $InputObject)) {
            throw "$Context must be an object."
        }
        $propertyMap = @{}
        foreach ($propertyName in @(& $getPropertyNames $InputObject)) {
            if ($propertyMap.ContainsKey($propertyName)) {
                throw "$Context contains duplicate property '$propertyName'."
            }
            $propertyMap[$propertyName] = $true
            if ($propertyName -notin $Names) {
                throw "$Context contains unsupported property '$propertyName'."
            }
        }
    }

    & $assertKnownProperties $schemaObject @('Tables', 'UserVersion') 'The structured schema'

    $tables = @(& $getArray $schemaObject 'Tables' 'The structured schema' $true)

    $tableMap = @{}
    $tableNames = [System.Collections.Generic.List[string]]::new()
    $tableColumnMaps = @{}
    $tableColumnNames = @{}
    foreach ($table in $tables) {
        if (-not (& $testSchemaObject $table)) {
            throw "Each entry in 'Tables' must be an object."
        }
        $tableName = & $getRequiredText $table 'Name' 'Each table'
        & $assertKnownProperties $table @(
            'Name', 'Columns', 'PrimaryKey', 'UniqueConstraints', 'ForeignKeys', 'Indexes',
            'WithoutRowId', 'Strict'
        ) "Table '$tableName'"
        if ($tableMap.ContainsKey($tableName)) {
            throw "The structured schema contains duplicate table '$tableName'."
        }

        $columns = @(& $getArray $table 'Columns' "Table '$tableName'" $true)

        $columnMap = @{}
        $columnNames = [System.Collections.Generic.List[string]]::new()
        foreach ($column in $columns) {
            if (-not (& $testSchemaObject $column)) {
                throw "Each column in table '$tableName' must be an object."
            }
            $columnName = & $getRequiredText $column 'Name' "Each column in table '$tableName'"
            & $assertKnownProperties $column @(
                'Name', 'Type', 'PrimaryKey', 'AutoIncrement', 'Nullable', 'Unique', 'Collation',
                'Default', 'DefaultExpression'
            ) "Column '$columnName' in table '$tableName'"
            if ($columnMap.ContainsKey($columnName)) {
                throw "Table '$tableName' contains duplicate column '$columnName'."
            }
            $columnMap[$columnName] = $column
            $columnNames.Add($columnName)
        }

        $tableMap[$tableName] = $table
        $tableNames.Add($tableName)
        $tableColumnMaps[$tableName] = $columnMap
        $tableColumnNames[$tableName] = $columnNames
    }

    $statements = [System.Collections.Generic.List[string]]::new()
    $indexNames = @{}
    foreach ($tableName in $tableNames) {
        $table = $tableMap[$tableName]
        $columnMap = $tableColumnMaps[$tableName]
        $definitions = [System.Collections.Generic.List[string]]::new()
        $columnPrimaryKeys = [System.Collections.Generic.List[string]]::new()

        foreach ($columnName in $tableColumnNames[$tableName]) {
            $column = $columnMap[$columnName]
            $typeName = & $getRequiredText $column 'Type' "Column '$columnName' in table '$tableName'"
            if ($typeName -notmatch '^[A-Za-z][A-Za-z0-9_]*(?:\s+[A-Za-z][A-Za-z0-9_]*)*(?:\s*\(\s*\d+(?:\s*,\s*\d+)?\s*\))?$') {
                throw "Column '$columnName' in table '$tableName' has unsupported type declaration '$typeName'."
            }

            $primaryKey = & $getBoolean $column 'PrimaryKey' $false
            $autoIncrement = & $getBoolean $column 'AutoIncrement' $false
            $nullable = & $getBoolean $column 'Nullable' $true
            $unique = & $getBoolean $column 'Unique' $false
            if ($autoIncrement -and (-not $primaryKey -or $typeName.Trim().ToUpperInvariant() -ne 'INTEGER')) {
                throw "Column '$columnName' in table '$tableName' can use AutoIncrement only with an INTEGER column primary key."
            }
            if ($primaryKey) {
                $columnPrimaryKeys.Add($columnName)
            }

            $parts = [System.Collections.Generic.List[string]]::new()
            $parts.Add((ConvertTo-SqliteQuotedIdentifier -Name $columnName))
            $parts.Add($typeName.Trim())
            if ($primaryKey) {
                $parts.Add('PRIMARY KEY')
            }
            if ($autoIncrement) {
                $parts.Add('AUTOINCREMENT')
            }
            if (-not $nullable) {
                $parts.Add('NOT NULL')
            }
            if ($unique) {
                $parts.Add('UNIQUE')
            }

            $collationProperty = & $getProperty $column 'Collation'
            if ($null -ne $collationProperty) {
                $collation = [string]$collationProperty.Value
                if ($collation -notin @('BINARY', 'NOCASE', 'RTRIM')) {
                    throw "Column '$columnName' in table '$tableName' has unsupported collation '$collation'."
                }
                $parts.Add("COLLATE $($collation.ToUpperInvariant())")
            }

            $defaultProperty = & $getProperty $column 'Default'
            $defaultExpressionProperty = & $getProperty $column 'DefaultExpression'
            if ($null -ne $defaultProperty -and $null -ne $defaultExpressionProperty) {
                throw "Column '$columnName' in table '$tableName' cannot define both Default and DefaultExpression."
            }
            if ($null -ne $defaultProperty) {
                $parts.Add("DEFAULT $(ConvertTo-SqliteSchemaLiteral -Value $defaultProperty.Value)")
            } elseif ($null -ne $defaultExpressionProperty) {
                $defaultExpression = ([string]$defaultExpressionProperty.Value).ToUpperInvariant()
                if ($defaultExpression -notin @('CURRENT_TIME', 'CURRENT_DATE', 'CURRENT_TIMESTAMP')) {
                    throw "Column '$columnName' in table '$tableName' has unsupported DefaultExpression '$($defaultExpressionProperty.Value)'."
                }
                $parts.Add("DEFAULT $defaultExpression")
            }

            $definitions.Add(($parts -join ' '))
        }

        if ($columnPrimaryKeys.Count -gt 1) {
            throw "Table '$tableName' defines more than one column primary key. Use the table-level PrimaryKey array for a composite key."
        }
        $tablePrimaryKey = @(& $getNameList $table 'PrimaryKey' "Table '$tableName'" $false)
        if ($columnPrimaryKeys.Count -gt 0 -and $tablePrimaryKey.Count -gt 0) {
            throw "Table '$tableName' cannot combine a column primary key with the table-level PrimaryKey property."
        }
        if ($tablePrimaryKey.Count -gt 0) {
            & $assertKnownColumns $tablePrimaryKey $columnMap "PrimaryKey for table '$tableName'"
            $quotedColumns = @($tablePrimaryKey | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
            $definitions.Add("PRIMARY KEY ($($quotedColumns -join ', '))")
        }

        foreach ($uniqueConstraint in @(& $getArray $table 'UniqueConstraints' "Table '$tableName'" $false)) {
            if (-not (& $testSchemaObject $uniqueConstraint)) {
                throw "Each unique constraint in table '$tableName' must be an object."
            }
            & $assertKnownProperties $uniqueConstraint @('Name', 'Columns') "A unique constraint in table '$tableName'"
            $uniqueColumns = @(& $getNameList $uniqueConstraint 'Columns' "A unique constraint in table '$tableName'" $true)
            & $assertKnownColumns $uniqueColumns $columnMap "A unique constraint in table '$tableName'"
            $constraintNameProperty = & $getProperty $uniqueConstraint 'Name'
            $prefix = if ($null -ne $constraintNameProperty) {
                "CONSTRAINT $(ConvertTo-SqliteQuotedIdentifier -Name ([string]$constraintNameProperty.Value)) "
            } else {
                ''
            }
            $quotedColumns = @($uniqueColumns | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
            $definitions.Add("${prefix}UNIQUE ($($quotedColumns -join ', '))")
        }

        foreach ($foreignKey in @(& $getArray $table 'ForeignKeys' "Table '$tableName'" $false)) {
            if (-not (& $testSchemaObject $foreignKey)) {
                throw "Each foreign key in table '$tableName' must be an object."
            }
            & $assertKnownProperties $foreignKey @(
                'Name', 'Columns', 'References', 'OnDelete', 'OnUpdate'
            ) "A foreign key in table '$tableName'"
            $foreignColumns = @(& $getNameList $foreignKey 'Columns' "A foreign key in table '$tableName'" $true)
            & $assertKnownColumns $foreignColumns $columnMap "A foreign key in table '$tableName'"
            $referencesProperty = & $getProperty $foreignKey 'References'
            if ($null -eq $referencesProperty -or -not (& $testSchemaObject $referencesProperty.Value)) {
                throw "A foreign key in table '$tableName' requires a References object."
            }
            & $assertKnownProperties $referencesProperty.Value @('Table', 'Columns') "References for a foreign key in table '$tableName'"
            $referencedTable = & $getRequiredText $referencesProperty.Value 'Table' "A foreign key in table '$tableName'"
            if (-not $tableMap.ContainsKey($referencedTable)) {
                throw "A foreign key in table '$tableName' references unknown table '$referencedTable'."
            }
            $referencedColumns = @(& $getNameList $referencesProperty.Value 'Columns' "A foreign key in table '$tableName'" $true)
            if ($foreignColumns.Count -ne $referencedColumns.Count) {
                throw "A foreign key in table '$tableName' must reference the same number of columns."
            }
            & $assertKnownColumns $referencedColumns $tableColumnMaps[$referencedTable] "A foreign key in table '$tableName'"

            $constraintNameProperty = & $getProperty $foreignKey 'Name'
            $prefix = if ($null -ne $constraintNameProperty) {
                "CONSTRAINT $(ConvertTo-SqliteQuotedIdentifier -Name ([string]$constraintNameProperty.Value)) "
            } else {
                ''
            }
            $quotedForeignColumns = @($foreignColumns | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
            $quotedReferencedColumns = @($referencedColumns | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
            $definition = "${prefix}FOREIGN KEY ($($quotedForeignColumns -join ', ')) REFERENCES " +
                "$(ConvertTo-SqliteQuotedIdentifier -Name $referencedTable) ($($quotedReferencedColumns -join ', '))"
            foreach ($actionName in @('OnDelete', 'OnUpdate')) {
                $actionProperty = & $getProperty $foreignKey $actionName
                if ($null -ne $actionProperty) {
                    $action = ([string]$actionProperty.Value).ToUpperInvariant()
                    if ($action -notin @('NO ACTION', 'RESTRICT', 'SET NULL', 'SET DEFAULT', 'CASCADE')) {
                        throw "A foreign key in table '$tableName' has unsupported $actionName action '$($actionProperty.Value)'."
                    }
                    $sqlActionName = if ($actionName -eq 'OnDelete') { 'ON DELETE' } else { 'ON UPDATE' }
                    $definition += " $sqlActionName $action"
                }
            }
            $definitions.Add($definition)
        }

        $withoutRowId = & $getBoolean $table 'WithoutRowId' $false
        $strict = & $getBoolean $table 'Strict' $false
        if ($withoutRowId -and $columnPrimaryKeys.Count -eq 0 -and $tablePrimaryKey.Count -eq 0) {
            throw "Table '$tableName' must define a primary key when WithoutRowId is true."
        }
        if ($strict) {
            foreach ($columnName in $tableColumnNames[$tableName]) {
                $strictType = [string]((& $getProperty $columnMap[$columnName] 'Type').Value)
                if ($strictType.Trim().ToUpperInvariant() -notin @('INT', 'INTEGER', 'REAL', 'TEXT', 'BLOB', 'ANY')) {
                    throw "STRICT table '$tableName' uses unsupported SQLite strict type '$strictType' for column '$columnName'."
                }
            }
        }

        $tableOptions = [System.Collections.Generic.List[string]]::new()
        if ($withoutRowId) { $tableOptions.Add('WITHOUT ROWID') }
        if ($strict) { $tableOptions.Add('STRICT') }
        $optionClause = if ($tableOptions.Count -gt 0) { ' ' + ($tableOptions -join ', ') } else { '' }
        $quotedTable = ConvertTo-SqliteQuotedIdentifier -Name $tableName
        $statements.Add("CREATE TABLE $quotedTable ($($definitions -join ', '))$optionClause;")

        foreach ($index in @(& $getArray $table 'Indexes' "Table '$tableName'" $false)) {
            if (-not (& $testSchemaObject $index)) {
                throw "Each index in table '$tableName' must be an object."
            }
            $indexName = & $getRequiredText $index 'Name' "Each index in table '$tableName'"
            & $assertKnownProperties $index @('Name', 'Columns', 'Unique') "Index '$indexName' in table '$tableName'"
            if ($indexNames.ContainsKey($indexName)) {
                throw "The structured schema contains duplicate index '$indexName'."
            }
            $indexNames[$indexName] = $true
            $indexColumns = @(& $getNameList $index 'Columns' "Index '$indexName' in table '$tableName'" $true)
            & $assertKnownColumns $indexColumns $columnMap "Index '$indexName' in table '$tableName'"
            $uniqueIndex = & $getBoolean $index 'Unique' $false
            $uniqueClause = if ($uniqueIndex) { 'UNIQUE ' } else { '' }
            $quotedIndexColumns = @($indexColumns | ForEach-Object { ConvertTo-SqliteQuotedIdentifier -Name $_ })
            $quotedIndex = ConvertTo-SqliteQuotedIdentifier -Name $indexName
            $statements.Add("CREATE ${uniqueClause}INDEX $quotedIndex ON $quotedTable ($($quotedIndexColumns -join ', '));")
        }
    }

    $userVersionProperty = & $getProperty $schemaObject 'UserVersion'
    if ($null -ne $userVersionProperty) {
        $userVersionValue = $userVersionProperty.Value
        $isInteger =
            $userVersionValue -is [byte] -or $userVersionValue -is [sbyte] -or
            $userVersionValue -is [int16] -or $userVersionValue -is [uint16] -or
            $userVersionValue -is [int32] -or $userVersionValue -is [uint32] -or
            $userVersionValue -is [int64] -or $userVersionValue -is [uint64]
        try {
            if (-not $isInteger) {
                throw 'The value is not an integer.'
            }
            $userVersion = [System.Convert]::ToInt32(
                $userVersionValue,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } catch {
            throw "Schema property 'UserVersion' must be a non-negative 32-bit integer."
        }
        if ($userVersion -lt 0) {
            throw "Schema property 'UserVersion' must be a non-negative 32-bit integer."
        }
        $statements.Add("PRAGMA user_version = $userVersion;")
    }

    $statements.ToArray()
}
