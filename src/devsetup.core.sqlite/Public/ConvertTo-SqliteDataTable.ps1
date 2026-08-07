function ConvertTo-SqliteDataTable
{
<#
.SYNOPSIS
    Creates a DataTable for an object

.DESCRIPTION
    Creates a DataTable based on an object's properties.

.PARAMETER InputObject
    One or more objects to convert into a DataTable

.PARAMETER NonNullable
    A list of columns to set disable AllowDBNull on

.INPUTS
    Object
        Any object can be piped to ConvertTo-SqliteDataTable

.OUTPUTS
   System.Data.DataTable

.EXAMPLE
    $dt = Get-psdrive | ConvertTo-SqliteDataTable

    Creates a DataTable from the properties returned by Get-PSDrive and assigns it to $dt.

.EXAMPLE
    $dataTable = Get-Process | Select-Object Name, CPU | ConvertTo-SqliteDataTable
    Invoke-SQLiteBulkCopy -DataTable $dataTable -DataSource C:\Processes.sqlite -Table Processes -Force

    Converts selected process properties to a DataTable and inserts the rows into SQLite.

.NOTES
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
    v1.8  - ramblingcookiemonster - Removed if($Value) logic.  This would not catch empty strings, zero, $false and other non-null items
                                  - Added perhaps pointless error handling

.LINK
    https://github.com/pwshdevs/devsetup.core.sqlite

.FUNCTIONALITY
    SQL
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline = $true)]
        [PSObject[]]$InputObject,

        [string[]]$NonNullable = @()
    )

    Begin
    {
        $dt = New-Object Data.datatable
        $First = $true
    }
    Process
    {
        foreach ($Object in $InputObject)
        {
            $DR = $DT.NewRow()
            foreach ($Property in $Object.PsObject.Properties)
            {
                $Name = $Property.Name
                $Value = $Property.Value

                #RCM: what if the first property is not reflective of all the properties?  Unlikely, but...
                if ($First)
                {
                    $Col = New-Object Data.DataColumn
                    $Col.ColumnName = $Name

                    #If it's not DBNull or Null, get the type
                    if ($Value -isnot [System.DBNull] -and $Value -ne $null)
                    {
                        $Col.DataType = [System.Type]::GetType( $(Get-SqliteDataColumnType $property.TypeNameOfValue) )
                    }

                    #Set it to nonnullable if specified
                    if ($NonNullable -contains $Name )
                    {
                        $col.AllowDBNull = $false
                    }

                    try
                    {
                        $DT.Columns.Add($Col)
                    }
                    catch
                    {
                        Write-Error "Could not add column $($Col | Out-String) for property '$Name' with value '$Value' and type '$($Value.GetType().FullName)':`n$_"
                    }
                }

                Try
                {
                    #Handle arrays and nulls
                    if ($property.GetType().IsArray)
                    {
                        $DR.Item($Name) = $Value | ConvertTo-XML -As String -NoTypeInformation -Depth 1
                    }
                    elseif($Value -eq $null)
                    {
                        $DR.Item($Name) = [DBNull]::Value
                    }
                    else
                    {
                        $DR.Item($Name) = $Value
                    }
                }
                Catch
                {
                    Write-Error "Could not add property '$Name' with value '$Value' and type '$($Value.GetType().FullName)'"
                    continue
                }

                #Did we get a null or dbnull for a non-nullable item?  let the user know.
                if($NonNullable -contains $Name -and ($Value -is [System.DBNull] -or $Value -eq $null))
                {
                    write-verbose "NonNullable property '$Name' with null value found: $($object | out-string)"
                }

            }

            Try
            {
                $DT.Rows.Add($DR)
            }
            Catch
            {
                Write-Error "Failed to add row '$($DR | Out-String)':`n$_"
            }

            $First = $false
        }
    }

    End
    {
        Write-Output @(,$dt)
    }

} #ConvertTo-SqliteDataTable
