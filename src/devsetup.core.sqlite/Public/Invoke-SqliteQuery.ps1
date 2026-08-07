function Invoke-SqliteQuery {
    <#
    .SYNOPSIS
        Runs a SQL script against a SQLite database.

    .DESCRIPTION
        Runs a SQL script against a SQLite database.

        Paramaterized queries are supported.

        Help details below borrowed from Invoke-Sqlcmd, may be inaccurate here.

    .PARAMETER DataSource
        Path to one or more SQLite data sources to query

    .PARAMETER Query
        Specifies a query to be run.

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-SqliteQuery. Specify the full path to the file.

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER SqlParameters
        Hashtable of parameters for parameterized SQL queries.  http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

        Limited support for conversions to SQLite friendly formats is supported.
            For example, if you pass in a .NET DateTime, we convert it to a string that SQLite will recognize as a datetime

        Example:
            -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
            -SqlParameters @{"ServerName = "c-is-hyperv-1"}

    .PARAMETER SQLiteConnection
        An existing SQLiteConnection to use.  We do not close this connection upon completed query.

    .PARAMETER AppendDataSource
        If specified, append the SQLite data source path to PSObject or DataRow output

    .PARAMETER AssemblyPath
        Retained for compatibility with earlier versions. The module automatically loads the bundled provider assembly.

    .PARAMETER DateTimeFormat
        Controls how System.Data.SQLite parses and serializes DateTime values when DataSource is
        used. The default is InvariantCulture, which supports common SQLite timestamp forms and
        timestamps containing a separated UTC offset.

    .PARAMETER DateTimeKind
        Specifies the DateTime kind used while parsing values when DataSource is used. The default
        is Utc. Configure an existing SQLiteConnection directly when using SQLiteConnection.

    .PARAMETER DateTimeFormatString
        An optional exact .NET DateTime format string for databases with a fixed timestamp
        representation. This parameter is available with the DataSource parameter sets.

    .INPUTS
        DataSource
            You can pipe DataSource paths to Invoke-SQLiteQuery.  The query will execute against each Data Source.

    .OUTPUTS
       As PSObject:     System.Management.Automation.PSCustomObject
       As DataRow:      System.Data.DataRow
       As DataTable:    System.Data.DataTable
       As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
       As SingleValue:  Dependent on data type in first column.

    .EXAMPLE
        Invoke-SqliteQuery -DataSource C:\Names.sqlite -Query 'SELECT * FROM Names'

        Runs a query against a SQLite database and returns PowerShell objects.

    .EXAMPLE
        $parameters = @{ FullName = 'Cookie Monster' }
        Invoke-SqliteQuery -DataSource C:\Names.sqlite -Query 'SELECT * FROM Names WHERE FullName = @FullName' -SqlParameters $parameters

        Runs a parameterized query.

    .EXAMPLE
        Invoke-SqliteQuery -DataSource C:\Names.sqlite -InputFile C:\Query.sql

        Reads and executes SQL from a file.

    .EXAMPLE
        $connection = New-SQLiteConnection -DataSource :MEMORY:
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE Names (FullName TEXT)'

        Executes a query using an existing SQLite connection.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite

    .LINK
        https://www.sqlite.org/datatype3.html

    .LINK
        https://www.sqlite.org/lang.html

    .LINK
        http://www.sqlite.org/pragma.html

    .FUNCTIONALITY
        SQL
    #>

    [CmdletBinding( DefaultParameterSetName='Src-Que' )]
    [OutputType([System.Management.Automation.PSCustomObject],[System.Data.DataRow],[System.Data.DataTable],[System.Data.DataTableCollection],[System.Data.DataSet])]
    param(
        [Parameter( ParameterSetName='Src-Que',
                    Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQLite Data Source required...' )]
        [Parameter( ParameterSetName='Src-Fil',
                    Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQLite Data Source required...' )]
        [Alias('Path','File','FullName','Database')]
        [validatescript({
            #This should match memory, or the parent path should exist
            $Parent = Split-Path $_ -Parent
            if(
                $_ -match ":MEMORY:|^WHAT$" -or
                ( $Parent -and (Test-Path $Parent))
            ){
                $True
            }
            else {
                Throw "Invalid datasource '$_'.`nThis must match :MEMORY:, or '$Parent' must exist"
            }
        })]
        [string[]]
        $DataSource,

        [Parameter( ParameterSetName='Src-Que',
                    Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Con-Que',
                    Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [string]
        $Query,

        [Parameter( ParameterSetName='Src-Fil',
                    Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Con-Fil',
                    Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $InputFile,

        [Parameter( Position=2,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $QueryTimeout=600,

        [Parameter( Position=3,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateSet("DataSet", "DataTable", "DataRow","PSObject","SingleValue")]
        [string]
        $As="PSObject",

        [Parameter( Position=4,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Collections.IDictionary]
        $SqlParameters,

        [Parameter( Position=5,
                    Mandatory=$false )]
        [switch]
        $AppendDataSource,

        [Parameter( Position=6,
                    Mandatory=$false )]
        [validatescript({Test-Path $_ })]
        [string]$AssemblyPath = $SQLiteAssembly,

        [Parameter( ParameterSetName='Src-Que',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Src-Fil',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Data.SQLite.SQLiteDateFormats]
        $DateTimeFormat = [System.Data.SQLite.SQLiteDateFormats]::InvariantCulture,

        [Parameter( ParameterSetName='Src-Que',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Src-Fil',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.DateTimeKind]
        $DateTimeKind = [System.DateTimeKind]::Utc,

        [Parameter( ParameterSetName='Src-Que',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Src-Fil',
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateNotNullOrEmpty()]
        [string]
        $DateTimeFormatString,

        [Parameter( ParameterSetName = 'Con-Que',
                    Position=7,
                    Mandatory=$true,
                    ValueFromPipeline=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName = 'Con-Fil',
                    Position=7,
                    Mandatory=$true,
                    ValueFromPipeline=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Alias( 'Connection', 'Conn' )]
        [System.Data.SQLite.SQLiteConnection]
        $SQLiteConnection
    )

    Begin
    {
        #Assembly, should already be covered by psm1
            Try
            {
                [void][System.Data.SQLite.SQLiteConnection]
            }
            Catch
            {
                if( -not ($Library = Add-Type -path $SQLiteAssembly -PassThru -ErrorAction stop) )
                {
                    Throw "This module requires the System.Data.SQLite ADO.NET provider: https://www.nuget.org/packages/System.Data.SQLite"
                }
            }

        if ($PSBoundParameters.ContainsKey('InputFile'))
        {
            $filePath = $(Resolve-Path $InputFile).path
            $Query =  [System.IO.File]::ReadAllText("$filePath")
            Write-Verbose "Extracted query from [$InputFile]"
        }
        Write-Verbose "Running Invoke-SQLiteQuery with ParameterSet '$($PSCmdlet.ParameterSetName)'.  Performing query '$Query'"

        If($As -eq "PSObject" -and -not ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]))
        {
            Write-Warning 'The SQLite DBNull scrubber is unavailable. Defaulting to DataRow output.'
            $As = "Datarow"
        }

        #Handle existing connections
        if($PSBoundParameters.Keys -contains "SQLiteConnection")
        {
            if($SQLiteConnection.State -notlike "Open")
            {
                Try
                {
                    $SQLiteConnection.Open()
                }
                Catch
                {
                    Throw $_
                }
            }

            if($SQLiteConnection.state -notlike "Open")
            {
                Throw "SQLiteConnection is not open:`n$($SQLiteConnection | Out-String)"
            }

            $DataSource = @("WHAT")
        }
    }
    Process
    {
        foreach($DB in $DataSource)
        {

            if($PSBoundParameters.Keys -contains "SQLiteConnection")
            {
                $Conn = $SQLiteConnection
            }
            else
            {
                # Resolve the path entered for the database to a proper path name.
                # This accounts for a variaty of possible ways to provide a path, but
                # in the end the connection string needs a fully qualified file path.
                if ($DB -match ":MEMORY:")
                {
                    $Database = $DB
                }
                else
                {
                    $Database = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DB)
                }

                if(Test-Path $Database)
                {
                    Write-Verbose "Querying existing Data Source '$Database'"
                }
                else
                {
                    Write-Verbose "Creating andn querying Data Source '$Database'"
                }

                $ConnectionParameters = @{
                    DataSource = $Database
                    DateTimeFormat = $DateTimeFormat
                    DateTimeKind = $DateTimeKind
                    ErrorAction = 'Stop'
                }
                if($PSBoundParameters.ContainsKey('DateTimeFormatString'))
                {
                    $ConnectionParameters.DateTimeFormatString = $DateTimeFormatString
                }

                Try
                {
                    $conn = New-SQLiteConnection @ConnectionParameters
                }
                Catch
                {
                    Write-Error $_
                    continue
                }
            }

            $cmd = $Conn.CreateCommand()
            $cmd.CommandText = $Query
            $cmd.CommandTimeout = $QueryTimeout

            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        {
                            if($_.Value -is [datetime]) { $_.Value = $_.Value.ToString("yyyy-MM-dd HH:mm:ss") }
                            $cmd.Parameters.AddWithValue("@$($_.Key)", $_.Value)
                        }
                        Else
                        {
                            $cmd.Parameters.AddWithValue("@$($_.Key)", [DBNull]::Value)
                        }
                    } > $null
            }

            $ds = New-Object system.Data.DataSet
            $da = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)

            Try
            {
                [void]$da.fill($ds)
            }
            Catch
            {
                $Err = $_
                switch ($ErrorActionPreference.tostring())
                {
                    {'SilentlyContinue','Ignore' -contains $_} {}
                    'Stop' {     Throw $Err }
                    'Continue' { Write-Error $Err}
                    Default {    Write-Error $Err}
                }
            }
            Finally
            {
                $da.Dispose()
                $cmd.Dispose()
                if($PSBoundParameters.Keys -notcontains "SQLiteConnection")
                {
                    $conn.Close()
                    $conn.Dispose()
                }
            }

            if($AppendDataSource)
            {
                #Basics from Chad Miller
                $Column =  New-Object Data.DataColumn
                $Column.ColumnName = "Datasource"
                $ds.Tables[0].Columns.Add($Column)

                Try
                {
                    #Someone better at regular expression, feel free to tackle this
                    $Conn.ConnectionString -match "Data Source=(?<DataSource>.*);"
                    $Datasrc = $Matches.DataSource.split(";")[0]
                }
                Catch
                {
                    $Datasrc = $DB
                }

                Foreach($row in $ds.Tables[0])
                {
                    $row.Datasource = $Datasrc
                }
            }

            switch ($As)
            {
                'DataSet'
                {
                    $ds
                }
                'DataTable'
                {
                    $ds.Tables
                }
                'DataRow'
                {
                    $ds.Tables[0]
                }
                'PSObject'
                {
                    #Scrub DBNulls - Provides convenient results you can use comparisons with
                    #Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
                    foreach ($row in $ds.Tables[0].Rows)
                    {
                        [DevSetup.Core.SQLite.DBNullScrubber]::DataRowToPSObject($row)
                    }
                }
                'SingleValue'
                {
                    $ds.Tables[0] | Select-Object -ExpandProperty $ds.Tables[0].Columns[0].ColumnName
                }
            }
        }
    }
}
