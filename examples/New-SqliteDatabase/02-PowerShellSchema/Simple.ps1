[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'powershell-schema-simple.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schema = @{
    Tables = @(
        @{
            Name = 'Books'
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                @{ Name = 'Title'; Type = 'TEXT'; Nullable = $false }
                @{ Name = 'Author'; Type = 'TEXT' }
            )
        }
    )
}

New-SqliteDatabase -Path $DatabasePath -Schema $schema
Add-SqliteRow -DataSource $DatabasePath -On Books -Data @{ Title = 'The Left Hand of Darkness'; Author = 'Ursula K. Le Guin' }

Get-SqliteRow -DataSource $DatabasePath -On Books
