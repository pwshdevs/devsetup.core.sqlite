Describe 'Pinned build test runner' {
    BeforeAll {
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $runnerPath = Join-Path $projectRoot 'tools/Test-PSBuildPester.ps1'
        $requirementsPath = Join-Path $projectRoot 'requirements.psd1'
        $powerShellPath = (Get-Process -Id $PID).Path

        # A discoverable newer Pester must never be imported by the runner.
        $moduleRoot = Join-Path $TestDrive 'modules'
        $newerPester = Join-Path $moduleRoot 'Pester/99.0.0'
        New-Item -Path $newerPester -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $newerPester 'Pester.psm1') -Value "throw 'Unexpected newer Pester import'"
        New-ModuleManifest -Path (Join-Path $newerPester 'Pester.psd1') -RootModule Pester.psm1 -ModuleVersion 99.0.0

        $childScript = Join-Path $TestDrive 'Run-PinnedTests.ps1'
        Set-Content -LiteralPath $childScript -Value @'
param($RunnerPath, $RequirementsPath, $ModuleRoot, $FixturePath)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = $ModuleRoot + [IO.Path]::PathSeparator + $env:PSModulePath
$requirements = Import-PowerShellDataFile -LiteralPath $RequirementsPath
Import-Module Pester -RequiredVersion $requirements.Pester.Version
. $RunnerPath
Test-PSBuildPester -Path $FixturePath -OutputPath results.xml -OutputVerbosity None
if ((Get-Module Pester).Version.ToString() -ne $requirements.Pester.Version) {
    throw 'The runner did not retain the pinned Pester version.'
}
'@

        function Invoke-PinnedTestProcess {
            param([string]$FixturePath)

            # Windows PowerShell 5.1 treats redirected native stderr as errors.
            # Capture expected child failures even when the build uses Stop;
            # this preference change is confined to the helper's function scope.
            $ErrorActionPreference = 'Continue'
            $output = & $powerShellPath -NoProfile -File $childScript $runnerPath $requirementsPath $moduleRoot $FixturePath 2>&1
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = $output -join [Environment]::NewLine
            }
        }
    }

    It 'uses the pin when a newer Pester is discoverable' {
        $fixture = Join-Path $TestDrive 'passing'
        New-Item -Path $fixture -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture 'Example.Tests.ps1') -Value "Describe 'fixture' { It 'passes' { 1 | Should -Be 1 } }"

        $run = Invoke-PinnedTestProcess -FixturePath $fixture
        $run.ExitCode | Should -Be 0 -Because $run.Output
        [xml]$report = Get-Content -LiteralPath (Join-Path $fixture 'results.xml') -Raw
        $report.'test-results'.failures | Should -Be '0'
        $report.'test-results'.total | Should -Be '1'
    }

    It 'fails the build for <Name>' -ForEach @(
        @{ Name = 'assertion failures'; Body = "Describe 'fixture' { It 'fails' { 1 | Should -Be 2 } }" }
        @{ Name = 'BeforeAll failures'; Body = "Describe 'fixture' { BeforeAll { throw 'setup failed' }; It 'never runs' { } }" }
        @{ Name = 'discovery failures'; Body = "throw 'discovery failed'" }
    ) {
        $fixture = Join-Path $TestDrive $Name
        New-Item -Path $fixture -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture 'Example.Tests.ps1') -Value $Body

        $run = Invoke-PinnedTestProcess -FixturePath $fixture
        $run.ExitCode | Should -Not -Be 0
        $run.Output | Should -Match 'Pester run failed'
    }
}
