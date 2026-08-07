# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.0.0] Unreleased

### Added

- Cross-platform System.Data.SQLite 2.0.4 and SQLite 3.53.4 runtime assets for Windows, Linux, and macOS.
- Native x64, x86, ARM, and ARM64 support where available for each operating system.
- Culture-independent UTC date/time parsing with support for configurable provider formats.
- A precompiled AnyCPU support library for DBNull-to-null conversion without runtime C# compilation.
- GitHub Actions workflows, PlatyPS documentation, project governance files, and a reproducible Lath build.
- A repository-only SQLite runtime updater integrated with the automated maintenance canary.
- High-level `Get-SqliteRow`, `Add-SqliteRow`, `Set-SqliteRow`, and `Remove-SqliteRow` commands with quoted identifiers and parameterized values.
- Safe mutation defaults that require a filter or explicit `-All`, plus portable ordered/limited updates and deletes for rowid and composite-key tables.
- Source-layout enforcement requiring one documented function per correspondingly named file.

### Changed

- Renamed the module from PSSQLite to devsetup.core.sqlite.
- Renamed Out-DataTable to ConvertTo-SqliteDataTable.
- Moved the legacy nested DataTable and bulk-copy helpers into documented, individually named private files.
- Normalized the build-process PATH under WSL and limited Unix script-analysis input to PowerShell files, avoiding slow Windows command discovery and a PSScriptAnalyzer null reference on bundled native runtime trees.
- Made build-dependency cleanup tolerate manifests that omit the optional `RequiredModules` key under strict mode.

