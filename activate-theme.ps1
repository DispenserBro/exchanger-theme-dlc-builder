param(
    [string]$ThemeId = "space-pixel",
    [string]$ThemeSource = ""
)

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "tools\Select-Theme.ps1") -ThemeId $ThemeId -ThemeSource $ThemeSource
