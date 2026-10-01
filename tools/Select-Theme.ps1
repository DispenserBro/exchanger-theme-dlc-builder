param(
    [string]$ThemeId = "space-pixel",
    [string]$ThemeSource = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$themesRoot = Join-Path $projectRoot "themes"

if (Test-Path -LiteralPath $themesRoot) {
    foreach ($themeDirectory in Get-ChildItem -LiteralPath $themesRoot -Directory) {
        $legacyIgnore = Join-Path $themeDirectory.FullName ".gdignore"
        if (Test-Path -LiteralPath $legacyIgnore) {
            Remove-Item -LiteralPath $legacyIgnore -Force
            Write-Host "Removed legacy theme ignore: $legacyIgnore"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ThemeSource)) {
    $themeRoot = Join-Path $projectRoot ("themes\" + $ThemeId)
} else {
    $themeRoot = (Resolve-Path -LiteralPath $ThemeSource).Path
}

$packageRoot = if (Test-Path -LiteralPath (Join-Path $themeRoot "package\manifest.json")) {
    Join-Path $themeRoot "package"
} elseif (Test-Path -LiteralPath (Join-Path $themeRoot "manifest.json")) {
    $themeRoot
} else {
    throw "Theme source must contain package\manifest.json or manifest.json: $themeRoot"
}
$packageRoot = [System.IO.Path]::GetFullPath($packageRoot)

$manifest = Get-Content -LiteralPath (Join-Path $packageRoot "manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.Format -ne "ExchangerThemeDlc") {
    throw "Unsupported manifest Format '$($manifest.Format)'."
}
if ($manifest.FormatVersion -ne 2) {
    throw "Full-scene themes require manifest FormatVersion 2."
}
if (-not [string]::IsNullOrWhiteSpace($ThemeId) -and $manifest.ThemeId -ne $ThemeId) {
    throw "ThemeId '$($manifest.ThemeId)' does not match selected id '$ThemeId'."
}

$buildDirectory = Join-Path $projectRoot "build"
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
$buildIgnorePath = Join-Path $buildDirectory ".gdignore"
if (-not (Test-Path -LiteralPath $buildIgnorePath)) {
    [System.IO.File]::WriteAllText(
        $buildIgnorePath,
        "# Generated builds and isolated export workspaces are not editor resources." + [Environment]::NewLine,
        $utf8WithoutBom
    )
}
$state = [ordered]@{
    ThemeId = [string]$manifest.ThemeId
    DisplayName = [string]$manifest.DisplayName
    Source = [System.IO.Path]::GetFullPath($themeRoot)
    Package = $packageRoot
    ActivatedAtUtc = [DateTime]::UtcNow.ToString("o")
}
$stateJson = $state | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $buildDirectory "active-theme.json"), $stateJson + [Environment]::NewLine, $utf8WithoutBom)

Write-Host "Theme '$($manifest.ThemeId)' selected from $packageRoot"
