Describe 'SQLite row commands' {
BeforeAll {
    $projectRoot = if ($env:BHProjectPath) {
        $env:BHProjectPath
    } else {
        Split-Path $PSScriptRoot -Parent
    }
    $sourceManifest = Join-Path $projectRoot 'src/devsetup.core.sqlite/devsetup.core.sqlite.psd1'
    $manifest = Import-PowerShellDataFile -LiteralPath $sourceManifest
    $outputManifest = Join-Path $projectRoot "Output/devsetup.core.sqlite/$($manifest.ModuleVersion)/devsetup.core.sqlite.psd1"
    $moduleManifest = if ($env:BHProjectPath -and (Test-Path -LiteralPath $outputManifest -PathType Leaf)) {
        $outputManifest
    } else {
        $sourceManifest
    }

    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
    Import-Module $moduleManifest -Force -ErrorAction Stop
}

AfterAll {
    [System.Data.SQLite.SQLiteConnection]::ClearAllPools()
    Get-Module devsetup.core.sqlite | Remove-Module -Force -ErrorAction Ignore
}

BeforeEach {
    $script:connection = New-SqliteConnection -DataSource :MEMORY:
    Invoke-SqliteQuery -SQLiteConnection $script:connection -Query @'
CREATE TABLE People (
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL UNIQUE,
    Active INTEGER NOT NULL DEFAULT 1,
    Note TEXT,
    CreatedAt TEXT
)
'@
}

AfterEach {
    if ($null -ne $script:connection) {
        $script:connection.Dispose()
        $script:connection = $null
    }
}

Context 'Add-SqliteRow' {
    It 'supports the natural On and Data batch syntax' {
        Add-SqliteRow -SQLiteConnection $connection -On People -Data @(
            @{ Id = 1; Name = 'Ada' }
            @{ Id = 2; Name = 'Grace' }
        )

        @(Get-SqliteRow -SQLiteConnection $connection -On People).Count | Should -Be 2
    }

    It 'accepts objects from the pipeline' {
        @(
            [pscustomobject]@{ Id = 1; Name = 'Ada' }
            [pscustomobject]@{ Id = 2; Name = 'Grace' }
        ) | Add-SqliteRow -SQLiteConnection $connection -Table People

        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Name | Should -Be @('Ada', 'Grace')
    }

    It 'uses the union of columns and fills missing values with null' {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
            @{ Id = 1; Name = 'Ada'; Note = 'first' }
            @{ Id = 2; Name = 'Grace'; CreatedAt = '2026-01-02' }
        )

        $rows = @(Get-SqliteRow -SQLiteConnection $connection -Table People -OrderBy Id)
        $rows[0].CreatedAt | Should -BeNullOrEmpty
        $rows[1].Note | Should -BeNullOrEmpty
    }

    It 'quotes unusual table and column identifiers' {
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE "Odd "" Table" ("select" INTEGER, "Display Name" TEXT)'
        Add-SqliteRow -SQLiteConnection $connection -On 'Odd " Table' -Data @{ select = 7; 'Display Name' = 'safe' }

        $row = Get-SqliteRow -SQLiteConnection $connection -On 'Odd " Table' -Column 'select', 'Display Name'
        $row.select | Should -Be 7
        $row.'Display Name' | Should -Be 'safe'
    }

    It 'does not interpret an identifier as executable SQL' {
        $hostileName = 'Rows"; DROP TABLE People;--'
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE "Rows""; DROP TABLE People;--" ("Value" TEXT)'
        Add-SqliteRow -SQLiteConnection $connection -Table $hostileName -Data @{ Value = 'safe' }

        (Get-SqliteRow -SQLiteConnection $connection -Table $hostileName).Value | Should -Be 'safe'
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'SELECT COUNT(*) FROM People' -As SingleValue | Should -Be 0
    }

    It 'rolls back the entire batch when one row violates a constraint' {
        {
            Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
                @{ Id = 1; Name = 'duplicate' }
                @{ Id = 2; Name = 'duplicate' }
            ) -ErrorAction Stop
        } | Should -Throw

        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Count | Should -Be 0
    }

    It 'supports Ignore conflict handling and PassThru accurately' {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @{ Id = 1; Name = 'Ada' }
        $inserted = @(Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
            @{ Id = 2; Name = 'Ada' }
            @{ Id = 3; Name = 'Grace' }
        ) -ConflictAction Ignore -PassThru)

        $inserted | Should -HaveCount 1
        $inserted[0].Name | Should -Be 'Grace'
    }

    It 'normalizes Boolean and DateTime values predictably' {
        $instant = [datetime]'2026-08-06T12:34:56.789Z'
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @{
            Id = 1; Name = 'Ada'; Active = $false; CreatedAt = $instant
        }

        $row = Get-SqliteRow -SQLiteConnection $connection -Table People
        $row.Active | Should -Be 0
        $row.CreatedAt | Should -Be '2026-08-06 12:34:56.789'
    }

    It 'rejects null, scalar, and empty row data' {
        { Add-SqliteRow -SQLiteConnection $connection -Table People -Data $null } | Should -Throw
        { Add-SqliteRow -SQLiteConnection $connection -Table People -Data 42 } | Should -Throw
        { Add-SqliteRow -SQLiteConnection $connection -Table People -Data @{} } | Should -Throw
    }

    It 'leaves a supplied connection open' {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @{ Id = 1; Name = 'Ada' }
        $connection.State | Should -Be 'Open'
    }

    It 'does not create or modify a database under WhatIf' {
        $path = Join-Path $TestDrive 'whatif.sqlite'
        Add-SqliteRow -DataSource $path -Table People -Data @{ Id = 1; Name = 'Ada' } -WhatIf
        Test-Path -LiteralPath $path | Should -BeFalse
    }

    It 'handles a large prepared batch in one call' {
        $data = @(1..1000 | ForEach-Object { @{ Id = $_; Name = "Person $_" } })
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data $data

        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Count | Should -Be 1000
    }
}

Context 'Get-SqliteRow' {
    BeforeEach {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
            @{ Id = 1; Name = 'Ada'; Active = $true; Note = $null }
            @{ Id = 2; Name = 'Grace'; Active = $true; Note = 'compiler' }
            @{ Id = 3; Name = 'Linus'; Active = $false; Note = $null }
            @{ Id = 4; Name = 'Margaret'; Active = $true; Note = 'apollo' }
        )
    }

    It 'joins structured equality filters with AND' {
        $row = Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Active = $true; Name = 'Grace' }
        $row.Id | Should -Be 2
    }

    It 'maps a null structured filter to IS NULL' {
        @(Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Note = $null }).Count | Should -Be 2
    }

    It 'supports custom predicates with normalized parameter markers' {
        $rows = @(Get-SqliteRow -SQLiteConnection $connection -Table People `
            -WhereSql 'Id >= @minimum AND Name <> @excluded' `
            -SqlParameters @{ '@minimum' = 2; ':excluded' = 'Linus' } `
            -OrderBy Id)
        $rows.Name | Should -Be @('Grace', 'Margaret')
    }

    It 'projects selected columns' {
        $row = Get-SqliteRow -SQLiteConnection $connection -Table People -Column Id, Name -Where @{ Id = 1 }
        $row.PSObject.Properties.Name | Should -Be @('Id', 'Name')
    }

    It 'applies descending order, limit, and offset' {
        $rows = @(Get-SqliteRow -SQLiteConnection $connection -Table People -OrderBy Id -Descending -Limit 2 -Offset 1)
        $rows.Id | Should -Be @(3, 2)
    }

    It 'requires Limit with Offset' {
        { Get-SqliteRow -SQLiteConnection $connection -Table People -Offset 1 } | Should -Throw '*Limit is required*'
    }

    It 'rejects ambiguous and unsafe filter inputs' {
        { Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Id = 1 } -WhereSql 'Id = 1' } |
            Should -Throw '*cannot be used together*'
        { Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Id = @(1, 2) } } |
            Should -Throw '*is a collection*'
        { Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Id = 1 } -SqlParameters @{ id = 1 } } |
            Should -Throw '*only be used with WhereSql*'
        { Get-SqliteRow -SQLiteConnection $connection -Table People -WhereSql 'Id = @__crud_bad' -SqlParameters @{ __crud_bad = 1 } } |
            Should -Throw '*reserved*'
    }

    It 'leaves a supplied connection open' {
        [void](Get-SqliteRow -SQLiteConnection $connection -Table People -Limit 1)
        $connection.State | Should -Be 'Open'
    }
}

Context 'Set-SqliteRow' {
    BeforeEach {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
            @{ Id = 1; Name = 'Ada'; Active = $true }
            @{ Id = 2; Name = 'Grace'; Active = $true }
            @{ Id = 3; Name = 'Linus'; Active = $true }
            @{ Id = 4; Name = 'Margaret'; Active = $true }
        )
    }

    It 'updates structured targets and returns the affected count' {
        $count = Set-SqliteRow -SQLiteConnection $connection -On People -Values @{ Active = $false } `
            -Where @{ Id = 2 } -PassThru -Confirm:$false
        $count | Should -Be 1
        (Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Id = 2 }).Active | Should -Be 0
    }

    It 'can set a column to null' {
        Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Note = $null } -Where @{ Id = 1 } -Confirm:$false
        (Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Id = 1 }).Note | Should -BeNullOrEmpty
    }

    It 'supports a parameterized custom predicate' {
        Set-SqliteRow -SQLiteConnection $connection -Table People -Data @{ Note = 'updated' } `
            -WhereSql 'Id >= @first' -SqlParameters @{ first = 3 } -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Note = 'updated' }).Count | Should -Be 2
    }

    It 'refuses missing and empty filters unless All is explicit' {
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = $false } -Confirm:$false } |
            Should -Throw '*Refusing an unscoped mutation*'
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = $false } -Where @{} -Confirm:$false } |
            Should -Throw '*Refusing an unscoped mutation*'
    }

    It 'rejects All combined with a filter' {
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = $false } -All -Where @{ Id = 1 } -Confirm:$false } |
            Should -Throw '*cannot be combined*'
    }

    It 'updates a deterministic limited window without compile-time SQLite support' {
        Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = $false } `
            -All -OrderBy Id -Descending -Limit 2 -Offset 1 -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Active = $false } -OrderBy Id).Id |
            Should -Be @(2, 3)
    }

    It 'uses rowid when a table has no primary key' {
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE NoKey (Sequence INTEGER, State TEXT)'
        Add-SqliteRow -SQLiteConnection $connection -Table NoKey -Data @(
            @{ Sequence = 3; State = 'old' }, @{ Sequence = 1; State = 'old' }, @{ Sequence = 2; State = 'old' }
        )
        Set-SqliteRow -SQLiteConnection $connection -Table NoKey -Values @{ State = 'new' } -All -OrderBy Sequence -Limit 1 -Confirm:$false
        (Get-SqliteRow -SQLiteConnection $connection -Table NoKey -Where @{ State = 'new' }).Sequence | Should -Be 1
    }

    It 'uses a composite primary key for WITHOUT ROWID tables' {
        Invoke-SqliteQuery -SQLiteConnection $connection -Query @'
CREATE TABLE Composite (Tenant TEXT, Sequence INTEGER, State TEXT, PRIMARY KEY (Tenant, Sequence)) WITHOUT ROWID
'@
        Add-SqliteRow -SQLiteConnection $connection -Table Composite -Data @(
            @{ Tenant = 'b'; Sequence = 1; State = 'old' }, @{ Tenant = 'a'; Sequence = 2; State = 'old' },
            @{ Tenant = 'a'; Sequence = 1; State = 'old' }
        )
        Set-SqliteRow -SQLiteConnection $connection -Table Composite -Values @{ State = 'new' } `
            -All -OrderBy Tenant, Sequence -Limit 1 -Confirm:$false
        $row = Get-SqliteRow -SQLiteConnection $connection -Table Composite -Where @{ State = 'new' }
        $row.Tenant | Should -Be 'a'
        $row.Sequence | Should -Be 1
    }

    It 'rejects nondeterministic paging combinations' {
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = 0 } -All -Limit 1 -Confirm:$false } |
            Should -Throw '*OrderBy is required*'
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = 0 } -All -OrderBy Id -Confirm:$false } |
            Should -Throw '*Limit is required*'
        { Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = 0 } -All -Offset 1 -Confirm:$false } |
            Should -Throw '*Limit is required*'
    }

    It 'honors WhatIf and leaves supplied connections open' {
        Set-SqliteRow -SQLiteConnection $connection -Table People -Values @{ Active = $false } -All -WhatIf
        @(Get-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Active = $true }).Count | Should -Be 4
        $connection.State | Should -Be 'Open'
    }
}

Context 'Remove-SqliteRow' {
    BeforeEach {
        Add-SqliteRow -SQLiteConnection $connection -Table People -Data @(
            @{ Id = 1; Name = 'Ada'; Active = $true; Note = $null }
            @{ Id = 2; Name = 'Grace'; Active = $false; Note = 'old' }
            @{ Id = 3; Name = 'Linus'; Active = $false; Note = $null }
            @{ Id = 4; Name = 'Margaret'; Active = $true; Note = 'old' }
        )
    }

    It 'deletes structured targets and returns the affected count' {
        $count = Remove-SqliteRow -SQLiteConnection $connection -On People -Where @{ Active = $false } `
            -PassThru -Confirm:$false
        $count | Should -Be 2
        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Count | Should -Be 2
    }

    It 'supports null filters and custom parameterized predicates' {
        Remove-SqliteRow -SQLiteConnection $connection -Table People -Where @{ Note = $null } -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Id | Should -Be @(2, 4)

        Remove-SqliteRow -SQLiteConnection $connection -Table People `
            -WhereSql 'Id >= @minimum' -SqlParameters @{ minimum = 4 } -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Id | Should -Be 2
    }

    It 'refuses missing and empty filters unless All is explicit' {
        { Remove-SqliteRow -SQLiteConnection $connection -Table People -Confirm:$false } |
            Should -Throw '*Refusing an unscoped mutation*'
        { Remove-SqliteRow -SQLiteConnection $connection -Table People -Where @{} -Confirm:$false } |
            Should -Throw '*Refusing an unscoped mutation*'
    }

    It 'deletes a deterministic limited window' {
        Remove-SqliteRow -SQLiteConnection $connection -Table People -All -OrderBy Id -Descending -Limit 2 -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People -OrderBy Id).Id | Should -Be @(1, 2)
    }

    It 'deletes from a composite WITHOUT ROWID table with Limit' {
        Invoke-SqliteQuery -SQLiteConnection $connection -Query @'
CREATE TABLE CompositeDelete (Tenant TEXT, Sequence INTEGER, PRIMARY KEY (Tenant, Sequence)) WITHOUT ROWID
'@
        Add-SqliteRow -SQLiteConnection $connection -Table CompositeDelete -Data @(
            @{ Tenant = 'b'; Sequence = 1 }, @{ Tenant = 'a'; Sequence = 2 }, @{ Tenant = 'a'; Sequence = 1 }
        )
        Remove-SqliteRow -SQLiteConnection $connection -Table CompositeDelete -All `
            -OrderBy Tenant, Sequence -Limit 1 -Confirm:$false
        $rows = @(Get-SqliteRow -SQLiteConnection $connection -Table CompositeDelete -OrderBy Tenant, Sequence)
        $rows | Should -HaveCount 2
        $rows[0].Tenant | Should -Be 'a'
        $rows[0].Sequence | Should -Be 2
    }

    It 'rejects limited mutation when every rowid alias is hidden and there is no primary key' {
        Invoke-SqliteQuery -SQLiteConnection $connection -Query 'CREATE TABLE HiddenRowId (rowid INTEGER, _rowid_ INTEGER, oid INTEGER, Value TEXT)'
        Add-SqliteRow -SQLiteConnection $connection -Table HiddenRowId -Data @{ rowid = 1; _rowid_ = 2; oid = 3; Value = 'x' }
        { Remove-SqliteRow -SQLiteConnection $connection -Table HiddenRowId -All -OrderBy Value -Limit 1 -Confirm:$false } |
            Should -Throw '*hides every rowid alias*'
    }

    It 'rejects All with a filter and nondeterministic paging' {
        { Remove-SqliteRow -SQLiteConnection $connection -Table People -All -Where @{ Id = 1 } -Confirm:$false } |
            Should -Throw '*cannot be combined*'
        { Remove-SqliteRow -SQLiteConnection $connection -Table People -All -Limit 1 -Confirm:$false } |
            Should -Throw '*OrderBy is required*'
        { Remove-SqliteRow -SQLiteConnection $connection -Table People -All -OrderBy Id -Confirm:$false } |
            Should -Throw '*Limit is required*'
    }

    It 'honors WhatIf and leaves supplied connections open' {
        Remove-SqliteRow -SQLiteConnection $connection -Table People -All -WhatIf
        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Count | Should -Be 4
        $connection.State | Should -Be 'Open'
    }

    It 'allows a fully explicit delete-all operation' {
        Remove-SqliteRow -SQLiteConnection $connection -Table People -All -Confirm:$false
        @(Get-SqliteRow -SQLiteConnection $connection -Table People).Count | Should -Be 0
    }
}
}
