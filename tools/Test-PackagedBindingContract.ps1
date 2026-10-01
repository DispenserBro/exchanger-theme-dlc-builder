param(
    [string]$ThemeId = "*"
)

$ErrorActionPreference = "Stop"
$builderRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$authorityPath = Join-Path $builderRoot "contracts\screen_bindings.v2.json"
if (-not (Test-Path -LiteralPath $authorityPath)) {
    throw "The authoritative binding contract is missing: $authorityPath"
}

$contract = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
if ($contract.Format -ne "ExchangerThemeBindingContract" -or $contract.Version -ne 2) {
    throw "contracts\screen_bindings.v2.json has an unsupported format or version."
}
$screenCount = @($contract.Screens).Count
$bindingCount = @($contract.Screens | ForEach-Object { $_.Bindings }).Count
if ($screenCount -ne 9 -or $bindingCount -ne 481) {
    throw "Binding contract v2 must contain 9 screens and 481 elements; found $screenCount/$bindingCount."
}

$allBindings = @($contract.Screens | ForEach-Object { $_.Bindings })
$bindingIds = @($allBindings | ForEach-Object { $_.Id })
if (@($bindingIds | Select-Object -Unique).Count -ne 481) {
    throw "Binding contract v2 contains duplicate element IDs."
}

$requiredServiceBindings = [ordered]@{
    "settings.scroll.content.section_tabs.service_button" = "Button"
    "settings.scroll.content.service_inventory_panel" = "Control"
    "settings.scroll.content.service_inventory_panel.margin.content.count" = "Label"
    "settings.scroll.content.service_inventory_panel.margin.content.hopper1_label" = "Label"
    "settings.scroll.content.service_inventory_panel.margin.content.hopper2_label" = "Label"
    "settings.scroll.content.service_inventory_panel.margin.content.recount_button" = "Button"
    "settings.scroll.content.service_inventory_panel.margin.content.manual_add_button" = "Button"
    "settings.scroll.content.service_inventory_panel.margin.content.status" = "Label"
    "settings.service_dialog_overlay" = "Control"
    "settings.service_dialog_overlay.dialog.margin.content.title" = "Label"
    "settings.service_dialog_overlay.dialog.margin.content.description" = "Label"
    "settings.service_dialog_overlay.dialog.margin.content.amount" = "SpinBox"
    "settings.service_dialog_overlay.dialog.margin.content.buttons.cancel_button" = "Button"
    "settings.service_dialog_overlay.dialog.margin.content.buttons.confirm_button" = "Button"
}
foreach ($entry in $requiredServiceBindings.GetEnumerator()) {
    $binding = @($allBindings | Where-Object { $_.Id -eq $entry.Key })
    if ($binding.Count -ne 1 -or @($binding[0].Types) -notcontains $entry.Value) {
        throw "Binding contract v2 is missing service binding '$($entry.Key)' with type '$($entry.Value)'."
    }
}
$supplementalRuntimeBindings = @(
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
foreach ($supplementalRuntimeBinding in $supplementalRuntimeBindings) {
    if ($bindingIds -contains $supplementalRuntimeBinding) {
        throw "Supplemental runtime binding '$supplementalRuntimeBinding' must not change the immutable 481-element JSON contract."
    }
}
$cardAmountValueBinding = @($allBindings | Where-Object {
    $_.Id -eq "card_amount.content.reward_panel.content.value"
})
if ($cardAmountValueBinding.Count -ne 1 -or @($cardAmountValueBinding[0].Types) -notcontains "Label") {
    throw "The immutable CardAmount Value binding must remain a Label at its original ID/path."
}

$requiredShortTextBindings = @(
    "home.scroll.content.speech_text",
    "settings.scroll.content.branding_panel.margin.content.short_text",
    "settings.scroll.content.branding_panel.margin.content.short_text_error",
    "settings.scroll.content.branding_preview_panel.margin.content.short_text"
)
foreach ($bindingId in $requiredShortTextBindings) {
    if ($bindingIds -notcontains $bindingId) {
        throw "Binding contract v2 is missing required short-text binding '$bindingId'."
    }
}
if (@($bindingIds | Where-Object { $_ -like "*subtitle*" }).Count -ne 0) {
    throw "Binding contract v2 must not restore deprecated subtitle bindings."
}

$expectedFixedCollections = @{
    "card_amount.content.amount_panel.margin.content.preset_grid.slot_" = 16
    "settings.scroll.content.bonus_panel.margin.content.rows.slot_" = 80
    "settings.scroll.content.card_options_panel.margin.content.preset_rows.slot_" = 64
    "settings.scroll.content.advertisement_playlist_panel.margin.content.rows.slot_" = 48
}
foreach ($entry in $expectedFixedCollections.GetEnumerator()) {
    $actual = @($bindingIds | Where-Object { $_.StartsWith($entry.Key, [System.StringComparison]::Ordinal) }).Count
    if ($actual -ne $entry.Value) {
        throw "Fixed collection '$($entry.Key)' must expose $($entry.Value) bindings; found $actual."
    }
}

$authorityHash = (Get-FileHash -LiteralPath $authorityPath -Algorithm SHA256).Hash
$themeDirectories = Get-ChildItem -LiteralPath (Join-Path $builderRoot "themes") -Directory | Where-Object {
    $ThemeId -eq "*" -or $_.Name -eq $ThemeId
}
if (@($themeDirectories).Count -eq 0) {
    throw "Theme '$ThemeId' was not found in themes/."
}

foreach ($themeDirectory in $themeDirectories) {
    $manifestPath = Join-Path $themeDirectory.FullName "package\manifest.json"
    $packageContractPath = Join-Path $themeDirectory.FullName "package\contracts\screen_bindings.v2.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Manifest for theme '$($themeDirectory.Name)' is missing: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.Format -ne "ExchangerThemeDlc" -or $manifest.FormatVersion -ne 2) {
        throw "Theme '$($themeDirectory.Name)' does not use ExchangerThemeDlc v2."
    }
    if (-not (Test-Path -LiteralPath $packageContractPath)) {
        throw "Binding contract copy for theme '$($themeDirectory.Name)' is missing."
    }
    $packageHash = (Get-FileHash -LiteralPath $packageContractPath -Algorithm SHA256).Hash
    if ($packageHash -ne $authorityHash) {
        throw "Binding contract copy for theme '$($themeDirectory.Name)' differs from contracts\screen_bindings.v2.json."
    }
}

Write-Host "Binding contract copies are synchronized: $(@($themeDirectories).Count) theme(s), SHA-256 $authorityHash."
