#handle PS2
    if(-not $PSScriptRoot)
    {
        $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
    }

#Pick and import assemblies:
    function Get-DevSetupSQLiteRuntimeIdentifier
    {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateSet('linux', 'osx', 'win')]
            [string]
            $Platform,

            [Parameter(Mandatory=$true)]
            [string]
            $Architecture
        )

        $RuntimeIdentifier = "{0}-{1}" -f $Platform, $Architecture.ToLowerInvariant()
        $SupportedRuntimeIdentifiers = @(
            'linux-arm',
            'linux-arm64',
            'linux-x64',
            'osx-arm64',
            'osx-x64',
            'win-arm64',
            'win-x64',
            'win-x86'
        )

        if($SupportedRuntimeIdentifiers -notcontains $RuntimeIdentifier)
        {
            Throw "devsetup.core.sqlite does not include native SQLite binaries for '$RuntimeIdentifier'."
        }

        $RuntimeIdentifier
    }

    $ProcessArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()

    if($PSEdition -eq 'core')
    {
        if($IsLinux)
        {
            $RuntimePlatform = 'linux'
        }
        elseif($IsMacOS)
        {
            $RuntimePlatform = 'osx'
        }
        elseif($IsWindows)
        {
            $RuntimePlatform = 'win'
        }
        else
        {
            Throw 'devsetup.core.sqlite does not support this operating system.'
        }

        $RuntimeIdentifier = Get-DevSetupSQLiteRuntimeIdentifier -Platform $RuntimePlatform -Architecture $ProcessArchitecture
        Write-Verbose "Loading the $RuntimeIdentifier PowerShell Core provider."
        $SQLiteAssembly = Join-Path $PSScriptRoot "core\$RuntimeIdentifier\System.Data.SQLite.dll"
    }
    elseif($ProcessArchitecture -eq 'X64')
    {
        Write-Verbose 'Loading the x64 Windows PowerShell provider.'
        $SQLiteAssembly = Join-Path $PSScriptRoot 'x64\System.Data.SQLite.dll'
    }
    elseif($ProcessArchitecture -eq 'X86')
    {
        Write-Verbose 'Loading the x86 Windows PowerShell provider.'
        $SQLiteAssembly = Join-Path $PSScriptRoot 'x86\System.Data.SQLite.dll'
    }
    else
    {
        Throw "devsetup.core.sqlite does not support Windows PowerShell on $ProcessArchitecture. Use PowerShell 7 for ARM64 support."
    }

    if(-not (Test-Path -LiteralPath $SQLiteAssembly -PathType Leaf))
    {
        Throw "The bundled System.Data.SQLite provider was not found at '$SQLiteAssembly'."
    }

    if( -not ($Library = Add-Type -path $SQLiteAssembly -PassThru -ErrorAction stop) )
    {
        Throw "This module requires the System.Data.SQLite ADO.NET provider: https://www.nuget.org/packages/System.Data.SQLite"
    }

#Load the portable PSObject DBNull scrubber once per process. The helper is
#precompiled so PowerShell logging never records a runtime C# type definition.
    if(-not ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]))
    {
        $SQLiteSupportAssembly = Join-Path $PSScriptRoot 'lib\devsetup.core.sqlite.Support.dll'
        if(-not (Test-Path -LiteralPath $SQLiteSupportAssembly -PathType Leaf))
        {
            Throw "The bundled devsetup.core.sqlite support assembly was not found at '$SQLiteSupportAssembly'."
        }

        try
        {
            [void][System.Reflection.Assembly]::LoadFrom($SQLiteSupportAssembly)
        }
        catch
        {
            Throw "Could not load the devsetup.core.sqlite support assembly at '$SQLiteSupportAssembly': $_"
        }

        if(-not ('DevSetup.Core.SQLite.DBNullScrubber' -as [type]))
        {
            Throw "The support assembly at '$SQLiteSupportAssembly' does not contain DevSetup.Core.SQLite.DBNullScrubber."
        }
    }

#Get public and private function definition files.
    $Public  = Get-ChildItem $PSScriptRoot\*.ps1 -ErrorAction SilentlyContinue
    #$Private = Get-ChildItem $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue 

#Dot source the files
    Foreach($import in @($Public))
    {
        Try
        {
            #PS2 compatibility
            if($import.fullname)
            {
                . $import.fullname
            }
        }
        Catch
        {
            Write-Error "Failed to import function $($import.fullname): $_"
        }
    }
    
#Create some aliases, export public functions
    Export-ModuleMember -Function $($Public | Select -ExpandProperty BaseName)
