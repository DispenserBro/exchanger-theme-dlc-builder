param(
    [string]$HostProject = (Join-Path $PSScriptRoot "..\..\exchanger"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\contracts\screen_bindings.v2.json"),
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$hostRoot = (Resolve-Path -LiteralPath $HostProject).Path
$screenDefinitions = @(
    [ordered]@{ Directory = "HomeScreen"; Key = "home"; Pascal = "Home" },
    [ordered]@{ Directory = "CashPaymentScreen"; Key = "cash_payment"; Pascal = "CashPayment" },
    [ordered]@{ Directory = "CardAmountScreen"; Key = "card_amount"; Pascal = "CardAmount" },
    [ordered]@{ Directory = "CardCustomAmountScreen"; Key = "card_custom_amount"; Pascal = "CardCustomAmount" },
    [ordered]@{ Directory = "CardTerminalScreen"; Key = "card_terminal"; Pascal = "CardTerminal" },
    [ordered]@{ Directory = "SuccessScreen"; Key = "success"; Pascal = "Success" },
    [ordered]@{ Directory = "ErrorScreen"; Key = "error"; Pascal = "Error" },
    [ordered]@{ Directory = "ServiceAccessScreen"; Key = "service_access"; Pascal = "ServiceAccess" },
    [ordered]@{ Directory = "SettingsScreen"; Key = "settings"; Pascal = "Settings" }
)

# Эти готовые узлы появились после фиксации immutable-каталога v2. Host использует
# их напрямую и Builder валидирует отдельно, поэтому буквальные GetNode-пути не
# должны незаметно расширять contracts/screen_bindings.v2.json.
$supplementalRuntimeBindingIds = @(
    "home.scroll.content.advertisement_panel",
    "home.scroll.content.stock_status.meter.empty",
    "home.scroll.content.stock_status.meter.low",
    "home.scroll.content.stock_status.meter.enough",
    "home.scroll.content.stock_status.meter.much",
    "home.scroll.content.stock_status.approximate_count",
    "card_amount.content.reward_panel.content.bonus",
    "cash_payment.content.banner_text",
    "cash_payment.content.top_bar.home_navigation_button",
    "card_amount.content.top_bar.home_navigation_button",
    "card_custom_amount.content.top_bar.home_navigation_button",
    "card_terminal.content.top_bar.home_navigation_button",
    "success.content.home_navigation_button",
    "error.content.home_navigation_button",
    "service_access.content.home_navigation_button",
    "settings.footer",
    "settings.footer.save_and_exit_button",
    "settings.scroll.content.footer_clearance",
    "settings.scroll.content.music_panel",
    "settings.scroll.content.sound_effects_panel",
    "settings.scroll.content.service_inventory_panel.margin.content.description",
    "settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled",
    "settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled",
    "settings.scroll.content.menu_visibility_panel",
    "settings.scroll.content.menu_visibility_panel.margin.content.show_stock_status",
    "settings.scroll.content.menu_visibility_panel.margin.content.show_right_character",
    "settings.scroll.content.menu_visibility_panel.margin.content.show_promotion_block",
    "settings.scroll.content.menu_visibility_panel.margin.content.show_interactive_pet",
    "settings.scroll.content.advertisement_poster_panel.margin.content.select_button",
    "settings.scroll.content.animated_banner_texts_panel"
)

function Convert-ToSnakeCase([string]$Value) {
    return [regex]::Replace($Value, '(?<=[a-z0-9])([A-Z])', '_$1').ToLowerInvariant()
}

function Convert-ToBindingId([string]$ScreenKey, [string]$FallbackPath) {
    $relative = $FallbackPath.Substring("SafeMargin/".Length)
    $segments = $relative.Split('/') | ForEach-Object { Convert-ToSnakeCase $_ }
    return $ScreenKey + "." + ($segments -join ".")
}

function Convert-ToGodotType([string]$CodeType) {
    switch ($CodeType) {
        "AdvertisementPlayerControl" { return "Control" }
        "ConnectionStatusControl" { return "Control" }
        "StockStatusControl" { return "Control" }
        default { return $CodeType }
    }
}

function Add-Binding(
    [System.Collections.Specialized.OrderedDictionary]$Bindings,
    [string]$Id,
    [string]$Type,
    [string]$FallbackPath
) {
    $Bindings[$Id] = [ordered]@{
        Id = $Id
        Types = @($Type)
        Required = $true
        FallbackPath = $FallbackPath
    }
}

$screens = @()
foreach ($definition in $screenDefinitions) {
    $sourcePath = Join-Path $hostRoot ("src\scenes\{0}\{0}.cs" -f $definition.Directory)
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Host screen source is missing: $sourcePath"
    }
    $source = Get-Content -LiteralPath $sourcePath -Raw
    $matches = [regex]::Matches(
        $source,
        'GetNode(?:<(?<type>[^>]+)>)?\("(?<path>SafeMargin/[^"]+)"\)'
    )
    $bindings = [ordered]@{}
    foreach ($match in $matches) {
        $fallbackPath = $match.Groups["path"].Value
        $bindingId = Convert-ToBindingId $definition.Key $fallbackPath
        $codeType = $match.Groups["type"].Value
        if ([string]::IsNullOrWhiteSpace($codeType)) {
            $codeType = "Node"
        }
        $bindings[$bindingId] = [ordered]@{
            Id = $bindingId
            Types = @((Convert-ToGodotType $codeType))
            Required = $true
            FallbackPath = $fallbackPath
        }
    }

    if ($definition.Key -eq "card_custom_amount" -or $definition.Key -eq "service_access") {
        for ($digit = 0; $digit -le 9; $digit++) {
            $fallbackPath = if ($definition.Key -eq "card_custom_amount") {
                "SafeMargin/Content/KeypadPanel/Content/Keypad/Digit$digit"
            } else {
                "SafeMargin/Content/AccessPanel/Fields/Keypad/Digit$digit"
            }
            $bindingId = Convert-ToBindingId $definition.Key $fallbackPath
            $bindings[$bindingId] = [ordered]@{
                Id = $bindingId
                Types = @("Button")
                Required = $true
                FallbackPath = $fallbackPath
            }
        }
    }

    if ($definition.Key -eq "home") {
        Add-Binding $bindings "home.scroll.content.footer.margin.content.connection_status" "Control" "SafeMargin/Scroll/Content/Footer/Margin/Content/ConnectionStatus"
        Add-Binding $bindings "home.scroll.content.stock_status.state" "Label" "SafeMargin/Scroll/Content/StockStatus/Margin/Content/State"
        Add-Binding $bindings "home.scroll.content.footer.margin.content.connection_status.label" "Label" "SafeMargin/Scroll/Content/Footer/Margin/Content/ConnectionStatus/Panel/Margin/Label"
        Add-Binding $bindings "home.scroll.content.advertisement_panel.layer.content" "Control" "SafeMargin/Scroll/Content/AdvertisementPanel/Layer/Content"
        Add-Binding $bindings "home.scroll.content.advertisement_panel.layer.content.poster" "TextureRect" "SafeMargin/Scroll/Content/AdvertisementPanel/Layer/Content/Poster"
        Add-Binding $bindings "home.scroll.content.advertisement_panel.layer.content.video_player" "VideoStreamPlayer" "SafeMargin/Scroll/Content/AdvertisementPanel/Layer/Content/VideoPlayer"
        Add-Binding $bindings "home.scroll.content.advertisement_panel.layer.content.fallback_label" "Label" "SafeMargin/Scroll/Content/AdvertisementPanel/Layer/Content/FallbackLabel"
    }

    if ($definition.Key -eq "card_amount") {
        for ($index = 0; $index -lt 16; $index++) {
            $suffix = $index.ToString("00")
            Add-Binding $bindings "card_amount.content.amount_panel.margin.content.preset_grid.slot_$suffix" "Button" "SafeMargin/Content/AmountPanel/Margin/Content/PresetGrid/PresetSlot$suffix"
        }
    }

    if ($definition.Key -eq "settings") {
        Add-Binding $bindings "settings.scroll.content.section_tabs.service_button" "Button" "SafeMargin/Scroll/Content/SectionTabs/ServiceButton"
        Add-Binding $bindings "settings.scroll.content.service_inventory_panel" "Control" "SafeMargin/Scroll/Content/ServiceInventoryPanel"
        Add-Binding $bindings "settings.scroll.content.service_inventory_panel.margin.content.count" "Label" "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/Count"
        Add-Binding $bindings "settings.scroll.content.service_inventory_panel.margin.content.recount_button" "Button" "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/RecountButton"
        Add-Binding $bindings "settings.scroll.content.service_inventory_panel.margin.content.manual_add_button" "Button" "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/ManualAddButton"
        Add-Binding $bindings "settings.scroll.content.service_inventory_panel.margin.content.status" "Label" "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/Status"
        Add-Binding $bindings "settings.service_dialog_overlay" "Control" "SafeMargin/ServiceDialogOverlay"
        Add-Binding $bindings "settings.service_dialog_overlay.dialog.margin.content.title" "Label" "SafeMargin/ServiceDialogOverlay/Dialog/Margin/Content/Title"
        Add-Binding $bindings "settings.service_dialog_overlay.dialog.margin.content.description" "Label" "SafeMargin/ServiceDialogOverlay/Dialog/Margin/Content/Description"
        Add-Binding $bindings "settings.service_dialog_overlay.dialog.margin.content.amount" "SpinBox" "SafeMargin/ServiceDialogOverlay/Dialog/Margin/Content/Amount"
        Add-Binding $bindings "settings.service_dialog_overlay.dialog.margin.content.buttons.cancel_button" "Button" "SafeMargin/ServiceDialogOverlay/Dialog/Margin/Content/Buttons/CancelButton"
        Add-Binding $bindings "settings.service_dialog_overlay.dialog.margin.content.buttons.confirm_button" "Button" "SafeMargin/ServiceDialogOverlay/Dialog/Margin/Content/Buttons/ConfirmButton"

        for ($index = 0; $index -lt 33; $index++) {
            $suffix = $index.ToString("00")
            $row = if ($index -lt 12) { 0 } elseif ($index -lt 23) { 1 } else { 2 }
            Add-Binding $bindings "settings.keyboard_overlay.text_keyboard.content.letter_rows.row$row.key_$suffix" "Button" "SafeMargin/KeyboardOverlay/TextKeyboard/Content/LetterRows/Row$row/Key_$suffix"
        }

        foreach ($action in @(
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.header.hide_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/Header/HideButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.primary_actions.language_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/PrimaryActions/LanguageButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.primary_actions.shift_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/PrimaryActions/ShiftButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.primary_actions.symbols_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/PrimaryActions/SymbolsButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.primary_actions.backspace_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/PrimaryActions/BackspaceButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.secondary_actions.caret_left_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/SecondaryActions/CaretLeftButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.secondary_actions.caret_right_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/SecondaryActions/CaretRightButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.secondary_actions.clear_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/SecondaryActions/ClearButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.text_keyboard.content.secondary_actions.space_button"; Path = "SafeMargin/KeyboardOverlay/TextKeyboard/Content/SecondaryActions/SpaceButton" }
        )) {
            Add-Binding $bindings $action.Id "Button" $action.Path
        }

        for ($digit = 0; $digit -le 9; $digit++) {
            Add-Binding $bindings "settings.keyboard_overlay.numeric_keyboard.content.grid.digit$digit" "Button" "SafeMargin/KeyboardOverlay/NumericKeyboard/Content/Grid/Digit$digit"
        }
        foreach ($action in @(
            [ordered]@{ Id = "settings.keyboard_overlay.numeric_keyboard.content.header.hide_button"; Path = "SafeMargin/KeyboardOverlay/NumericKeyboard/Content/Header/HideButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.numeric_keyboard.content.grid.clear_button"; Path = "SafeMargin/KeyboardOverlay/NumericKeyboard/Content/Grid/ClearButton" },
            [ordered]@{ Id = "settings.keyboard_overlay.numeric_keyboard.content.grid.backspace_button"; Path = "SafeMargin/KeyboardOverlay/NumericKeyboard/Content/Grid/BackspaceButton" }
        )) {
            Add-Binding $bindings $action.Id "Button" $action.Path
        }

        Add-Binding $bindings "settings.scroll.content.bonus_panel.margin.content.rows.empty_state" "Label" "SafeMargin/Scroll/Content/BonusPanel/Margin/Content/Rows/EmptyState"
        for ($index = 0; $index -lt 16; $index++) {
            $suffix = $index.ToString("00")
            $id = "settings.scroll.content.bonus_panel.margin.content.rows.slot_$suffix"
            $path = "SafeMargin/Scroll/Content/BonusPanel/Margin/Content/Rows/Slot$suffix"
            Add-Binding $bindings $id "Control" $path
            Add-Binding $bindings "$id.threshold" "SpinBox" "$path/Row/Threshold"
            Add-Binding $bindings "$id.bonus" "SpinBox" "$path/Row/Bonus"
            Add-Binding $bindings "$id.remove_button" "Button" "$path/Row/RemoveButton"
            Add-Binding $bindings "$id.error" "Label" "$path/Error"
        }

        Add-Binding $bindings "settings.scroll.content.card_options_panel.margin.content.preset_rows.empty_state" "Label" "SafeMargin/Scroll/Content/CardOptionsPanel/Margin/Content/PresetRows/EmptyState"
        for ($index = 0; $index -lt 16; $index++) {
            $suffix = $index.ToString("00")
            $id = "settings.scroll.content.card_options_panel.margin.content.preset_rows.slot_$suffix"
            $path = "SafeMargin/Scroll/Content/CardOptionsPanel/Margin/Content/PresetRows/Slot$suffix"
            Add-Binding $bindings $id "Control" $path
            Add-Binding $bindings "$id.amount" "SpinBox" "$path/Row/Amount"
            Add-Binding $bindings "$id.remove_button" "Button" "$path/Row/RemoveButton"
            Add-Binding $bindings "$id.error" "Label" "$path/Error"
        }

        Add-Binding $bindings "settings.scroll.content.advertisement_playlist_panel.margin.content.rows.empty_state" "Label" "SafeMargin/Scroll/Content/AdvertisementPlaylistPanel/Margin/Content/Rows/EmptyState"
        for ($index = 0; $index -lt 12; $index++) {
            $suffix = $index.ToString("00")
            $id = "settings.scroll.content.advertisement_playlist_panel.margin.content.rows.slot_$suffix"
            $path = "SafeMargin/Scroll/Content/AdvertisementPlaylistPanel/Margin/Content/Rows/Slot$suffix"
            Add-Binding $bindings $id "Control" $path
            Add-Binding $bindings "$id.path" "LineEdit" "$path/Row/Path"
            Add-Binding $bindings "$id.remove_button" "Button" "$path/Row/RemoveButton"
            Add-Binding $bindings "$id.error" "Label" "$path/Error"
        }
    }

    foreach ($supplementalBindingId in $supplementalRuntimeBindingIds) {
        if ($bindings.Contains($supplementalBindingId)) {
            $bindings.Remove($supplementalBindingId)
        }
    }

    $screens += [ordered]@{
        BindingId = "screen.$($definition.Key)"
        Key = $definition.Key
        RootName = "ThemeScreen_$($definition.Pascal)"
        Path = "res://exchanger_theme_dlc/scenes/screen_$($definition.Key).tscn"
        Bindings = @($bindings.Values | Sort-Object Id)
    }
}

$catalog = [ordered]@{
    Format = "ExchangerThemeBindingContract"
    Version = 2
    ScreenMetadataKey = "exchanger_screen_binding_id"
    ElementMetadataKey = "exchanger_binding_id"
    Source = "Immutable Exchanger ThemeView contract: host binds existing theme-owned nodes only"
    Screens = $screens
}
$json = $catalog | ConvertTo-Json -Depth 12

if ($Check) {
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Binding catalog is missing: $OutputPath"
    }
    $current = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
    $expectedScreens = @($catalog.Screens)
    $currentScreens = @($current.Screens)
    if ($current.Format -ne $catalog.Format -or $current.Version -ne $catalog.Version -or $currentScreens.Count -ne $expectedScreens.Count) {
        throw "Binding catalog header or screen count is out of date."
    }
    foreach ($expectedScreen in $expectedScreens) {
        $currentScreen = @($currentScreens | Where-Object { $_.BindingId -eq $expectedScreen.BindingId })
        if ($currentScreen.Count -ne 1 -or @($currentScreen[0].Bindings).Count -ne @($expectedScreen.Bindings).Count) {
            throw "Binding catalog screen '$($expectedScreen.BindingId)' is out of date."
        }
        foreach ($expectedBinding in $expectedScreen.Bindings) {
            $actual = @($currentScreen[0].Bindings | Where-Object { $_.Id -eq $expectedBinding.Id })
            if ($actual.Count -ne 1 -or $actual[0].FallbackPath -ne $expectedBinding.FallbackPath -or (@($actual[0].Types) -join ",") -ne (@($expectedBinding.Types) -join ",")) {
                throw "Binding '$($expectedBinding.Id)' is missing or out of date."
            }
        }
    }
    $builderRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $authorityHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
    foreach ($packageDirectory in Get-ChildItem -LiteralPath (Join-Path $builderRoot "themes") -Directory) {
        $packageCatalog = Join-Path $packageDirectory.FullName "package\contracts\screen_bindings.v2.json"
        if (-not (Test-Path -LiteralPath $packageCatalog)) {
            throw "Packaged binding catalog is missing or out of date: $packageCatalog"
        }
        $packageHash = (Get-FileHash -LiteralPath $packageCatalog -Algorithm SHA256).Hash
        if ($packageHash -ne $authorityHash) {
            throw "Packaged binding catalog is missing or out of date: $packageCatalog"
        }
    }
    Write-Host "Binding catalog matches the host sources."
    return
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
$builderRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
foreach ($themeDirectory in Get-ChildItem -LiteralPath (Join-Path $builderRoot "themes") -Directory) {
    $packageRoot = Join-Path $themeDirectory.FullName "package"
    if (-not (Test-Path -LiteralPath $packageRoot)) {
        continue
    }
    $packageContractDirectory = Join-Path $packageRoot "contracts"
    New-Item -ItemType Directory -Force -Path $packageContractDirectory | Out-Null
    Copy-Item -LiteralPath $OutputPath -Destination (Join-Path $packageContractDirectory "screen_bindings.v2.json") -Force
}
Write-Host "Binding catalog written: $OutputPath"
