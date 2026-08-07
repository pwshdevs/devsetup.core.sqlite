<#
.SYNOPSIS
    Updates the SQLite runtime assets bundled with the repository.

.DESCRIPTION
    Maintainer tool that downloads System.Data.SQLite and SQLite packages from NuGet, then
    replaces the managed and native assets for one or every supported runtime. By default,
    versions come from tools/SQLiteDependencies.psd1 and the repository source module is updated.

.PARAMETER ProviderVersion
    The System.Data.SQLite NuGet package version to install.

.PARAMETER SQLiteVersion
    The SQLite NuGet package version to install.

.PARAMETER OS
    The runtime identifier to update. Defaults to the current platform.

.PARAMETER All
    Updates every supported runtime from one set of downloaded packages.

.PARAMETER InstallPath
    The source module directory to update. Defaults to src/devsetup.core.sqlite in this repository.

.EXAMPLE
    ./tools/Update-SqliteRuntime.ps1 -OS linux-arm64

    Updates the Linux ARM64 runtime using the pinned package versions.

.EXAMPLE
    ./tools/Update-SqliteRuntime.ps1 -All

    Refreshes all bundled runtimes for a canary candidate or release.

.OUTPUTS
    PSCustomObject describing each updated runtime.

.LINK
    https://github.com/pwshdevs/devsetup.core.sqlite
#>
[CmdletBinding()]
param(
    [Parameter()]
    [Alias('Version')]
    [string]
    $ProviderVersion,

    [Parameter()]
    [string]
    $SQLiteVersion,

    [Parameter()]
    [ValidateSet('linux-arm', 'linux-arm64', 'linux-x64', 'osx-arm64', 'osx-x64', 'win-arm64', 'win-x64', 'win-x86')]
    [string]
    $OS,

    [Parameter()]
    [switch]
    $All,

    [Parameter()]
    [string]
    $InstallPath
)

Process {
        $dependencyPath = Join-Path -Path $PSScriptRoot -ChildPath 'SQLiteDependencies.psd1'
        $dependencies = Import-PowerShellDataFile -LiteralPath $dependencyPath
        if (-not $ProviderVersion) {
            $ProviderVersion = $dependencies.ProviderVersion
        }
        if (-not $SQLiteVersion) {
            $SQLiteVersion = $dependencies.SQLiteVersion
        }
        if ($All -and $PSBoundParameters.ContainsKey('OS')) {
            throw 'Specify either -All or -OS, not both.'
        }

        if (-not $All -and -not $OS) {
            $architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()

            if ($PSEdition -eq 'Core' -and $IsLinux) {
                $OS = "linux-$architecture"
            }
            elseif ($PSEdition -eq 'Core' -and $IsMacOS) {
                $OS = "osx-$architecture"
            }
            elseif ($IsWindows -or $PSEdition -ne 'Core') {
                $OS = "win-$architecture"
            }
            else {
                throw 'Unable to determine the current operating system. Specify -OS explicitly.'
            }
        }

        if (-not $InstallPath) {
            $repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            $InstallPath = Join-Path -Path $repositoryRoot -ChildPath 'src/devsetup.core.sqlite'
        }

        $InstallPath = (Resolve-Path -LiteralPath $InstallPath -ErrorAction Stop).Path
        $buildPath = Join-Path ([IO.Path]::GetTempPath()) ("devsetup.core.sqlite-{0}" -f [Guid]::NewGuid().ToString('N'))
        $providerArchive = Join-Path $buildPath "System.Data.SQLite.$ProviderVersion.zip"
        $providerPath = Join-Path $buildPath 'provider'
        $sqliteArchive = Join-Path $buildPath "SQLite.$SQLiteVersion.zip"
        $sqlitePath = Join-Path $buildPath 'sqlite'

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

        if (-not $All -and -not $nativeFileNames.ContainsKey($OS)) {
            throw "devsetup.core.sqlite does not support the '$OS' runtime identifier."
        }

        $runtimeIdentifiers = if ($All) {
            @($nativeFileNames.Keys | Sort-Object)
        }
        else {
            @($OS)
        }

        try {
            Write-Verbose "Downloading System.Data.SQLite $ProviderVersion and SQLite $SQLiteVersion from NuGet."
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            New-Item -ItemType Directory -Path $providerPath, $sqlitePath -Force | Out-Null

            Invoke-WebRequest -UseBasicParsing `
                -Uri "https://www.nuget.org/api/v2/package/System.Data.SQLite/$ProviderVersion" `
                -OutFile $providerArchive
            Invoke-WebRequest -UseBasicParsing `
                -Uri "https://www.nuget.org/api/v2/package/SQLite/$SQLiteVersion" `
                -OutFile $sqliteArchive

            Expand-Archive -LiteralPath $providerArchive -DestinationPath $providerPath
            Expand-Archive -LiteralPath $sqliteArchive -DestinationPath $sqlitePath

            $providerNetStandardPath = Join-Path (Join-Path (Join-Path $providerPath 'lib') 'netstandard2.0') 'System.Data.SQLite.dll'
            $providerDesktopPath = Join-Path (Join-Path (Join-Path $providerPath 'lib') 'net471') 'System.Data.SQLite.dll'
            foreach ($providerAsset in $providerNetStandardPath, $providerDesktopPath) {
                if (-not (Test-Path -LiteralPath $providerAsset -PathType Leaf)) {
                    throw "The provider package does not contain the expected asset: $providerAsset"
                }
            }

            $nativeSources = @{}
            foreach ($runtimeIdentifier in $runtimeIdentifiers) {
                $nativeFileName = $nativeFileNames[$runtimeIdentifier]
                $nativeSource = Join-Path (Join-Path (Join-Path (Join-Path $sqlitePath 'runtimes') $runtimeIdentifier) 'native') $nativeFileName
                if (-not (Test-Path -LiteralPath $nativeSource -PathType Leaf)) {
                    throw "The SQLite package does not contain the expected $runtimeIdentifier asset: $nativeSource"
                }
                $nativeSources[$runtimeIdentifier] = $nativeSource
            }

            foreach ($runtimeIdentifier in $runtimeIdentifiers) {
                $coreTarget = Join-Path (Join-Path $InstallPath 'core') $runtimeIdentifier
                $nativeFileName = $nativeFileNames[$runtimeIdentifier]
                $nativeSource = $nativeSources[$runtimeIdentifier]
                New-Item -ItemType Directory -Path $coreTarget -Force | Out-Null

                Copy-Item `
                    -LiteralPath $providerNetStandardPath `
                    -Destination (Join-Path $coreTarget 'System.Data.SQLite.dll') `
                    -Force
                Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $coreTarget $nativeFileName) -Force

                $legacyInterop = Join-Path $coreTarget 'SQLite.Interop.dll'
                if (Test-Path -LiteralPath $legacyInterop) {
                    Remove-Item -LiteralPath $legacyInterop -Force
                }

                $desktopTarget = $null
                if ($runtimeIdentifier -in @('win-x64', 'win-x86')) {
                    $architecture = $runtimeIdentifier.Substring(4)
                    $desktopTarget = Join-Path $InstallPath $architecture
                    New-Item -ItemType Directory -Path $desktopTarget -Force | Out-Null

                    Copy-Item `
                        -LiteralPath $providerDesktopPath `
                        -Destination (Join-Path $desktopTarget 'System.Data.SQLite.dll') `
                        -Force
                    Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $desktopTarget $nativeFileName) -Force

                    $legacyInterop = Join-Path $desktopTarget 'SQLite.Interop.dll'
                    if (Test-Path -LiteralPath $legacyInterop) {
                        Remove-Item -LiteralPath $legacyInterop -Force
                    }
                }

                [pscustomobject]@{
                    RuntimeIdentifier = $runtimeIdentifier
                    ProviderVersion   = $ProviderVersion
                    SQLiteVersion     = $SQLiteVersion
                    ManagedPath       = Join-Path $coreTarget 'System.Data.SQLite.dll'
                    NativePath        = Join-Path $coreTarget $nativeFileName
                    DesktopPath       = $desktopTarget
                }
            }
        }
        finally {
            if (Test-Path -LiteralPath $buildPath) {
                Remove-Item -LiteralPath $buildPath -Recurse -Force
            }
        }

        Write-Warning 'Start a new PowerShell process before loading the updated SQLite assemblies.'
    }
