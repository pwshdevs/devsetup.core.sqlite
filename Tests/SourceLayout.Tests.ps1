BeforeDiscovery {
    $projectRoot = if ($env:BHProjectPath) {
        $env:BHProjectPath
    } else {
        Split-Path $PSScriptRoot -Parent
    }
    $moduleSource = Join-Path $projectRoot 'src/devsetup.core.sqlite'
    $scriptFiles = @(Get-ChildItem `
        (Join-Path $moduleSource 'Public'), (Join-Path $moduleSource 'Private') `
        -Filter '*.ps1' `
        -File)
}

Describe 'PowerShell source layout' {
    It '<_.BaseName>.ps1 contains one documented function with the matching name' -ForEach $scriptFiles {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )
        $functions = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true))

        $parseErrors | Should -BeNullOrEmpty
        $functions | Should -HaveCount 1
        $functions[0].Name | Should -Be $_.BaseName
        $functions[0].GetHelpContent() | Should -Not -BeNullOrEmpty
    }
}
