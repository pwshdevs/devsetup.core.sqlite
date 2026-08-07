[CmdletBinding()]
param(
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$sourceModulePath = Join-Path -Path $ProjectRoot -ChildPath 'src/devsetup.core.sqlite'
$updaterPath = Join-Path -Path $ProjectRoot -ChildPath 'tools/Update-SqliteRuntime.ps1'
$dependencyPath = Join-Path -Path $ProjectRoot -ChildPath 'tools/SQLiteDependencies.psd1'
$dependencies = Import-PowerShellDataFile -LiteralPath $dependencyPath

$temporaryRoot = if ($env:RUNNER_TEMP) {
    [IO.Path]::GetFullPath($env:RUNNER_TEMP)
}
else {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
}
$candidatePath = [IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot "devsetup-core-sqlite-canary-$([Guid]::NewGuid().ToString('N'))")
)
if (-not $candidatePath.StartsWith(
        $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "The SQLite canary path is outside the temporary directory: $candidatePath"
}
if (Test-Path -LiteralPath $candidatePath) {
    throw "The SQLite canary path already exists: $candidatePath"
}

$nativeFileNames = @{
    'linux-arm'   = 'libe_sqlite3.so'
    'linux-arm64' = 'libe_sqlite3.so'
    'linux-x64'   = 'libe_sqlite3.so'
    'osx-arm64'   = 'libe_sqlite3.dylib'
    'osx-x64'     = 'libe_sqlite3.dylib'
    'win-arm64'   = 'e_sqlite3.dll'
    'win-x64'     = 'e_sqlite3.dll'
    'win-x86'     = 'e_sqlite3.dll'
}

try {
    Copy-Item -LiteralPath $sourceModulePath -Destination $candidatePath -Recurse
    $updates = @(& $updaterPath -InstallPath $candidatePath -All -ErrorAction Stop)
    if ($updates.Count -ne $nativeFileNames.Count) {
        throw "Expected $($nativeFileNames.Count) runtime updates; received $($updates.Count)."
    }

    foreach ($runtimeIdentifier in $nativeFileNames.Keys) {
        $update = $updates | Where-Object RuntimeIdentifier -eq $runtimeIdentifier
        if (@($update).Count -ne 1) {
            throw "Expected one updater result for $runtimeIdentifier."
        }

        $sourceRuntimePath = Join-Path (Join-Path $sourceModulePath 'core') $runtimeIdentifier
        $candidateRuntimePath = Join-Path (Join-Path $candidatePath 'core') $runtimeIdentifier
        foreach ($fileName in 'System.Data.SQLite.dll', $nativeFileNames[$runtimeIdentifier]) {
            $sourcePath = Join-Path $sourceRuntimePath $fileName
            $candidateFilePath = Join-Path $candidateRuntimePath $fileName
            if (-not (Test-Path -LiteralPath $candidateFilePath -PathType Leaf)) {
                throw "The updater did not create $candidateFilePath."
            }
            if ((Get-FileHash -LiteralPath $sourcePath).Hash -ne
                (Get-FileHash -LiteralPath $candidateFilePath).Hash) {
                throw "The pinned $runtimeIdentifier/$fileName asset is not reproducible."
            }
        }
    }

    foreach ($architecture in 'x64', 'x86') {
        foreach ($fileName in 'System.Data.SQLite.dll', 'e_sqlite3.dll') {
            $sourcePath = Join-Path (Join-Path $sourceModulePath $architecture) $fileName
            $candidateFilePath = Join-Path (Join-Path $candidatePath $architecture) $fileName
            if ((Get-FileHash -LiteralPath $sourcePath).Hash -ne
                (Get-FileHash -LiteralPath $candidateFilePath).Hash) {
                throw "The pinned Windows PowerShell $architecture/$fileName asset is not reproducible."
            }
        }
    }

    [pscustomobject]@{
        ProviderVersion = $dependencies.ProviderVersion
        SQLiteVersion   = $dependencies.SQLiteVersion
        RuntimeCount    = $updates.Count
        Reproducible    = $true
    }
}
finally {
    if (Test-Path -LiteralPath $candidatePath) {
        $resolvedCandidatePath = [IO.Path]::GetFullPath(
            (Resolve-Path -LiteralPath $candidatePath).Path
        )
        if (-not $resolvedCandidatePath.StartsWith(
                $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Refusing to remove a path outside the temporary directory: $resolvedCandidatePath"
        }
        Remove-Item -LiteralPath $resolvedCandidatePath -Recurse -Force
    }
}
