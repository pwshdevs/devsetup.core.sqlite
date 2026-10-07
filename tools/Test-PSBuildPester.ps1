function Test-PSBuildPester {
    <#
    .SYNOPSIS
        Runs PowerShellBuild tests with the Pester version pinned by this project.
    .DESCRIPTION
        Provides the PowerShellBuild Pester task interface without its unbounded
        MinimumVersion import. Reads the pin from requirements.psd1 so dependency
        updates apply to bootstrap and test execution together.
    .PARAMETER Path
        Directory containing the tests.
    .PARAMETER ModuleName
        Project module to unload after testing.
    .PARAMETER ModuleManifest
        Staged project manifest to import when ImportModule is set.
    .PARAMETER OutputPath
        Test report path, relative to the tests directory.
    .PARAMETER OutputFormat
        Pester test report format.
    .PARAMETER CodeCoverage
        Enables code coverage.
    .PARAMETER CodeCoverageThreshold
        Required coverage fraction, from zero to one.
    .PARAMETER CodeCoverageFiles
        Source files to include in coverage.
    .PARAMETER CodeCoverageOutputFile
        Coverage report path, relative to the tests directory.
    .PARAMETER CodeCoverageOutputFileFormat
        Pester coverage report format.
    .PARAMETER ImportModule
        Imports the staged project module before testing.
    .PARAMETER SkipRemainingOnFailure
        Scope of tests to skip after a failure.
    .PARAMETER OutputVerbosity
        Pester output verbosity.
    .EXAMPLE
        Test-PSBuildPester -Path ./Tests -OutputPath out/testResults.xml

        Runs the tests with the project-pinned Pester version and writes a report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ModuleName,
        [string]$ModuleManifest,
        [string]$OutputPath,
        [string]$OutputFormat = 'NUnit2.5',
        [switch]$CodeCoverage,
        [double]$CodeCoverageThreshold,
        [string[]]$CodeCoverageFiles = @(),
        [string]$CodeCoverageOutputFile = 'coverage.xml',
        [string]$CodeCoverageOutputFileFormat = 'JaCoCo',
        [switch]$ImportModule,
        [ValidateSet('None', 'Run', 'Container', 'Block')]
        [string]$SkipRemainingOnFailure = 'None',
        [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$OutputVerbosity = 'Detailed'
    )

    $requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '../requirements.psd1')
    Import-Module Pester -RequiredVersion $requirements.Pester.Version -ErrorAction Stop
    if ($ImportModule) {
        $ModuleManifest = (Resolve-Path -LiteralPath $ModuleManifest -ErrorAction Stop).Path
    }

    Push-Location -LiteralPath $Path
    try {
        if ($ImportModule) {
            Get-Module -Name $ModuleName | Remove-Module -Force
            Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Path = '.'
        $configuration.Run.PassThru = $true
        $configuration.Run.SkipRemainingOnFailure = $SkipRemainingOnFailure
        $configuration.Output.Verbosity = $OutputVerbosity
        $configuration.TestResult.Enabled = -not [string]::IsNullOrEmpty($OutputPath)
        $configuration.TestResult.OutputPath = $OutputPath
        $configuration.TestResult.OutputFormat = $OutputFormat

        if ($CodeCoverage) {
            $configuration.CodeCoverage.Enabled = $true
            if ($CodeCoverageFiles.Count -gt 0) {
                $configuration.CodeCoverage.Path = $CodeCoverageFiles
            }
            $configuration.CodeCoverage.OutputPath = $CodeCoverageOutputFile
            $configuration.CodeCoverage.OutputFormat = $CodeCoverageOutputFileFormat
            $configuration.CodeCoverage.CoveragePercentTarget = 100 * $CodeCoverageThreshold
        }

        $result = Invoke-Pester -Configuration $configuration
        # Aggregate status also catches discovery and BeforeAll/AfterAll errors
        # that do not increment the individual test FailedCount.
        if ($result.Result -ne 'Passed') {
            throw "Pester run failed: $($result.Result)."
        }
        if ($CodeCoverage -and $result.CodeCoverage.CoveragePercent -lt (100 * $CodeCoverageThreshold)) {
            throw "Pester code coverage is below the required $($configuration.CodeCoverage.CoveragePercentTarget.Value) percent."
        }
    } finally {
        Pop-Location
        if ($ModuleName) {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }
}
