function Test-PSBuildScriptAnalysis {
    <#
    .SYNOPSIS
        Runs PowerShellBuild script analysis without traversing bundled binaries on Unix.
    .DESCRIPTION
        Delegates to PowerShellBuild's Test-PSBuildScriptAnalysis command on Windows.
        On Linux and macOS, enumerates and analyzes each PowerShell source file without
        recursion. This avoids a PSScriptAnalyzer 1.25.0 null-reference failure caused
        by recursively analyzing a staged module that contains native runtime trees.
    .PARAMETER Path
        Path to the staged PowerShell module.
    .PARAMETER SeverityThreshold
        Severity at which PowerShellBuild fails the build.
    .PARAMETER SettingsPath
        Path to the PSScriptAnalyzer settings file.
    .EXAMPLE
        Test-PSBuildScriptAnalysis -Path ./Output/devsetup.core.sqlite/1.1.0 -SeverityThreshold Error

        Analyzes the staged module and fails when an error-level diagnostic is found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('None', 'Error', 'Warning', 'Information')]
        [string]$SeverityThreshold,

        [string]$SettingsPath
    )

    if ($PSVersionTable.PSEdition -ne 'Core' -or $IsWindows) {
        return PowerShellBuild\Test-PSBuildScriptAnalysis @PSBoundParameters
    }

    $sourceExtensions = @('.ps1', '.psd1', '.psm1')
    $analysisResult = @(
        Get-ChildItem -LiteralPath $Path -File -Recurse |
            Where-Object Extension -In $sourceExtensions |
            Sort-Object -Property FullName |
            ForEach-Object {
                Invoke-ScriptAnalyzer -Path $_.FullName -Settings $SettingsPath
            }
    )

    if ($analysisResult.Count -gt 0) {
        Write-Host 'PSScriptAnalyzer results:' -ForegroundColor Yellow
        $analysisResult | Format-Table -AutoSize
    }

    $errors = @($analysisResult | Where-Object Severity -EQ 'Error').Count
    $warnings = @($analysisResult | Where-Object Severity -EQ 'Warning').Count
    $information = @($analysisResult | Where-Object Severity -EQ 'Information').Count

    switch ($SeverityThreshold) {
        'None' {
            return
        }
        'Error' {
            if ($errors -gt 0) {
                throw "PSScriptAnalyzer found $errors error-level issue(s)."
            }
        }
        'Warning' {
            if ($errors -gt 0 -or $warnings -gt 0) {
                throw "PSScriptAnalyzer found $errors error-level and $warnings warning-level issue(s)."
            }
        }
        'Information' {
            if ($errors -gt 0 -or $warnings -gt 0 -or $information -gt 0) {
                throw "PSScriptAnalyzer found $errors error-level, $warnings warning-level, and $information information-level issue(s)."
            }
        }
        default {
            if ($analysisResult.Count -gt 0) {
                throw "PSScriptAnalyzer found $($analysisResult.Count) issue(s)."
            }
        }
    }
}
