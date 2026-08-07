@{
    PSDepend = @{
        Version = '0.4.1'
    }
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'Pester' = @{
        Version = '6.0.1'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake' = @{
        Version = '5.0.4'
    }
    'BuildHelpers' = @{
        Version = '2.0.16'
    }
    'PowerShellBuild' = @{
        Version = '0.8.2'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.25.0'
    }
}
