[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'sql-file-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

$sqlPath = Join-Path $PSScriptRoot 'Advanced.schema.sql'
New-SqliteDatabase -Path $DatabasePath -InputFile $sqlPath

Add-SqliteRow -DataSource $DatabasePath -On Authors -Data @{ Id = 1; DisplayName = 'PowerShell Author' }
Add-SqliteRow -DataSource $DatabasePath -On Articles -Data @{
    Id = 1
    AuthorId = 1
    Slug = 'reliable-sqlite-automation'
    Title = 'Reliable SQLite Automation'
}
Add-SqliteRow -DataSource $DatabasePath -On Tags -Data @(
    @{ Name = 'powershell' }
    @{ Name = 'sqlite' }
)
Add-SqliteRow -DataSource $DatabasePath -On ArticleTags -Data @(
    @{ ArticleId = 1; TagName = 'powershell' }
    @{ ArticleId = 1; TagName = 'sqlite' }
)
Set-SqliteRow -DataSource $DatabasePath -On Articles -Values @{
    Status = 'published'
    PublishedAt = '2026-08-07 12:00:00.000'
} -Where @{ Id = 1 } -Confirm:$false

Invoke-SqliteQuery -DataSource $DatabasePath -Query 'SELECT * FROM PublishedArticles' -As PSObject
