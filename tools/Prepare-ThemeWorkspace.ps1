param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$packageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
$workspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "build\theme-workspaces"))
$packageResourcePrefix = ""
if ($packageRoot.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    $packageProjectRelative = $packageRoot.Substring($projectRoot.Length + 1).Replace("\", "/").TrimEnd("/")
    $packageResourcePrefix = "res://$packageProjectRelative/"
}
$runtimeResourcePrefix = "res://exchanger_theme_dlc/"
$portableTextExtensions = @(".gd", ".gdshader", ".json", ".tres", ".tscn")
$preservedImportSourceExtensions = @(".ttf", ".otf", ".woff", ".woff2")
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

if (
    ($workspaceRoot -eq $allowedRoot) -or
    (-not $workspaceRoot.StartsWith($allowedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
) {
    throw "Refusing to prepare unexpected theme workspace: $workspaceRoot"
}

if (Test-Path -LiteralPath $workspaceRoot) {
    Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
}

$stagingRoot = Join-Path $workspaceRoot "exchanger_theme_dlc"
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse -File) {
    if ($file.Name -eq ".gdignore" -or $file.Extension -eq ".uid") {
        continue
    }
    $isPreservedImport = $false
    if ($file.Extension -eq ".import") {
        $importSourceName = $file.Name.Substring(0, $file.Name.Length - $file.Extension.Length)
        $importSourceExtension = [System.IO.Path]::GetExtension($importSourceName).ToLowerInvariant()
        $isPreservedImport = $importSourceExtension -in $preservedImportSourceExtensions
        if (-not $isPreservedImport) {
            continue
        }
    }
    $relative = $file.FullName.Substring($packageRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
    $destination = Join-Path $stagingRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    if (-not [string]::IsNullOrWhiteSpace($packageResourcePrefix) -and ($file.Extension -in $portableTextExtensions -or $isPreservedImport)) {
        $content = [System.IO.File]::ReadAllText($destination)
        $portableContent = $content.Replace($packageResourcePrefix, $runtimeResourcePrefix)
        if ($portableContent -ne $content) {
            [System.IO.File]::WriteAllText($destination, $portableContent, $utf8WithoutBom)
        }
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot "tools") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot "contracts") | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot "tools\validate_theme.gd") -Destination (Join-Path $workspaceRoot "tools\validate_theme.gd") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "contracts\screen_bindings.v2.json") -Destination (Join-Path $workspaceRoot "contracts\screen_bindings.v2.json") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "export_presets.cfg") -Destination (Join-Path $workspaceRoot "export_presets.cfg") -Force

$projectConfig = @'
; Generated isolated workspace for Exchanger theme validation/export.
config_version=5

[application]
config/name="Exchanger Theme Build Workspace"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor]
export/convert_text_resources_to_binary=false

[rendering]
textures/canvas_textures/default_texture_filter=0
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'@
[System.IO.File]::WriteAllText((Join-Path $workspaceRoot "project.godot"), $projectConfig, $utf8WithoutBom)

Write-Host "Prepared isolated theme workspace: $workspaceRoot"
