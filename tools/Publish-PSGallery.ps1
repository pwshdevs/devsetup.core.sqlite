[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ModuleName = 'devsetup.core.sqlite',

    [string]$Repository = 'PSGallery',

    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$manifestPath = Join-Path -Path $projectRoot -ChildPath "src/$ModuleName/$ModuleName.psd1"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Module manifest not found: $manifestPath"
}

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$localVersion = [version]$manifest.ModuleVersion

if ([string]::IsNullOrWhiteSpace($env:PSGALLERY_API_KEY)) {
    $decision = [pscustomobject]@{
        ModuleName       = $ModuleName
        LocalVersion     = $localVersion
        PublishedVersion = $null
        Repository       = $Repository
        ShouldPublish    = $false
        SkipReason       = 'MissingApiKey'
    }
    Write-Host 'PSGALLERY_API_KEY is not configured. Skipping publication.'
    if ($PassThru) {
        $decision
    }
    return
}

$publishedModule = $null

try {
    if (Get-Command -Name Find-PSResource -ErrorAction SilentlyContinue) {
        $publishedModule = Find-PSResource -Name $ModuleName -Repository $Repository -ErrorAction Stop
    } elseif (Get-Command -Name Find-Module -ErrorAction SilentlyContinue) {
        $publishedModule = Find-Module -Name $ModuleName -Repository $Repository -ErrorAction Stop
    } else {
        throw 'Neither Find-PSResource nor Find-Module is available.'
    }
} catch {
    if ($_.CategoryInfo.Category -ne [System.Management.Automation.ErrorCategory]::ObjectNotFound) {
        throw
    }
}

$publishedVersion = if ($publishedModule) { [version]$publishedModule.Version } else { $null }
$shouldPublish = -not $publishedVersion -or $localVersion -gt $publishedVersion
$decision = [pscustomobject]@{
    ModuleName       = $ModuleName
    LocalVersion     = $localVersion
    PublishedVersion = $publishedVersion
    Repository       = $Repository
    ShouldPublish    = $shouldPublish
    SkipReason       = if ($shouldPublish) { $null } else { 'NotNewer' }
}

if (-not $shouldPublish) {
    Write-Host "$ModuleName $localVersion is not newer than $Repository version $publishedVersion. Skipping publication."
} elseif ($PSCmdlet.ShouldProcess("$Repository/$ModuleName", "Publish version $localVersion")) {
    $powerShellPath = (Get-Process -Id $PID).Path
    Push-Location -LiteralPath $projectRoot
    try {
        & $powerShellPath -NoLogo -NoProfile -File './build.ps1' -Task Publish -Bootstrap
        if ($LASTEXITCODE -ne 0) {
            throw "The Publish build task failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

if ($PassThru) {
    $decision
}

