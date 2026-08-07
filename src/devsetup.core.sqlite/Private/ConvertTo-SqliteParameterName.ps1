function ConvertTo-SqliteParameterName {
    <#
    .SYNOPSIS
        Converts column names to SQLite bulk-copy parameter names.
    .DESCRIPTION
        Replaces non-word groups with their character codes so generated parameter names remain distinct and bindable.
    .PARAMETER InputObject
        Column names to convert.
    .PARAMETER Regex
        Pattern identifying characters to encode.
    .PARAMETER Separator
        Separator placed between encoded character codes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Regex = '(\W+)',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Separator = '_'
    )

    process {
        $InputObject | ForEach-Object {
            if ($_ -match $Regex) {
                $groups = @($_ -split $Regex | Where-Object { $_ })
                for ($index = 0; $index -lt $groups.Count; $index++) {
                    if ($groups[$index] -match $Regex) {
                        $groups[$index] = ($groups[$index].ToCharArray() | ForEach-Object { [string][int]$_ }) -join $Separator
                    }
                }
                $groups -join $Separator
            } else {
                $_
            }
        }
    }
}
