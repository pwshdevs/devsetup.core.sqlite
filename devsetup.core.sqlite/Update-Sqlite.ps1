function Update-Sqlite {
    <#
    .SYNOPSIS
        Updates the bundled System.Data.SQLite provider and native SQLite library.

    .PARAMETER ProviderVersion
        The System.Data.SQLite NuGet package version to install.

    .PARAMETER SQLiteVersion
        The SQLite NuGet package version to install.

    .PARAMETER OS
        The runtime identifier to update. Defaults to the current platform.

    .PARAMETER InstallPath
        The devsetup.core.sqlite module directory. Defaults to the imported module's directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Alias('Version')]
        [string]
        $ProviderVersion = '2.0.4',

        [Parameter()]
        [string]
        $SQLiteVersion = '3.53.4',

        [Parameter()]
        [ValidateSet('linux-arm', 'linux-arm64', 'linux-x64', 'osx-arm64', 'osx-x64', 'win-arm64', 'win-x64', 'win-x86')]
        [string]
        $OS,

        [Parameter()]
        [string]
        $InstallPath
    )

    Process {
        if (-not $OS) {
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
            $module = Get-Module devsetup.core.sqlite
            if (-not $module) {
                throw 'Specify -InstallPath when devsetup.core.sqlite is not imported.'
            }

            $InstallPath = Split-Path $module.Path -Parent
        }

        $InstallPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallPath)
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

        if (-not $nativeFileNames.ContainsKey($OS)) {
            throw "devsetup.core.sqlite does not support the '$OS' runtime identifier."
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

            $coreTarget = Join-Path $InstallPath "core\$OS"
            $nativeFileName = $nativeFileNames[$OS]
            $nativeSource = Join-Path $sqlitePath "runtimes\$OS\native\$nativeFileName"
            New-Item -ItemType Directory -Path $coreTarget -Force | Out-Null

            Copy-Item `
                -LiteralPath (Join-Path $providerPath 'lib\netstandard2.0\System.Data.SQLite.dll') `
                -Destination (Join-Path $coreTarget 'System.Data.SQLite.dll') `
                -Force
            Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $coreTarget $nativeFileName) -Force

            $legacyInterop = Join-Path $coreTarget 'SQLite.Interop.dll'
            if (Test-Path -LiteralPath $legacyInterop) {
                Remove-Item -LiteralPath $legacyInterop -Force
            }

            if ($OS -in @('win-x64', 'win-x86')) {
                $architecture = $OS.Substring(4)
                $desktopTarget = Join-Path $InstallPath $architecture
                New-Item -ItemType Directory -Path $desktopTarget -Force | Out-Null

                Copy-Item `
                    -LiteralPath (Join-Path $providerPath 'lib\net471\System.Data.SQLite.dll') `
                    -Destination (Join-Path $desktopTarget 'System.Data.SQLite.dll') `
                    -Force
                Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $desktopTarget $nativeFileName) -Force

                $legacyInterop = Join-Path $desktopTarget 'SQLite.Interop.dll'
                if (Test-Path -LiteralPath $legacyInterop) {
                    Remove-Item -LiteralPath $legacyInterop -Force
                }
            }
        }
        finally {
            if (Test-Path -LiteralPath $buildPath) {
                Remove-Item -LiteralPath $buildPath -Recurse -Force
            }
        }

        Write-Warning 'Start a new PowerShell process before using the updated SQLite assemblies.'
    }
}
