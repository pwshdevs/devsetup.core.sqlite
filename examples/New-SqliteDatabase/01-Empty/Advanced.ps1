[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'empty-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$connection = New-SqliteDatabase -Path $DatabasePath -PassThru
try {
    Invoke-SqliteQuery -SQLiteConnection $connection -Query @'
CREATE TABLE ApplicationInfo (
    Name TEXT PRIMARY KEY,
    Value TEXT NOT NULL
);
'@

    Add-SqliteRow -SQLiteConnection $connection -On ApplicationInfo -Data @(
        @{ Name = 'SchemaOwner'; Value = 'external-migrator' }
        @{ Name = 'SchemaVersion'; Value = '1' }
    )

    Get-SqliteRow -SQLiteConnection $connection -On ApplicationInfo -OrderBy Name
} finally {
    $connection.Dispose()
}
