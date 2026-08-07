[CmdletBinding()]
param(
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ProjectTest {
    param(
        [string]$Path,
        [string]$PowerShellPath
    )

    $buildPath = Join-Path -Path $Path -ChildPath 'build.ps1'
    $hadGitHubWorkspace = Test-Path -LiteralPath Env:GITHUB_WORKSPACE
    $originalGitHubWorkspace = $env:GITHUB_WORKSPACE
    Push-Location -LiteralPath $Path
    try {
        # BuildHelpers prioritizes GITHUB_WORKSPACE over the current directory.
        # Point it at the project under test so generated modules do not inherit
        # the parent repository's build and test paths on GitHub-hosted runners.
        $env:GITHUB_WORKSPACE = $Path
        & $PowerShellPath -NoLogo -NoProfile -ExecutionPolicy Bypass `
            -File $buildPath -Task Test -Bootstrap
        if ($LASTEXITCODE -ne 0) {
            throw "Tests failed in $Path with exit code $LASTEXITCODE."
        }
    } finally {
        if ($hadGitHubWorkspace) {
            $env:GITHUB_WORKSPACE = $originalGitHubWorkspace
        } else {
            Remove-Item -LiteralPath Env:GITHUB_WORKSPACE -ErrorAction SilentlyContinue
        }
        Pop-Location
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$powerShellPath = (Get-Process -Id $PID).Path
$sourceRoot = Join-Path -Path $ProjectRoot -ChildPath 'src'
$moduleRoots = @(
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $sourceRoot -Directory
    }
    Get-ChildItem -LiteralPath $ProjectRoot -Directory |
        Where-Object Name -ne 'src'
)
$manifestPaths = @(
    $moduleRoots |
        ForEach-Object {
            $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $candidate
            }
        }
)
if ($manifestPaths.Count -ne 1) {
    throw "Expected one project module manifest; found $($manifestPaths.Count)."
}

$manifestPath = $manifestPaths[0]
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestPath)

Invoke-ProjectTest -Path $ProjectRoot -PowerShellPath $powerShellPath

$builtManifestPath = Join-Path -Path $ProjectRoot `
    -ChildPath "Output/$moduleName/$($manifest.ModuleVersion)/$moduleName.psd1"
if (-not (Test-Path -LiteralPath $builtManifestPath -PathType Leaf)) {
    throw "The built module manifest was not found at $builtManifestPath."
}

Import-Module -Name $builtManifestPath -Force -ErrorAction Stop
$generatorCommand = Get-Command -Name New-LathModule -Module $moduleName -ErrorAction SilentlyContinue
if (-not $generatorCommand) {
    return
}

$generatedModuleName = 'LathCanaryModule'
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$generatedProjectPath = Join-Path -Path $tempRoot -ChildPath "$generatedModuleName-$PID"

try {
    $templateParameters = @{
        ModuleName   = $generatedModuleName
        Description  = 'PSLath dependency canary module'
        Version      = '0.1.0'
        FullName     = 'PSLath Canary'
        License      = 'MIT'
        CoC          = 'No'
        MkDocs       = 'No'
        Classes      = 'Yes'
        PlatyPS      = 'Yes'
        devcontainer = 'No'
        CICD         = 'GitHubActions'
    }

    New-LathModule `
        -DestinationPath $generatedProjectPath `
        -TemplateParameters $templateParameters `
        -Force `
        -NoLogo `
        -ErrorAction Stop | Out-Null

    Invoke-ProjectTest -Path $generatedProjectPath -PowerShellPath $powerShellPath

    $generatedManifestPath = Join-Path -Path $generatedProjectPath `
        -ChildPath "src/$generatedModuleName/$generatedModuleName.psd1"
    $generatedManifest = Import-PowerShellDataFile -LiteralPath $generatedManifestPath
    $generatedBuildManifestPath = Join-Path -Path $generatedProjectPath `
        -ChildPath "Output/$generatedModuleName/$($generatedManifest.ModuleVersion)/$generatedModuleName.psd1"
    if (-not (Test-Path -LiteralPath $generatedBuildManifestPath -PathType Leaf)) {
        throw "The generated module build was not found at $generatedBuildManifestPath."
    }
} finally {
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $generatedProjectPath) {
        Remove-Item -LiteralPath $generatedProjectPath -Recurse -Force
    }
}

