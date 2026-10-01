param(
    [string]$ThemeId = "space-pixel",
    [string]$ThemeSource = "",
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path $PSScriptRoot).Path
. (Join-Path $projectRoot "tools\Resolve-GodotExecutable.ps1")
$GodotExecutable = Resolve-ThemeGodotExecutable -GodotExecutable $GodotExecutable

& (Join-Path $projectRoot "tools\Select-Theme.ps1") -ThemeId $ThemeId -ThemeSource $ThemeSource
& $GodotExecutable --path $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Preview for theme '$ThemeId' failed."
}
