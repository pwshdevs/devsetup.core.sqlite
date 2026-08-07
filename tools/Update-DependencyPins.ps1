[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot,

    [string]$ModuleManifestPath,

    [version]$ProposedVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProjectManifestPath {
    param([string]$Root)

    $sourceRoot = Join-Path -Path $Root -ChildPath 'src'
    $moduleRoots = @(
        if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
            Get-ChildItem -LiteralPath $sourceRoot -Directory
        }
        Get-ChildItem -LiteralPath $Root -Directory |
            Where-Object Name -ne 'src'
    )
    $candidates = @(
        $moduleRoots |
            ForEach-Object {
                $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $candidate
                }
            }
    )
    if ($candidates.Count -ne 1) {
        throw "Expected one project module manifest beneath $Root; found $($candidates.Count)."
    }

    $candidates[0]
}

function Get-DataFileHashtableAst {
    param(
        [string]$Content,
        [string]$Path
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content,
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "Unable to parse $Path`: $($parseErrors[0].Message)"
    }

    $hashtable = $ast.Find(
        { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
        $false
    )
    if (-not $hashtable) {
        throw "No root hashtable was found in $Path."
    }

    $hashtable
}

function Get-HashtablePair {
    param(
        [System.Management.Automation.Language.HashtableAst]$Hashtable,
        [string]$Key
    )

    @(
        $Hashtable.KeyValuePairs |
            Where-Object { $_.Item1.Value -eq $Key }
    ) | Select-Object -First 1
}

function Get-PairStringAst {
    param($Pair)

    $Pair.Item2.Find(
        { param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] },
        $true
    )
}

function ConvertTo-ReplacedContent {
    param(
        [string]$Content,
        [object[]]$Replacement
    )

    foreach ($item in @($Replacement | Sort-Object StartOffset -Descending)) {
        $Content = $Content.Substring(0, $item.StartOffset) +
            $item.Text +
            $Content.Substring($item.EndOffset)
    }

    $Content
}

function Get-RequirementModuleName {
    param(
        [string]$Content,
        [string]$Path
    )

    $hashtable = Get-DataFileHashtableAst -Content $Content -Path $Path
    @(
        $hashtable.KeyValuePairs |
            ForEach-Object { $_.Item1.Value } |
            Where-Object { $_ -ne 'PSDependOptions' }
    )
}

function ConvertTo-RequirementVersionContent {
    param(
        [string]$Content,
        [string]$Path,
        [hashtable]$Version,
        [switch]$Latest
    )

    $hashtable = Get-DataFileHashtableAst -Content $Content -Path $Path
    $replacements = @()

    foreach ($pair in $hashtable.KeyValuePairs) {
        $moduleName = [string]$pair.Item1.Value
        if ($moduleName -eq 'PSDependOptions') {
            continue
        }
        if (-not $Latest -and -not $Version.ContainsKey($moduleName)) {
            throw "No initialized version was found for build dependency $moduleName."
        }

        $nestedHashtable = $pair.Item2.Find(
            { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
            $true
        )
        $versionAst = if ($nestedHashtable) {
            $versionPair = Get-HashtablePair -Hashtable $nestedHashtable -Key 'Version'
            if (-not $versionPair) {
                throw "The $moduleName entry in $Path does not contain a Version property."
            }
            Get-PairStringAst -Pair $versionPair
        } else {
            Get-PairStringAst -Pair $pair
        }
        if (-not $versionAst) {
            throw "The version value for $moduleName in $Path is not a string."
        }

        $newVersion = if ($Latest) { 'latest' } else { $Version[$moduleName] }
        $replacements += [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset   = $versionAst.Extent.EndOffset
            Text        = "'$newVersion'"
        }
    }

    ConvertTo-ReplacedContent -Content $Content -Replacement $replacements
}

function Get-RequiredModuleSpecification {
    param(
        [string]$Content,
        [string]$Path
    )

    $rootHashtable = Get-DataFileHashtableAst -Content $Content -Path $Path
    $requiredModulesPair = Get-HashtablePair -Hashtable $rootHashtable -Key 'RequiredModules'
    if (-not $requiredModulesPair) {
        return @()
    }

    @(
        $requiredModulesPair.Item2.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
            $true
        ) |
            ForEach-Object {
                $namePair = Get-HashtablePair -Hashtable $_ -Key 'ModuleName'
                $versionPair = Get-HashtablePair -Hashtable $_ -Key 'RequiredVersion'
                if (-not $versionPair) {
                    $versionPair = Get-HashtablePair -Hashtable $_ -Key 'ModuleVersion'
                }
                if ($namePair -and $versionPair) {
                    [pscustomobject]@{
                        ModuleName  = [string](Get-PairStringAst -Pair $namePair).Value
                        VersionPair = $versionPair
                    }
                }
            }
    )
}

function ConvertTo-RequiredModuleContent {
    param(
        [string]$Content,
        [string]$Path,
        [hashtable]$Version
    )

    $replacements = @()
    foreach ($specification in Get-RequiredModuleSpecification -Content $Content -Path $Path) {
        if (-not $Version.ContainsKey($specification.ModuleName)) {
            throw "No initialized version was found for required module $($specification.ModuleName)."
        }

        $versionAst = Get-PairStringAst -Pair $specification.VersionPair
        if ($specification.VersionPair.Item1.Value -ne 'RequiredVersion') {
            $replacements += [pscustomobject]@{
                StartOffset = $specification.VersionPair.Item1.Extent.StartOffset
                EndOffset   = $specification.VersionPair.Item1.Extent.EndOffset
                Text        = 'RequiredVersion'
            }
        }
        $replacements += [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset   = $versionAst.Extent.EndOffset
            Text        = "'$($Version[$specification.ModuleName])'"
        }
    }

    ConvertTo-ReplacedContent -Content $Content -Replacement $replacements
}

function ConvertTo-ManifestVersionContent {
    param(
        [string]$Content,
        [string]$Path,
        [version]$Version
    )

    $hashtable = Get-DataFileHashtableAst -Content $Content -Path $Path
    $versionPair = Get-HashtablePair -Hashtable $hashtable -Key 'ModuleVersion'
    if (-not $versionPair) {
        throw "ModuleVersion was not found in $Path."
    }

    $versionAst = Get-PairStringAst -Pair $versionPair
    ConvertTo-ReplacedContent -Content $Content -Replacement @(
        [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset   = $versionAst.Extent.EndOffset
            Text        = "'$Version'"
        }
    )
}

function Get-NextPatchVersion {
    param([version]$Version)

    $patch = if ($Version.Build -lt 0) { 1 } else { $Version.Build + 1 }
    New-Object System.Version -ArgumentList $Version.Major, $Version.Minor, $patch
}

function Get-LatestStableNuGetVersion {
    param([string]$PackageId)

    $packageName = $PackageId.ToLowerInvariant()
    $index = Invoke-RestMethod `
        -UseBasicParsing `
        -Uri "https://api.nuget.org/v3-flatcontainer/$packageName/index.json" `
        -ErrorAction Stop
    $candidates = @(
        $index.versions |
            Where-Object { $_ -notmatch '-' } |
            ForEach-Object {
                [pscustomobject]@{
                    Text    = [string]$_
                    Version = [version]$_
                }
            }
    )
    if ($candidates.Count -eq 0) {
        throw "NuGet returned no stable versions for $PackageId."
    }

    ($candidates | Sort-Object Version -Descending | Select-Object -First 1).Text
}

function ConvertTo-SqliteDependencyContent {
    param(
        [string]$Content,
        [string]$Path,
        [string]$ProviderVersion,
        [string]$SQLiteVersion
    )

    $hashtable = Get-DataFileHashtableAst -Content $Content -Path $Path
    $versions = @{
        ProviderVersion = $ProviderVersion
        SQLiteVersion   = $SQLiteVersion
    }
    $replacements = foreach ($key in $versions.Keys) {
        $pair = Get-HashtablePair -Hashtable $hashtable -Key $key
        if (-not $pair) {
            throw "$key was not found in $Path."
        }
        $versionAst = Get-PairStringAst -Pair $pair
        if (-not $versionAst) {
            throw "$key in $Path is not a string."
        }

        [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset   = $versionAst.Extent.EndOffset
            Text        = "'$($versions[$key])'"
        }
    }

    ConvertTo-ReplacedContent -Content $Content -Replacement $replacements
}

function ConvertTo-SqliteReadmeContent {
    param(
        [string]$Content,
        [string]$ProviderVersion,
        [string]$SQLiteVersion
    )

    $versionPattern = '[0-9]+(?:\.[0-9]+)+'
    $pattern = "System\.Data\.SQLite\s+$versionPattern\s+and\s+SQLite\s+$versionPattern"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        throw 'The bundled SQLite version statement was not found in README.md.'
    }

    $replacement = "System.Data.SQLite $ProviderVersion and SQLite $SQLiteVersion"
    $Content.Substring(0, $match.Index) +
        $replacement +
        $Content.Substring($match.Index + $match.Length)
}

function ConvertTo-DependencyChangelog {
    param(
        [string]$Content,
        [version]$Version,
        [hashtable]$Dependency
    )

    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $dependencyEntries = @(
        $Dependency.Keys |
            Sort-Object |
            ForEach-Object {
                "- Validated and pinned ``$_`` at ``$($Dependency[$_])``."
            }
    )
    $section = @(
        "## [$Version] $(Get-Date -Format 'yyyy-MM-dd')"
        ''
        '### Changed'
        ''
        $dependencyEntries
        ''
        ''
    ) -join $newline

    $firstReleaseHeading = [regex]::Match($Content, '(?m)^##\s+\[')
    if ($firstReleaseHeading.Success) {
        $Content.Insert($firstReleaseHeading.Index, $section)
    } else {
        $Content.TrimEnd() + $newline + $newline + $section
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not $ModuleManifestPath) {
    $ModuleManifestPath = Get-ProjectManifestPath -Root $ProjectRoot
} elseif (-not [System.IO.Path]::IsPathRooted($ModuleManifestPath)) {
    $ModuleManifestPath = Join-Path -Path $ProjectRoot -ChildPath $ModuleManifestPath
}
$ModuleManifestPath = (Resolve-Path -LiteralPath $ModuleManifestPath).Path

$rootRequirementsPath = Join-Path -Path $ProjectRoot -ChildPath 'requirements.psd1'
$templateRequirementsPath = Join-Path -Path (Split-Path -Path $ModuleManifestPath -Parent) `
    -ChildPath 'template/requirements.psd1'
$isTemplateProject = Test-Path -LiteralPath $templateRequirementsPath -PathType Leaf
$pinnedRequirementsPath = if ($isTemplateProject) {
    $templateRequirementsPath
} else {
    $rootRequirementsPath
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$originalRootRequirements = [System.IO.File]::ReadAllText($rootRequirementsPath)
$originalPinnedRequirements = [System.IO.File]::ReadAllText($pinnedRequirementsPath)
$originalManifest = [System.IO.File]::ReadAllText($ModuleManifestPath)
$changelogPath = Join-Path -Path $ProjectRoot -ChildPath 'CHANGELOG.md'
$originalChangelog = [System.IO.File]::ReadAllText($changelogPath)
$readmePath = Join-Path -Path $ProjectRoot -ChildPath 'README.md'
$originalReadme = [System.IO.File]::ReadAllText($readmePath)
$sqliteDependencyPath = Join-Path -Path $ProjectRoot -ChildPath 'tools/SQLiteDependencies.psd1'
$originalSqliteDependencies = [System.IO.File]::ReadAllText($sqliteDependencyPath)
$sqliteDependencies = Import-PowerShellDataFile -LiteralPath $sqliteDependencyPath
$sqliteUpdaterPath = Join-Path -Path $ProjectRoot -ChildPath 'tools/Update-SqliteRuntime.ps1'
$manifestData = Import-PowerShellDataFile -LiteralPath $ModuleManifestPath
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModuleManifestPath)
$currentVersion = [version]$manifestData.ModuleVersion
$requiredSpecifications = @(
    Get-RequiredModuleSpecification -Content $originalManifest -Path $ModuleManifestPath
)

try {
    $latestProviderVersion = Get-LatestStableNuGetVersion `
        -PackageId $sqliteDependencies.ProviderPackage
    $latestSQLiteVersion = Get-LatestStableNuGetVersion `
        -PackageId $sqliteDependencies.SQLitePackage
    $candidateSqliteDependencies = ConvertTo-SqliteDependencyContent `
        -Content $originalSqliteDependencies `
        -Path $sqliteDependencyPath `
        -ProviderVersion $latestProviderVersion `
        -SQLiteVersion $latestSQLiteVersion
    $sqliteDependenciesChanged =
        $candidateSqliteDependencies -cne $originalSqliteDependencies
    $candidateReadme = if ($sqliteDependenciesChanged) {
        ConvertTo-SqliteReadmeContent `
            -Content $originalReadme `
            -ProviderVersion $latestProviderVersion `
            -SQLiteVersion $latestSQLiteVersion
    }
    else {
        $originalReadme
    }

    $rollingRequirements = ConvertTo-RequirementVersionContent `
        -Content $originalRootRequirements `
        -Path $rootRequirementsPath `
        -Latest
    [System.IO.File]::WriteAllText($rootRequirementsPath, $rollingRequirements, $utf8NoBom)

    $powerShellPath = (Get-Process -Id $PID).Path
    $buildPath = Join-Path -Path $ProjectRoot -ChildPath 'build.ps1'
    Push-Location -LiteralPath $ProjectRoot
    try {
        & $powerShellPath -NoLogo -NoProfile -ExecutionPolicy Bypass `
            -File $buildPath -Task Init -Bootstrap |
            Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Dependency initialization failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }

    $rootDependencyNames = Get-RequirementModuleName `
        -Content $rollingRequirements `
        -Path $rootRequirementsPath
    $pinnedDependencyNames = Get-RequirementModuleName `
        -Content $originalPinnedRequirements `
        -Path $pinnedRequirementsPath
    $allDependencyNames = @(
        @('PSDepend') +
        @($rootDependencyNames) +
        @($pinnedDependencyNames) +
        @($requiredSpecifications | ForEach-Object ModuleName) |
            Sort-Object -Unique
    )

    $initializedVersions = @{}
    foreach ($dependencyName in $allDependencyNames) {
        $installedModule = Get-Module -Name $dependencyName -ListAvailable |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if (-not $installedModule) {
            Install-Module -Name $dependencyName `
                -Repository PSGallery `
                -Scope CurrentUser `
                -Force `
                -ErrorAction Stop
            $installedModule = Get-Module -Name $dependencyName -ListAvailable |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }
        if (-not $installedModule) {
            throw "$dependencyName was not installed by the bootstrap/initialization step."
        }
        $initializedVersions[$dependencyName] = [string]$installedModule.Version
    }

    $requiredVersions = @{}
    foreach ($module in @($requiredSpecifications | ForEach-Object ModuleName)) {
        $requiredVersions[$module] = $initializedVersions[$module]
    }

    $candidatePinnedRequirements = ConvertTo-RequirementVersionContent `
        -Content $originalPinnedRequirements `
        -Path $pinnedRequirementsPath `
        -Version $initializedVersions
    $candidateManifest = ConvertTo-RequiredModuleContent `
        -Content $originalManifest `
        -Path $ModuleManifestPath `
        -Version $requiredVersions

    if ($isTemplateProject) {
        [System.IO.File]::WriteAllText(
            $rootRequirementsPath,
            $originalRootRequirements,
            $utf8NoBom
        )
    }

    $buildDependenciesChanged =
        $candidatePinnedRequirements -cne $originalPinnedRequirements -or
        $candidateManifest -cne $originalManifest
    $dependenciesChanged = $buildDependenciesChanged -or $sqliteDependenciesChanged
    $candidateVersion = $currentVersion

    if ($dependenciesChanged) {
        if ($PSBoundParameters.ContainsKey('ProposedVersion')) {
            $candidateVersion = $ProposedVersion
            if ($candidateVersion -le $currentVersion) {
                throw "ProposedVersion $candidateVersion must be newer than $currentVersion."
            }
        } else {
            $candidateVersion = Get-NextPatchVersion -Version $currentVersion
        }

        $candidateManifest = ConvertTo-ManifestVersionContent `
            -Content $candidateManifest `
            -Path $ModuleManifestPath `
            -Version $candidateVersion
        $validatedDependencies = @{}
        foreach ($dependencyName in $initializedVersions.Keys) {
            $validatedDependencies[$dependencyName] = $initializedVersions[$dependencyName]
        }
        $validatedDependencies[$sqliteDependencies.ProviderPackage] = $latestProviderVersion
        $validatedDependencies[$sqliteDependencies.SQLitePackage] = $latestSQLiteVersion

        $candidateChangelog = ConvertTo-DependencyChangelog `
            -Content $originalChangelog `
            -Version $candidateVersion `
            -Dependency $validatedDependencies
    } else {
        $candidateChangelog = $originalChangelog
    }

    if ($PSCmdlet.ShouldProcess($ProjectRoot, 'Write validated dependency and SQLite runtime candidate')) {
        if ($sqliteDependenciesChanged) {
            & $sqliteUpdaterPath `
                -ProviderVersion $latestProviderVersion `
                -SQLiteVersion $latestSQLiteVersion `
                -InstallPath (Split-Path -Path $ModuleManifestPath -Parent) `
                -All |
                Out-Host
        }

        [System.IO.File]::WriteAllText(
            $pinnedRequirementsPath,
            $candidatePinnedRequirements,
            $utf8NoBom
        )
        [System.IO.File]::WriteAllText($ModuleManifestPath, $candidateManifest, $utf8NoBom)
        [System.IO.File]::WriteAllText($changelogPath, $candidateChangelog, $utf8NoBom)
        [System.IO.File]::WriteAllText(
            $sqliteDependencyPath,
            $candidateSqliteDependencies,
            $utf8NoBom
        )
        [System.IO.File]::WriteAllText($readmePath, $candidateReadme, $utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText(
            $rootRequirementsPath,
            $originalRootRequirements,
            $utf8NoBom
        )
        if ($pinnedRequirementsPath -ne $rootRequirementsPath) {
            [System.IO.File]::WriteAllText(
                $pinnedRequirementsPath,
                $originalPinnedRequirements,
                $utf8NoBom
            )
        }
        [System.IO.File]::WriteAllText($ModuleManifestPath, $originalManifest, $utf8NoBom)
        [System.IO.File]::WriteAllText($changelogPath, $originalChangelog, $utf8NoBom)
        [System.IO.File]::WriteAllText(
            $sqliteDependencyPath,
            $originalSqliteDependencies,
            $utf8NoBom
        )
        [System.IO.File]::WriteAllText($readmePath, $originalReadme, $utf8NoBom)
    }
} catch {
    [System.IO.File]::WriteAllText(
        $rootRequirementsPath,
        $originalRootRequirements,
        $utf8NoBom
    )
    if ($pinnedRequirementsPath -ne $rootRequirementsPath) {
        [System.IO.File]::WriteAllText(
            $pinnedRequirementsPath,
            $originalPinnedRequirements,
            $utf8NoBom
        )
    }
    [System.IO.File]::WriteAllText($ModuleManifestPath, $originalManifest, $utf8NoBom)
    [System.IO.File]::WriteAllText($changelogPath, $originalChangelog, $utf8NoBom)
    [System.IO.File]::WriteAllText(
        $sqliteDependencyPath,
        $originalSqliteDependencies,
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText($readmePath, $originalReadme, $utf8NoBom)
    throw
}

$runtimeDependencies = @{}
$runtimeDependencies[[string]$sqliteDependencies.ProviderPackage] = $latestProviderVersion
$runtimeDependencies[[string]$sqliteDependencies.SQLitePackage] = $latestSQLiteVersion

[pscustomobject]@{
    Changed                = $dependenciesChanged
    ModuleName             = $moduleName
    CurrentVersion         = [string]$currentVersion
    ProposedVersion        = [string]$candidateVersion
    InitializedDependencies = [pscustomobject]$initializedVersions
    RequiredModules        = [pscustomobject]$requiredVersions
    RuntimeDependenciesChanged = $sqliteDependenciesChanged
    RuntimeDependencies    = [pscustomobject]$runtimeDependencies
    PinnedRequirementsPath = $pinnedRequirementsPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
    ModuleManifestPath     = $ModuleManifestPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
    ChangelogPath          = $changelogPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
    SQLiteDependenciesPath = $sqliteDependencyPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
}

