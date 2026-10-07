# PowerShellBuild's Analyze task resolves this project-local wrapper at runtime.
# Keep it in its own correspondingly named file with the rest of the build tools.
. (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Test-PSBuildScriptAnalysis.ps1')
# PowerShellBuild 0.8.2 reimports Pester with MinimumVersion, which can select a
# newer runner-installed assembly after bootstrap has loaded our pinned version.
. (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Test-PSBuildPester.ps1')

properties {
    # PowerShellBuild's bundled BuildHelpers does not discover manifests at
    # src/<ModuleName>/<ModuleName>.psd1, so restore the exact module settings
    # seeded by build.ps1 after PowerShellBuild initializes its defaults.
    $moduleManifestPath = $env:BHPSModuleManifest
    $moduleSourcePath = Split-Path -Path $moduleManifestPath -Parent
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($moduleManifestPath)
    $PSBPreference.General.SrcRootDir = $moduleSourcePath
    $PSBPreference.General.ModuleManifestPath = $moduleManifestPath
    $PSBPreference.General.ModuleName = $moduleName
    $PSBPreference.Test.RootDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Tests'
    $env:BHPSModulePath = $moduleSourcePath
    $env:BHModulePath = $moduleSourcePath
    $env:BHProjectName = $moduleName

    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
}

# Run static analysis before Pester initializes its test runspaces. This avoids
# a PSScriptAnalyzer null-reference failure observed after Pester on PowerShell 7.6.4.
$PSBTestDependency = @('Analyze', 'Pester')
$PSBStageFilesDependency = @('RestoreNestedModuleBuildEnvironment')

task RestoreNestedModuleBuildEnvironment -depends Clean {
    # Initialize-PSBuild calls BuildHelpers once more. Restore the nested src
    # values before any task stages, tests, or publishes the module.
    $env:BHProjectName = $PSBPreference.General.ModuleName
    $env:BHModulePath = $PSBPreference.General.SrcRootDir
    $env:BHPSModulePath = $PSBPreference.General.SrcRootDir
    $env:BHPSModuleManifest = $PSBPreference.General.ModuleManifestPath
}

task Default -depends Test

task Test -FromModule PowerShellBuild -minimumVersion '0.8.2'

task Canary -FromModule PSDependencyCanary -minimumVersion '1.0.0'

task Publish -FromModule PowerShellBuild -minimumVersion '0.8.2'
