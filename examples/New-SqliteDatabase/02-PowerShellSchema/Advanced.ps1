[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'powershell-schema-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$schema = @{
    UserVersion = 3
    Tables = @(
        @{
            Name = 'Organizations'
            Strict = $true
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                @{ Name = 'Name'; Type = 'TEXT'; Nullable = $false; Unique = $true; Collation = 'NOCASE' }
            )
        }
        @{
            Name = 'Projects'
            Strict = $true
            Columns = @(
                @{ Name = 'Id'; Type = 'INTEGER'; PrimaryKey = $true; AutoIncrement = $true }
                @{ Name = 'OrganizationId'; Type = 'INTEGER'; Nullable = $false }
                @{ Name = 'Slug'; Type = 'TEXT'; Nullable = $false; Collation = 'NOCASE' }
                @{ Name = 'State'; Type = 'TEXT'; Nullable = $false; Default = 'planned' }
                @{ Name = 'CreatedAt'; Type = 'TEXT'; Nullable = $false; DefaultExpression = 'CURRENT_TIMESTAMP' }
            )
            UniqueConstraints = @(
                @{ Name = 'UQ_Projects_OrganizationSlug'; Columns = @('OrganizationId', 'Slug') }
            )
            ForeignKeys = @(
                @{
                    Name = 'FK_Projects_Organizations'
                    Columns = @('OrganizationId')
                    References = @{ Table = 'Organizations'; Columns = @('Id') }
                    OnDelete = 'CASCADE'
                    OnUpdate = 'NO ACTION'
                }
            )
            Indexes = @(
                @{ Name = 'IX_Projects_StateCreatedAt'; Columns = @('State', 'CreatedAt') }
            )
        }
        @{
            Name = 'ProjectLabels'
            Strict = $true
            WithoutRowId = $true
            Columns = @(
                @{ Name = 'ProjectId'; Type = 'INTEGER'; Nullable = $false }
                @{ Name = 'Label'; Type = 'TEXT'; Nullable = $false; Collation = 'NOCASE' }
            )
            PrimaryKey = @('ProjectId', 'Label')
            ForeignKeys = @(
                @{
                    Columns = @('ProjectId')
                    References = @{ Table = 'Projects'; Columns = @('Id') }
                    OnDelete = 'CASCADE'
                }
            )
        }
    )
}

New-SqliteDatabase -Path $DatabasePath -Schema $schema
Add-SqliteRow -DataSource $DatabasePath -On Organizations -Data @{ Id = 1; Name = 'PwshDevs' }
Add-SqliteRow -DataSource $DatabasePath -On Projects -Data @{
    Id = 1
    OrganizationId = 1
    Slug = 'devsetup-core-sqlite'
}
Add-SqliteRow -DataSource $DatabasePath -On ProjectLabels -Data @(
    @{ ProjectId = 1; Label = 'powershell' }
    @{ ProjectId = 1; Label = 'sqlite' }
)

Get-SqliteRow -DataSource $DatabasePath -On Projects -Where @{ OrganizationId = 1 }
