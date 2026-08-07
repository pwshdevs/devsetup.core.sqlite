[cmdletbinding(DefaultParameterSetName = 'Task')]
param(
    # Build task(s) to execute
    [parameter(ParameterSetName = 'task', position = 0)]
    [ArgumentCompleter( {
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        $psakeFile = './psakeFile.ps1'
        switch ($Parameter) {
            'Task' {
                if ([string]::IsNullOrEmpty($WordToComplete)) {
                    Get-PSakeScriptTasks -buildFile $psakeFile | Select-Object -ExpandProperty Name
                }
                else {
                    Get-PSakeScriptTasks -buildFile $psakeFile |
                        Where-Object { $_.Name -match $WordToComplete } |
                        Select-Object -ExpandProperty Name
                }
            }
            Default {
            }
        }
    })]
    [string[]]$Task = 'default',

    # Bootstrap dependencies
    [switch]$Bootstrap,

    # List available build tasks
    [parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    # Optional properties to pass to psake
    [hashtable]$Properties,

    # Optional parameters to pass to psake
    [hashtable]$Parameters
)

$ErrorActionPreference = 'Stop'

# WSL appends Windows executable directories to PATH by default. PSScriptAnalyzer
# performs command discovery while evaluating rules and becomes dramatically
# slower when it traverses those mounted directories. A build launched in its
# own pwsh process only needs Linux tools, so remove Windows interop entries for
# that process without changing the caller's environment.
if ($PSVersionTable.PSEdition -eq 'Core' -and $IsLinux -and $env:WSL_DISTRO_NAME) {
    $pathSeparator = [string][System.IO.Path]::PathSeparator
    $env:PATH = @($env:PATH -split [regex]::Escape($pathSeparator) |
        Where-Object { $_ -notmatch '^/mnt/[A-Za-z]/' }) -join $pathSeparator
}

function Initialize-ProjectModuleBuildEnvironment {
    param([string]$ProjectRoot)

    Set-BuildEnvironment -Force

    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $sourceRoot = Join-Path -Path $ProjectRoot -ChildPath 'src'
    $manifestCandidates = @(
        Get-ChildItem -LiteralPath $sourceRoot -Directory |
            ForEach-Object {
                $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $candidate
                }
            }
    )
    if ($manifestCandidates.Count -ne 1) {
        throw "Expected one module manifest beneath $sourceRoot; found $($manifestCandidates.Count)."
    }

    $manifestPath = $manifestCandidates[0]
    $modulePath = Split-Path -Path $manifestPath -Parent
    $env:BHProjectPath = $ProjectRoot
    $env:BHProjectName = [System.IO.Path]::GetFileNameWithoutExtension($manifestPath)
    $env:BHModulePath = $modulePath
    $env:BHPSModulePath = $modulePath
    $env:BHPSModuleManifest = $manifestPath
}

# Bootstrap dependencies
if ($Bootstrap.IsPresent) {
    $minimumPSDependVersion = '0.4.1'
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if ((Test-Path -Path ./requirements.psd1)) {
        $psDepend = Get-Module -Name PSDepend -ListAvailable |
            Where-Object Version -GE $minimumPSDependVersion |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if (-not $psDepend) {
            Install-Module -Name PSDepend -MinimumVersion $minimumPSDependVersion -Repository PSGallery -Scope CurrentUser -Force
        }
        Import-Module -Name PSDepend -MinimumVersion $minimumPSDependVersion -Verbose:$false
        Invoke-PSDepend -Path './requirements.psd1' -Install -Import -Force -WarningAction SilentlyContinue
    } else {
        Write-Warning 'No [requirements.psd1] found. Skipping build dependency installation.'
    }
}

# Execute psake task(s)
$psakeFile = './psakeFile.ps1'
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-PSakeScriptTasks -buildFile $psakeFile |
        Format-Table -Property Name, Description, Alias, DependsOn
} else {
    Initialize-ProjectModuleBuildEnvironment -ProjectRoot $PSScriptRoot
    Invoke-psake -buildFile $psakeFile -taskList $Task -nologo -properties $Properties -parameters $Parameters
    exit ([int](-not $psake.build_success))
}
