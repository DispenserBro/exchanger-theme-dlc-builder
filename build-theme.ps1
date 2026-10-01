param(
    [string]$ThemeId = "space-pixel",
    [string]$ThemeSource = "",
    [string]$OutputPath = "",
    [string]$GodotExecutable = "",
    [string]$ProgressPath = "",
    [switch]$PreserveActiveTheme,
    [switch]$InstallToDefaultUserPath,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path $PSScriptRoot).Path
. (Join-Path $projectRoot "tools\Resolve-GodotExecutable.ps1")
$GodotExecutable = Resolve-ThemeGodotExecutable -GodotExecutable $GodotExecutable

if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
    if (-not [System.IO.Path]::IsPathRooted($ProgressPath)) {
        $ProgressPath = Join-Path $projectRoot $ProgressPath
    }
    $ProgressPath = [System.IO.Path]::GetFullPath($ProgressPath)
}

function Write-ThemeBuildProgress {
    param(
        [string]$Stage,
        [string]$Message,
        [int]$Percent,
        [string]$Status = "running"
    )
    if ([string]::IsNullOrWhiteSpace($ProgressPath)) {
        return
    }
    $progressDirectory = [System.IO.Path]::GetDirectoryName($ProgressPath)
    New-Item -ItemType Directory -Force -Path $progressDirectory | Out-Null
    $payload = [ordered]@{
        ThemeId = $ThemeId
        Stage = $Stage
        Message = $Message
        Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
        Status = $Status
        OutputPath = $OutputPath
        UpdatedAtUtc = [DateTime]::UtcNow.ToString("o")
    }
    $json = $payload | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($ProgressPath, $json, [System.Text.UTF8Encoding]::new($false))
}

$activeStatePath = Join-Path $projectRoot "build\active-theme.json"
$activeStateExisted = Test-Path -LiteralPath $activeStatePath
$preservedActiveState = if ($PreserveActiveTheme -and $activeStateExisted) {
    [System.IO.File]::ReadAllBytes($activeStatePath)
} else {
    $null
}

try {
Write-ThemeBuildProgress -Stage "select" -Message "Selecting theme source" -Percent 5

& (Join-Path $PSScriptRoot "tools\Select-Theme.ps1") -ThemeId $ThemeId -ThemeSource $ThemeSource
$activeState = Get-Content -LiteralPath $activeStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$packageRoot = [System.IO.Path]::GetFullPath([string]$activeState.Package)

$buildDirectory = Join-Path $PSScriptRoot "build"
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $buildDirectory ($ThemeId + ".pck")
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot $OutputPath
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
Write-ThemeBuildProgress -Stage "prepare" -Message "Preparing isolated build workspace" -Percent 12

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ("build\theme-workspaces\" + $ThemeId + "-build")))
$allowedWorkspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "build\theme-workspaces"))
try {
    & (Join-Path $projectRoot "tools\Prepare-ThemeWorkspace.ps1") -PackageRoot $packageRoot -WorkspaceRoot $workspaceRoot

    Write-ThemeBuildProgress -Stage "import" -Message "Importing theme resources in Godot" -Percent 25
    & $GodotExecutable --headless --path $workspaceRoot --import
    if ($LASTEXITCODE -ne 0) {
        throw "Godot failed to import the selected theme."
    }
    if (-not $SkipValidation) {
        Write-ThemeBuildProgress -Stage "validate" -Message "Validating manifest, scenes, and bindings" -Percent 45
        & $GodotExecutable --headless --path $workspaceRoot --script res://tools/validate_theme.gd -- --contract res://contracts/screen_bindings.v2.json
        if ($LASTEXITCODE -ne 0) {
            throw "The selected theme does not satisfy the full-scene binding contract."
        }
    }

    Write-ThemeBuildProgress -Stage "export" -Message "Exporting production resources to PCK" -Percent 62
    & $GodotExecutable --headless --path $workspaceRoot --export-pack "Theme DLC" $OutputPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        throw "Godot failed to build the theme DLC package."
    }

    Write-ThemeBuildProgress -Stage "verify" -Message "Verifying packaged interactive pet" -Percent 84
    & $GodotExecutable --headless --path $projectRoot --script res://tools/verify_interactive_pet.gd -- --pack $OutputPath --optional
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged interactive pet verification failed for theme '$ThemeId'."
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

Write-ThemeBuildProgress -Stage "finalize" -Message "Finalizing local theme package" -Percent 93
$activeOutputPath = Join-Path $buildDirectory "active_theme.pck"
if (-not $PreserveActiveTheme -and $OutputPath -ne $activeOutputPath) {
    Copy-Item -LiteralPath $OutputPath -Destination $activeOutputPath -Force
}

if ($InstallToDefaultUserPath) {
    Write-ThemeBuildProgress -Stage "install" -Message "Installing PCK into the Exchanger user directory" -Percent 97
    $installDirectory = Join-Path $env:APPDATA "Godot\app_userdata\Exchanger\theme_dlc"
    New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
    Copy-Item -LiteralPath $OutputPath -Destination (Join-Path $installDirectory "active_theme.pck") -Force
    Write-Host "Theme '$ThemeId' installed into the Exchanger user directory."
} else {
    Write-Host "Theme '$ThemeId' built: $OutputPath"
}
Write-ThemeBuildProgress -Stage "complete" -Message "Theme build completed" -Percent 100 -Status "complete"
} catch {
    Write-ThemeBuildProgress -Stage "error" -Message $_.Exception.Message -Percent 100 -Status "error"
    throw
} finally {
    if ($PreserveActiveTheme) {
        if ($activeStateExisted) {
            [System.IO.File]::WriteAllBytes($activeStatePath, $preservedActiveState)
        } elseif (Test-Path -LiteralPath $activeStatePath) {
            Remove-Item -LiteralPath $activeStatePath -Force
        }
    }
}
