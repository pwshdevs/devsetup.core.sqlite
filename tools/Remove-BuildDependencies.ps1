[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot,

    [switch]$AllowPreinstalledModules
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$requirementsPaths = @((Join-Path -Path $ProjectRoot -ChildPath 'requirements.psd1'))
$moduleNames = @('PSDepend')
$preservedPesterMajorVersion = 3
$sourceRoot = Join-Path -Path $ProjectRoot -ChildPath 'src'
$moduleRoots = @(
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $sourceRoot -Directory
    }
    Get-ChildItem -LiteralPath $ProjectRoot -Directory |
        Where-Object Name -ne 'src'
)
$manifestCandidates = @(
    $moduleRoots |
        ForEach-Object {
            $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $candidate
            }
        }
)
if ($manifestCandidates.Count -eq 1) {
    $manifestData = Import-PowerShellDataFile -LiteralPath $manifestCandidates[0]
    foreach ($requiredModule in @($manifestData.RequiredModules)) {
        if ($requiredModule -is [string]) {
            $moduleNames += $requiredModule
        } elseif ($requiredModule.ModuleName) {
            $moduleNames += [string]$requiredModule.ModuleName
        }
    }

    $templateRequirements = Join-Path -Path (Split-Path -Path $manifestCandidates[0] -Parent) `
        -ChildPath 'template/requirements.psd1'
    if (Test-Path -LiteralPath $templateRequirements -PathType Leaf) {
        $requirementsPaths += $templateRequirements
    }
}

foreach ($path in $requirementsPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }

    $requirements = Import-PowerShellDataFile -LiteralPath $path
    $moduleNames += @($requirements.Keys | Where-Object { $_ -ne 'PSDependOptions' })
}
$moduleNames = @($moduleNames | Sort-Object -Unique)
$cleanPester = $moduleNames -contains 'Pester'
$moduleNames = @($moduleNames | Where-Object { $_ -ne 'Pester' })

foreach ($moduleName in $moduleNames) {
    Get-Module -Name $moduleName | Remove-Module -Force -ErrorAction SilentlyContinue
}
if ($cleanPester) {
    Get-Module -Name Pester |
        Where-Object { $_.Version.Major -ne $preservedPesterMajorVersion } |
        Remove-Module -Force -ErrorAction SilentlyContinue
}

$moduleRoots = @(
    $env:PSModulePath -split [System.IO.Path]::PathSeparator |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            try {
                [System.IO.Path]::GetFullPath($_.TrimEnd([System.IO.Path]::DirectorySeparatorChar))
            } catch {
                Write-Verbose "Ignoring malformed PSModulePath entry: $_"
            }
        } |
        Sort-Object -Unique
)

foreach ($moduleRoot in $moduleRoots) {
    foreach ($moduleName in $moduleNames) {
        $modulePath = Join-Path -Path $moduleRoot -ChildPath $moduleName
        if (Test-Path -LiteralPath $modulePath -PathType Container) {
            if ($PSCmdlet.ShouldProcess($modulePath, 'Remove preinstalled build dependency')) {
                try {
                    Remove-Item -LiteralPath $modulePath -Recurse -Force
                } catch {
                    if (-not $AllowPreinstalledModules) {
                        throw
                    }
                    Write-Warning "Unable to remove protected preinstalled module path: $modulePath"
                }
            }
        }
    }
}

if ($cleanPester) {
    $pesterModulePaths = @(
        Get-Module -Name Pester -ListAvailable |
            Where-Object { $_.Version.Major -ne $preservedPesterMajorVersion } |
            Select-Object -ExpandProperty ModuleBase -Unique
    )
    foreach ($pesterModulePath in $pesterModulePaths) {
        $resolvedPesterPath = [System.IO.Path]::GetFullPath($pesterModulePath)
        $versionDirectoryName = Split-Path -Path $resolvedPesterPath -Leaf
        $pesterDirectoryName = Split-Path -Path (Split-Path -Path $resolvedPesterPath -Parent) -Leaf
        $parsedVersion = $null
        $isVersionDirectory = [version]::TryParse($versionDirectoryName, [ref]$parsedVersion)
        if ($pesterDirectoryName -ne 'Pester' -or -not $isVersionDirectory) {
            $message = "Refusing to remove unexpected Pester module path: $resolvedPesterPath"
            if (-not $AllowPreinstalledModules) {
                throw $message
            }
            Write-Warning $message
            continue
        }

        if ($PSCmdlet.ShouldProcess($resolvedPesterPath, 'Remove non-inbox Pester dependency')) {
            try {
                Remove-Item -LiteralPath $resolvedPesterPath -Recurse -Force
            } catch {
                if (-not $AllowPreinstalledModules) {
                    throw
                }
                Write-Warning "Unable to remove protected Pester module path: $resolvedPesterPath"
            }
        }
    }
}

$remaining = @(
    foreach ($moduleRoot in $moduleRoots) {
        foreach ($moduleName in $moduleNames) {
            $modulePath = Join-Path -Path $moduleRoot -ChildPath $moduleName
            if (Test-Path -LiteralPath $modulePath -PathType Container) {
                $modulePath
            }
        }
    }
    if ($cleanPester) {
        Get-Module -Name Pester -ListAvailable |
            Where-Object { $_.Version.Major -ne $preservedPesterMajorVersion } |
            Select-Object -ExpandProperty ModuleBase -Unique
    }
)
if ($remaining.Count -gt 0) {
    $message = "Unable to remove build dependencies: $($remaining -join ', ')"
    if (-not $AllowPreinstalledModules) {
        throw $message
    }
    Write-Warning $message
}

$removedDescription = @($moduleNames)
if ($cleanPester) {
    $removedDescription += "Pester except major version $preservedPesterMajorVersion"
}
Write-Host "Removed all installed versions of: $($removedDescription -join ', ')"

