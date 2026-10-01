param(
    [string]$ThemeId = "space-pixel",
    [string]$ThemeSource = "",
    [string]$GodotExecutable = "",
    [switch]$SkipPreviewSmoke
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path $PSScriptRoot).Path
. (Join-Path $projectRoot "tools\Resolve-GodotExecutable.ps1")
$GodotExecutable = Resolve-ThemeGodotExecutable -GodotExecutable $GodotExecutable

& (Join-Path $projectRoot "tools\Select-Theme.ps1") -ThemeId $ThemeId -ThemeSource $ThemeSource
$activeState = Get-Content -LiteralPath (Join-Path $projectRoot "build\active-theme.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$packageRoot = [System.IO.Path]::GetFullPath([string]$activeState.Package)
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ("build\theme-workspaces\" + $ThemeId + "-test")))
$allowedWorkspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "build\theme-workspaces"))

try {
    & (Join-Path $projectRoot "tools\Prepare-ThemeWorkspace.ps1") -PackageRoot $packageRoot -WorkspaceRoot $workspaceRoot

    & $GodotExecutable --headless --path $workspaceRoot --import
    if ($LASTEXITCODE -ne 0) {
        throw "Godot could not import resources for theme '$ThemeId'."
    }

    & $GodotExecutable --headless --path $workspaceRoot --script res://tools/validate_theme.gd -- --contract res://contracts/screen_bindings.v2.json
    if ($LASTEXITCODE -ne 0) {
        throw "Theme '$ThemeId' does not satisfy manifest v2 or the binding contract."
    }

    & $GodotExecutable --headless --path $projectRoot --script res://tools/verify_interactive_pet.gd -- --theme $ThemeId --optional
    if ($LASTEXITCODE -ne 0) {
        throw "Interactive pet verification failed for theme '$ThemeId'."
    }

    if (-not $SkipPreviewSmoke) {
        if (-not $packageRoot.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Preview smoke requires a theme package inside the builder project."
        }
        & $GodotExecutable --headless --path $projectRoot --quit-after 3
        if ($LASTEXITCODE -ne 0) {
            throw "Headless preview smoke for theme '$ThemeId' failed."
        }
    }
} finally {
    if (
        (Test-Path -LiteralPath $workspaceRoot) -and
        $workspaceRoot.StartsWith($allowedWorkspaceRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
    }
    if ((Test-Path -LiteralPath $allowedWorkspaceRoot) -and @(Get-ChildItem -LiteralPath $allowedWorkspaceRoot -Force).Count -eq 0) {
        Remove-Item -LiteralPath $allowedWorkspaceRoot -Force
    }
}

Write-Host "Theme '$ThemeId': validation and preview smoke passed."
