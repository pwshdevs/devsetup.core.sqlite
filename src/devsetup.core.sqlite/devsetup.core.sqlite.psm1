function Get-DevSetupSQLiteRuntimeIdentifier {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('linux', 'osx', 'win')]
        [string]$Platform,

        [Parameter(Mandatory)]
        [string]$Architecture
    )

    $runtimeIdentifier = '{0}-{1}' -f $Platform, $Architecture.ToLowerInvariant()
    $supportedRuntimeIdentifiers = @(
        'linux-arm'
        'linux-arm64'
        'linux-x64'
        'osx-arm64'
        'osx-x64'
        'win-arm64'
        'win-x64'
        'win-x86'
    )

    if ($runtimeIdentifier -notin $supportedRuntimeIdentifiers) {
        throw "devsetup.core.sqlite does not include native SQLite binaries for '$runtimeIdentifier'."
    }

    $runtimeIdentifier
}

$processArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()

if ($PSEdition -eq 'Core') {
    if ($IsLinux) {
        $runtimePlatform = 'linux'
    } elseif ($IsMacOS) {
        $runtimePlatform = 'osx'
    } elseif ($IsWindows) {
        $runtimePlatform = 'win'
    } else {
        throw 'devsetup.core.sqlite does not support this operating system.'
    }

    $runtimeIdentifier = Get-DevSetupSQLiteRuntimeIdentifier -Platform $runtimePlatform -Architecture $processArchitecture
    Write-Verbose "Loading the $runtimeIdentifier PowerShell Core provider."
    $SQLiteAssembly = Join-Path $PSScriptRoot "core/$runtimeIdentifier/System.Data.SQLite.dll"
} elseif ($processArchitecture -eq 'X64') {
    Write-Verbose 'Loading the x64 Windows PowerShell provider.'
    $SQLiteAssembly = Join-Path $PSScriptRoot 'x64/System.Data.SQLite.dll'
} elseif ($processArchitecture -eq 'X86') {
    Write-Verbose 'Loading the x86 Windows PowerShell provider.'
    $SQLiteAssembly = Join-Path $PSScriptRoot 'x86/System.Data.SQLite.dll'
} else {
    throw "devsetup.core.sqlite does not support Windows PowerShell on $processArchitecture. Use PowerShell 7 for ARM64 support."
}

if (-not (Test-Path -LiteralPath $SQLiteAssembly -PathType Leaf)) {
    throw "The bundled System.Data.SQLite provider was not found at '$SQLiteAssembly'."
}

try {
    Add-Type -Path $SQLiteAssembly -ErrorAction Stop
} catch {
    throw "Unable to load the bundled System.Data.SQLite provider at '$SQLiteAssembly': $($_.Exception.Message)"
}

if (-not ('DevSetup.Core.SQLite.DBNullScrubber' -as [type])) {
    $sqliteSupportAssembly = Join-Path $PSScriptRoot 'lib/devsetup.core.sqlite.Support.dll'
    if (-not (Test-Path -LiteralPath $sqliteSupportAssembly -PathType Leaf)) {
        throw "The bundled devsetup.core.sqlite support assembly was not found at '$sqliteSupportAssembly'."
    }

    try {
        [void][System.Reflection.Assembly]::LoadFrom($sqliteSupportAssembly)
    } catch {
        throw "Unable to load the devsetup.core.sqlite support assembly at '$sqliteSupportAssembly': $($_.Exception.Message)"
    }

    if (-not ('DevSetup.Core.SQLite.DBNullScrubber' -as [type])) {
        throw "The support assembly at '$sqliteSupportAssembly' does not contain DevSetup.Core.SQLite.DBNullScrubber."
    }
}

# Dot source private/public functions. Missing or empty directories are valid.
$getScriptFiles = {
    param([Parameter(Mandatory)][string]$Directory)

    $directoryPath = Join-Path -Path $PSScriptRoot -ChildPath $Directory
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
        Get-ChildItem -LiteralPath $directoryPath -Filter '*.ps1' -File -Recurse -ErrorAction Stop |
            Sort-Object -Property FullName
    }
}

$private = @(& $getScriptFiles -Directory 'Private')
$public  = @(& $getScriptFiles -Directory 'Public')
foreach ($import in @($private + $public)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $public.Basename
