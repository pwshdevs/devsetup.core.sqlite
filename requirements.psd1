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
        # Import the pinned Pester before PowerShellBuild can load another version
        # through RequiredModules. Pester assemblies cannot be replaced in-session.
        DependsOn = 'Pester'
    }
    'PSDependencyCanary' = @{
        Version = '1.0.0'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.25.0'
    }
}
