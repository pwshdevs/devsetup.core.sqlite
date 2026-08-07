function New-SQLiteConnection
{
    <#
    .SYNOPSIS
        Creates a SQLiteConnection to a SQLite data source

    .DESCRIPTION
        Creates a SQLiteConnection to a SQLite data source

    .PARAMETER DataSource
       SQLite Data Source to connect to.

    .PARAMETER Password
        Specifies A Secure String password to use in the SQLite connection string.

        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

    .PARAMETER ReadOnly
        If specified, open SQLite data source as read only

    .PARAMETER DateTimeFormat
        Controls how System.Data.SQLite parses and serializes DateTime values. The default is
        InvariantCulture, which accepts common SQLite timestamps as well as timestamps containing
        a separated UTC offset, such as "2019-07-02 04:59:18.578 +00:00".

    .PARAMETER DateTimeKind
        Specifies the DateTime kind used by System.Data.SQLite while parsing values. The default is
        Utc so timestamps with offsets preserve the represented instant consistently across hosts.

    .PARAMETER DateTimeFormatString
        An optional exact .NET DateTime format string for databases with a fixed, non-standard
        timestamp representation. Leave this unset to use the broader DateTimeFormat behavior.

    .PARAMETER Open
        We open the connection by default.  You can use this parameter to create a connection without opening it.

    .OUTPUTS
        System.Data.SQLite.SQLiteConnection

    .EXAMPLE
        $Connection = New-SQLiteConnection -DataSource C:\NAMES.SQLite
        Invoke-SQLiteQuery -SQLiteConnection $Connection -query $Query

        Connects to C:\NAMES.SQLite and invokes a query against it.

    .EXAMPLE
        $Connection = New-SQLiteConnection -DataSource :MEMORY:
        Invoke-SqliteQuery -SQLiteConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
        Invoke-SqliteQuery -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
        Invoke-SqliteQuery -SQLiteConnection $Connection -Query "PRAGMA STATS"

        Creates an in-memory SQLite database, adds a table and row, and inspects its statistics.

    .EXAMPLE
        $Connection = New-SQLiteConnection -DataSource C:\Events.SQLite `
            -DateTimeFormatString 'yyyy-MM-dd HH:mm:ss.FFF zzz' `
            -DateTimeKind Utc

        Uses an exact format for a database with a fixed timestamp representation.

    .LINK
        https://github.com/pwshdevs/devsetup.core.sqlite

    .FUNCTIONALITY
        SQL

    #>
    [cmdletbinding()]
    [OutputType([System.Data.SQLite.SQLiteConnection])]
    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQL Server Instance required...' )]
        [Alias( 'Instance', 'Instances', 'ServerInstance', 'Server', 'Servers','cn','Path','File','FullName','Database' )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $DataSource,

        [Parameter( Position=2,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Security.SecureString]
        $Password,

        [Parameter( Position=3,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Switch]
        $ReadOnly,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Data.SQLite.SQLiteDateFormats]
        $DateTimeFormat = [System.Data.SQLite.SQLiteDateFormats]::InvariantCulture,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.DateTimeKind]
        $DateTimeKind = [System.DateTimeKind]::Utc,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateNotNullOrEmpty()]
        [string]
        $DateTimeFormatString,

        [Parameter( Position=4,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [bool]
        $Open = $True
    )
    Process
    {
        foreach($DataSRC in $DataSource)
        {
            if ($DataSRC -match ':MEMORY:' )
            {
                $Database = $DataSRC
            }
            else
            {
                $Database = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DataSRC)
            }

            Write-Verbose "Querying Data Source '$Database'"

            $ConnectionStringBuilder = New-Object System.Data.SQLite.SQLiteConnectionStringBuilder
            $ConnectionStringBuilder['Data Source'] = $Database
            $ConnectionStringBuilder.DateTimeFormat = $DateTimeFormat
            $ConnectionStringBuilder.DateTimeKind = $DateTimeKind

            if($PSBoundParameters.ContainsKey('DateTimeFormatString'))
            {
                $ConnectionStringBuilder.DateTimeFormatString = $DateTimeFormatString
            }

            if ($Password)
            {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                try
                {
                    $ConnectionStringBuilder.Password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
                }
                finally
                {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                }
            }
            if($ReadOnly)
            {
                $ConnectionStringBuilder.ReadOnly = $true
            }

            [string]$ConnectionString = $ConnectionStringBuilder.ConnectionString

            $conn = New-Object System.Data.SQLite.SQLiteConnection -ArgumentList $ConnectionString
            $conn.ParseViaFramework = $true #Allow UNC paths, thanks to Ray Alex!
            Write-Debug "ConnectionString $ConnectionString"

            if($Open)
            {
                Try
                {
                    $conn.Open()
                }
                Catch
                {
                    Write-Error $_
                    continue
                }
            }

            write-Verbose "Created SQLiteConnection:`n$($Conn | Out-String)"

            $Conn
        }
    }
}
