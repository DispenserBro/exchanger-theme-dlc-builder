param(
    [string]$HostProject = (Join-Path $PSScriptRoot "..\..\exchanger"),
    [string[]]$ThemeIds = @("example", "space-pixel")
)

$ErrorActionPreference = "Stop"
$builderRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$hostRoot = (Resolve-Path -LiteralPath $HostProject).Path
$contract = Get-Content -LiteralPath (Join-Path $builderRoot "contracts\screen_bindings.v2.json") -Raw | ConvertFrom-Json

$sourceDirectories = [ordered]@{
    home = "HomeScreen"
    cash_payment = "CashPaymentScreen"
    card_amount = "CardAmountScreen"
    card_custom_amount = "CardCustomAmountScreen"
    card_terminal = "CardTerminalScreen"
    success = "SuccessScreen"
    error = "ErrorScreen"
    service_access = "ServiceAccessScreen"
    settings = "SettingsScreen"
}

function Convert-NodeHeader([string]$Line) {
    if ($Line -match 'instance=ExtResource\("(?:2_stock|3_advertisement|4_connection)"\)') {
        $lineWithoutInstance = [regex]::Replace($Line, '\s+instance=ExtResource\("[^\"]+"\)', '')
        if ($lineWithoutInstance -notmatch '\stype="') {
            $lineWithoutInstance = $lineWithoutInstance.Insert($lineWithoutInstance.Length - 1, ' type="Control"')
        }
        return $lineWithoutInstance
    }
    return $Line
}

foreach ($themeId in $ThemeIds) {
    $themeRoot = Join-Path $builderRoot ("themes\" + $themeId)
    $sceneDirectory = Join-Path $themeRoot "package\scenes"
    New-Item -ItemType Directory -Force -Path $sceneDirectory | Out-Null

    foreach ($screen in $contract.Screens) {
        $sourceDirectory = $sourceDirectories[$screen.Key]
        $sourcePath = Join-Path $hostRoot ("src\scenes\{0}\{0}.tscn" -f $sourceDirectory)
        $lines = Get-Content -LiteralPath $sourcePath
        $bindingByFallbackPath = @{}
        foreach ($binding in $screen.Bindings) {
            $bindingByFallbackPath[$binding.FallbackPath] = $binding.Id
        }

        $result = [System.Collections.Generic.List[string]]::new()
        $rootSeen = $false
        $skipNonVisualService = $false
        foreach ($sourceLine in $lines) {
            $line = $sourceLine
            if ($line -match '^\[gd_scene .*\suid="[^"]+"') {
                $line = [regex]::Replace($line, '\s+uid="[^"]+"', '')
            }
            if ($line -match '^\[node name="(?:AutoSaveTimer|TestTonePlayer)"') {
                $skipNonVisualService = $true
                continue
            }
            if ($skipNonVisualService) {
                if ($line -notmatch '^\[') {
                    continue
                }
                $skipNonVisualService = $false
            }
            if ($line -match '^\[ext_resource type="Script"') {
                continue
            }
            if ($line -match '^\[ext_resource type="PackedScene".*path="res://src/ui/KioskFooter/') {
                $line = [regex]::Replace($line, 'path="[^"]+"', 'path="../components/footer.tscn"')
            } elseif ($line -match '^\[ext_resource .*path="res://src/') {
                continue
            }
            if ($line -match '^script = ExtResource\(' -or $line -match '^SlotId = ') {
                continue
            }

            if ($line -match '^\[node name="') {
                $line = Convert-NodeHeader $line
                $nameMatch = [regex]::Match($line, '^\[node name="(?<name>[^"]+)"')
                $parentMatch = [regex]::Match($line, ' parent="(?<parent>[^"]+)"')
                $name = $nameMatch.Groups["name"].Value
                if (-not $rootSeen) {
                    $line = $line.Replace(('name="' + $name + '"'), ('name="' + $screen.RootName + '"'))
                    $rootSeen = $true
                    $result.Add($line)
                    $result.Add(('metadata/exchanger_screen_binding_id = "' + $screen.BindingId + '"'))
                    continue
                }

                $parent = $parentMatch.Groups["parent"].Value
                $fullPath = if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq ".") {
                    $name
                } else {
                    $parent + "/" + $name
                }
                if ($bindingByFallbackPath.ContainsKey($fullPath)) {
                    $result.Add($line)
                    $result.Add(('metadata/exchanger_binding_id = "' + $bindingByFallbackPath[$fullPath] + '"'))
                    continue
                }
            }
            $result.Add($line)
        }

        $outputPath = Join-Path $sceneDirectory ("screen_" + $screen.Key + ".tscn")
        $text = ($result -join "`n") + "`n"
        if ($text -match 'res://src/' -or $text -match '(?m)^script = ') {
            throw "Sanitized scene still references host code: $outputPath"
        }
        Set-Content -LiteralPath $outputPath -Value $text -Encoding UTF8 -NoNewline
    }
}

Write-Host "Imported and bound host scene structures for: $($ThemeIds -join ', ')"
