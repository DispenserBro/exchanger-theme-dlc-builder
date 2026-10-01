@tool
extends EditorPlugin

const THEMES_ROOT := "res://themes"
const EXAMPLE_THEME_ID := "example"
const ACTIVE_STATE_PATH := "res://build/active-theme.json"
const ACTIVATE_SCRIPT_PATH := "res://activate-theme.ps1"
const BUILD_SCRIPT_PATH := "res://build-theme.ps1"
const PREVIEW_SCENE_PATH := "res://tools/preview/preview.tscn"

const MENU_SEPARATOR_ID := 1_947_300_100
const MENU_SELECT_ID := 1_947_300_101
const MENU_CREATE_ID := 1_947_300_102
const MENU_APPLY_ID := 1_947_300_103
const MENU_EXPORT_ID := 1_947_300_104
const SELECT_MENU_TEXT := "Выбрать тему"
const CREATE_MENU_TEXT := "Создать тему"
const EXPORT_MENU_TEXT := "Экспортировать тему"
const APPLY_MENU_TEXT := "Применить тему к Exchanger"
const SELECT_DIALOG_SIZE := Vector2i(700, 390)
const CREATE_DIALOG_SIZE := Vector2i(700, 470)
const EXPORT_THEME_DIALOG_SIZE := Vector2i(720, 430)
const EXPORT_FILE_DIALOG_SIZE := Vector2i(900, 620)
const APPLY_DIALOG_SIZE := Vector2i(720, 430)
const PROGRESS_DIALOG_SIZE := Vector2i(700, 330)
const MESSAGE_DIALOG_SIZE := Vector2i(680, 260)
const BUILD_PROGRESS_POLL_INTERVAL := 0.1
const BUILD_STAGE_LABELS := {
	"select": "Выбор исходников темы…",
	"prepare": "Подготовка пространства сборки…",
	"import": "Импорт ресурсов темы в Godot…",
	"validate": "Проверка manifest, сцен и биндингов…",
	"export": "Экспорт production-ресурсов в PCK…",
	"verify": "Проверка готового PCK…",
	"finalize": "Завершение локальной сборки…",
	"install": "Установка темы для Exchanger…",
	"complete": "Тема успешно собрана",
	"error": "Сборка завершилась с ошибкой",
}

var _editor_menu: PopupMenu
var _uses_standard_tools_menu := false
var _select_dialog: ConfirmationDialog
var _theme_options: OptionButton
var _select_details: RichTextLabel
var _create_dialog: ConfirmationDialog
var _theme_id_input: LineEdit
var _display_name_input: LineEdit
var _create_validation: Label
var _create_details: RichTextLabel
var _export_theme_dialog: ConfirmationDialog
var _export_theme_options: OptionButton
var _export_theme_details: RichTextLabel
var _export_file_dialog: FileDialog
var _apply_dialog: ConfirmationDialog
var _apply_details: RichTextLabel
var _progress_dialog: AcceptDialog
var _progress_bar: ProgressBar
var _progress_stage: Label
var _progress_details: RichTextLabel
var _message_dialog: AcceptDialog
var _theme_id_regex := RegEx.new()
var _busy := false
var _pending_export_theme_id := ""
var _pending_apply_theme_id := ""
var _build_thread: Thread
var _active_build_theme_id := ""
var _active_build_output_path := ""
var _active_build_installs := false
var _active_progress_path := ""
var _progress_poll_elapsed := 0.0


func _enter_tree() -> void:
	set_process(false)
	_theme_id_regex.compile("^[a-z0-9]+(?:-[a-z0-9]+)*$")
	_remove_legacy_theme_ignores()
	_create_dialogs()
	call_deferred("_install_menu_items")


func _exit_tree() -> void:
	_remove_menu_items()
	if _build_thread != null and _build_thread.is_started():
		_build_thread.wait_to_finish()
	_free_dialog(_select_dialog)
	_free_dialog(_create_dialog)
	_free_dialog(_export_theme_dialog)
	_free_dialog(_export_file_dialog)
	_free_dialog(_apply_dialog)
	_free_dialog(_progress_dialog)
	_free_dialog(_message_dialog)


func _install_menu_items() -> void:
	_editor_menu = _find_editor_menu(EditorInterface.get_base_control())
	if _editor_menu != null:
		_remove_direct_menu_item(MENU_SELECT_ID)
		_remove_direct_menu_item(MENU_CREATE_ID)
		_remove_direct_menu_item(MENU_EXPORT_ID)
		_remove_direct_menu_item(MENU_APPLY_ID)
		_remove_direct_menu_item(MENU_SEPARATOR_ID)
		_editor_menu.add_separator("Темы Exchanger", MENU_SEPARATOR_ID)
		_editor_menu.add_item(SELECT_MENU_TEXT, MENU_SELECT_ID)
		_editor_menu.add_item(CREATE_MENU_TEXT, MENU_CREATE_ID)
		_editor_menu.add_item(EXPORT_MENU_TEXT, MENU_EXPORT_ID)
		_editor_menu.add_item(APPLY_MENU_TEXT, MENU_APPLY_ID)
		if not _editor_menu.id_pressed.is_connected(_on_editor_menu_id_pressed):
			_editor_menu.id_pressed.connect(_on_editor_menu_id_pressed)
		print("[Theme Manager] Commands added to the Editor menu.")
		return

	_uses_standard_tools_menu = true
	add_tool_menu_item(SELECT_MENU_TEXT, _show_select_dialog)
	add_tool_menu_item(CREATE_MENU_TEXT, _show_create_dialog)
	add_tool_menu_item(EXPORT_MENU_TEXT, _show_export_dialog)
	add_tool_menu_item(APPLY_MENU_TEXT, _show_apply_dialog)
	push_warning("[Theme Manager] Editor menu was not found; commands were added to Project > Tools.")


func _remove_menu_items() -> void:
	if _editor_menu != null and is_instance_valid(_editor_menu):
		_remove_direct_menu_item(MENU_SELECT_ID)
		_remove_direct_menu_item(MENU_CREATE_ID)
		_remove_direct_menu_item(MENU_EXPORT_ID)
		_remove_direct_menu_item(MENU_APPLY_ID)
		_remove_direct_menu_item(MENU_SEPARATOR_ID)
		if _editor_menu.id_pressed.is_connected(_on_editor_menu_id_pressed):
			_editor_menu.id_pressed.disconnect(_on_editor_menu_id_pressed)
	if _uses_standard_tools_menu:
		remove_tool_menu_item(SELECT_MENU_TEXT)
		remove_tool_menu_item(CREATE_MENU_TEXT)
		remove_tool_menu_item(EXPORT_MENU_TEXT)
		remove_tool_menu_item(APPLY_MENU_TEXT)
	_uses_standard_tools_menu = false
	_editor_menu = null


func _remove_direct_menu_item(item_id: int) -> void:
	if _editor_menu == null or not is_instance_valid(_editor_menu):
		return
	var item_index := _editor_menu.get_item_index(item_id)
	if item_index >= 0:
		_editor_menu.remove_item(item_index)


func _find_editor_menu(root: Node) -> PopupMenu:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node is MenuBar:
			var menu_bar := node as MenuBar
			for menu_index in range(menu_bar.get_menu_count()):
				var title := menu_bar.get_menu_title(menu_index).replace("&", "").strip_edges().to_lower()
				if title == "editor" or title == "редактор":
					return menu_bar.get_menu_popup(menu_index)
		for child in node.get_children():
			pending.push_back(child)
	return null


func _remove_legacy_theme_ignores() -> void:
	var themes_directory := DirAccess.open(THEMES_ROOT)
	if themes_directory == null:
		return
	var removed_count := 0
	themes_directory.list_dir_begin()
	while true:
		var directory_name := themes_directory.get_next()
		if directory_name.is_empty():
			break
		if not themes_directory.current_is_dir() or directory_name.begins_with("."):
			continue
		var ignore_path := THEMES_ROOT.path_join(directory_name).path_join(".gdignore")
		if not FileAccess.file_exists(ignore_path):
			continue
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(ignore_path))
		if remove_error == OK:
			removed_count += 1
		else:
			push_warning("[Theme Manager] Не удалось удалить %s: %s" % [ignore_path, error_string(remove_error)])
	themes_directory.list_dir_end()
	if removed_count > 0:
		print("[Theme Manager] Removed %d legacy .gdignore file(s); themes are visible in FileSystem." % removed_count)
		EditorInterface.get_resource_filesystem().scan()


func _on_editor_menu_id_pressed(item_id: int) -> void:
	match item_id:
		MENU_SELECT_ID:
			_show_select_dialog()
		MENU_CREATE_ID:
			_show_create_dialog()
		MENU_EXPORT_ID:
			_show_export_dialog()
		MENU_APPLY_ID:
			_show_apply_dialog()


func _create_dialogs() -> void:
	var editor_root := EditorInterface.get_base_control()

	_select_dialog = ConfirmationDialog.new()
	_select_dialog.title = "Выбрать тему Exchanger"
	_configure_compact_dialog(_select_dialog, SELECT_DIALOG_SIZE)
	_select_dialog.get_ok_button().text = "Выбрать"
	_select_dialog.confirmed.connect(_on_select_confirmed)
	editor_root.add_child(_select_dialog)

	var select_content := VBoxContainer.new()
	select_content.custom_minimum_size = Vector2(620, 280)
	select_content.add_theme_constant_override("separation", 10)
	_select_dialog.add_child(select_content)
	var select_hint := Label.new()
	select_hint.text = "Выберите тему, с которой будет работать preview и команды редактора."
	select_content.add_child(select_hint)
	_theme_options = OptionButton.new()
	_theme_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_theme_options.item_selected.connect(_on_select_theme_changed)
	select_content.add_child(_theme_options)
	_select_details = _make_details_panel(150)
	select_content.add_child(_select_details)
	select_content.add_child(_make_steps_label([
		"Остановка запущенного preview",
		"Обновление active-theme.json",
		"Сканирование ресурсов и открытие preview",
	]))

	_create_dialog = ConfirmationDialog.new()
	_create_dialog.title = "Создать тему Exchanger"
	_configure_compact_dialog(_create_dialog, CREATE_DIALOG_SIZE)
	_create_dialog.get_ok_button().text = "Создать и выбрать"
	_create_dialog.confirmed.connect(_on_create_confirmed)
	editor_root.add_child(_create_dialog)

	var create_content := VBoxContainer.new()
	create_content.custom_minimum_size = Vector2(620, 360)
	create_content.add_theme_constant_override("separation", 7)
	_create_dialog.add_child(create_content)
	var create_hint := Label.new()
	create_hint.text = "Новая тема будет копией example: 9 полностью оформленных сцен и 481 биндинг."
	create_content.add_child(create_hint)
	create_content.add_child(_make_field_label("ID темы"))
	_theme_id_input = LineEdit.new()
	_theme_id_input.placeholder_text = "например, my-theme"
	_theme_id_input.text_changed.connect(_on_create_field_changed)
	create_content.add_child(_theme_id_input)
	create_content.add_child(_make_field_label("Название темы"))
	_display_name_input = LineEdit.new()
	_display_name_input.placeholder_text = "Например, Моя тема"
	_display_name_input.text_changed.connect(_on_create_field_changed)
	create_content.add_child(_display_name_input)
	_create_validation = Label.new()
	create_content.add_child(_create_validation)
	_create_details = _make_details_panel(105)
	_create_details.text = (
		"Этапы: проверка ID → копирование example → запись manifest.json → "
		+ "активация темы → открытие preview.\nИсходники будут созданы в themes/<id>/package/."
	)
	create_content.add_child(_create_details)

	_export_theme_dialog = ConfirmationDialog.new()
	_export_theme_dialog.title = "Экспортировать тему Exchanger"
	_configure_compact_dialog(_export_theme_dialog, EXPORT_THEME_DIALOG_SIZE)
	_export_theme_dialog.get_ok_button().text = "Выбрать файл…"
	_export_theme_dialog.confirmed.connect(_on_export_theme_confirmed)
	editor_root.add_child(_export_theme_dialog)

	var export_content := VBoxContainer.new()
	export_content.custom_minimum_size = Vector2(640, 320)
	export_content.add_theme_constant_override("separation", 10)
	_export_theme_dialog.add_child(export_content)
	var export_hint := Label.new()
	export_hint.text = "Можно экспортировать любую тему из themes/, независимо от активной темы preview."
	export_content.add_child(export_hint)
	_export_theme_options = OptionButton.new()
	_export_theme_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_theme_options.item_selected.connect(_on_export_theme_changed)
	export_content.add_child(_export_theme_options)
	_export_theme_details = _make_details_panel(155)
	export_content.add_child(_export_theme_details)
	export_content.add_child(_make_steps_label([
		"Изолированный импорт ресурсов",
		"Проверка manifest, 9 сцен и 481 биндинга",
		"Сборка и проверка готового PCK",
	]))

	_export_file_dialog = FileDialog.new()
	_export_file_dialog.title = "Сохранить тему как PCK"
	_export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_file_dialog.filters = PackedStringArray(["*.pck ; Exchanger Theme PCK"])
	_export_file_dialog.file_selected.connect(_on_export_file_selected)
	_export_file_dialog.canceled.connect(_on_export_canceled)
	editor_root.add_child(_export_file_dialog)

	_apply_dialog = ConfirmationDialog.new()
	_apply_dialog.title = "Применить тему к Exchanger"
	_configure_compact_dialog(_apply_dialog, APPLY_DIALOG_SIZE)
	_apply_dialog.get_ok_button().text = "Собрать и применить"
	_apply_dialog.confirmed.connect(_on_apply_confirmed)
	editor_root.add_child(_apply_dialog)
	var apply_content := VBoxContainer.new()
	apply_content.custom_minimum_size = Vector2(640, 320)
	apply_content.add_theme_constant_override("separation", 10)
	_apply_dialog.add_child(apply_content)
	var apply_hint := Label.new()
	apply_hint.text = "Активная тема будет полностью проверена, собрана и установлена для Exchanger."
	apply_content.add_child(apply_hint)
	_apply_details = _make_details_panel(170)
	apply_content.add_child(_apply_details)
	apply_content.add_child(_make_steps_label([
		"Проверка и сборка PCK",
		"Проверка содержимого готового пакета",
		"Установка active_theme.pck в каталог Exchanger",
	]))

	_progress_dialog = AcceptDialog.new()
	_progress_dialog.title = "Операция с темой"
	_configure_compact_dialog(_progress_dialog, PROGRESS_DIALOG_SIZE)
	_progress_dialog.get_ok_button().text = "Закрыть"
	editor_root.add_child(_progress_dialog)
	var progress_content := VBoxContainer.new()
	progress_content.custom_minimum_size = Vector2(620, 220)
	progress_content.add_theme_constant_override("separation", 12)
	_progress_dialog.add_child(progress_content)
	_progress_stage = Label.new()
	_progress_stage.text = "Подготовка…"
	progress_content.add_child(_progress_stage)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 28)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = true
	progress_content.add_child(_progress_bar)
	_progress_details = _make_details_panel(120)
	progress_content.add_child(_progress_details)

	_message_dialog = AcceptDialog.new()
	_message_dialog.title = "Темы Exchanger"
	_configure_compact_dialog(_message_dialog, MESSAGE_DIALOG_SIZE)
	editor_root.add_child(_message_dialog)


func _configure_compact_dialog(dialog: Window, maximum_size: Vector2i) -> void:
	# Godot 4.7 can calculate a huge first-popup minimum for an unlaid-out
	# autowrapped Label. Keep plugin dialogs explicitly bounded instead.
	dialog.wrap_controls = false
	dialog.unresizable = true
	dialog.max_size = maximum_size


func _make_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_details_panel(minimum_height: float) -> RichTextLabel:
	var details := RichTextLabel.new()
	details.custom_minimum_size = Vector2(0, minimum_height)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.bbcode_enabled = true
	details.fit_content = false
	details.scroll_active = false
	return details


func _make_steps_label(steps: Array[String]) -> Label:
	var label := Label.new()
	var lines: Array[String] = ["Этапы операции:"]
	for step_index in range(steps.size()):
		lines.append("%d. %s" % [step_index + 1, steps[step_index]])
	label.text = "\n".join(lines)
	return label


func _free_dialog(dialog: Window) -> void:
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


func _show_select_dialog() -> void:
	if _busy:
		_show_message("Операция уже выполняется.", true)
		return
	_refresh_theme_options()
	if _theme_options.item_count == 0:
		_show_message("В themes/ не найдено ни одной валидной темы manifest v2.", true)
		return
	_select_dialog.popup_centered_clamped(SELECT_DIALOG_SIZE, 0.9)


func _refresh_theme_options() -> void:
	_theme_options.clear()
	var active_theme_id := _read_active_theme_id()
	var selected_index := 0
	for theme in _list_themes():
		var item_index := _theme_options.item_count
		var theme_id: String = theme["id"]
		var display_name: String = theme["display_name"]
		_theme_options.add_item("%s  —  %s" % [display_name, theme_id])
		_theme_options.set_item_metadata(item_index, theme_id)
		if theme_id == active_theme_id:
			selected_index = item_index
	_theme_options.select(selected_index)
	_on_select_theme_changed(selected_index)


func _on_select_theme_changed(selected_index: int) -> void:
	if selected_index < 0 or selected_index >= _theme_options.item_count:
		_select_details.text = ""
		return
	var theme_id := str(_theme_options.get_item_metadata(selected_index))
	_select_details.text = _format_theme_details(theme_id, theme_id == _read_active_theme_id())


func _list_themes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var themes_directory := DirAccess.open(THEMES_ROOT)
	if themes_directory == null:
		return result
	themes_directory.list_dir_begin()
	while true:
		var directory_name := themes_directory.get_next()
		if directory_name.is_empty():
			break
		if not themes_directory.current_is_dir() or directory_name.begins_with("."):
			continue
		var manifest_path := THEMES_ROOT.path_join(directory_name).path_join("package/manifest.json")
		var manifest := _read_json_dictionary(manifest_path)
		if manifest.is_empty():
			continue
		if manifest.get("Format", "") != "ExchangerThemeDlc" or int(manifest.get("FormatVersion", 0)) != 2:
			continue
		if str(manifest.get("ThemeId", "")) != directory_name:
			continue
		result.append({
			"id": directory_name,
			"display_name": str(manifest.get("DisplayName", directory_name)),
			"format_version": int(manifest.get("FormatVersion", 0)),
		})
	themes_directory.list_dir_end()
	result.sort_custom(_sort_theme_records)
	return result


func _sort_theme_records(left: Dictionary, right: Dictionary) -> bool:
	return str(left["id"]) < str(right["id"])


func _read_active_theme_id() -> String:
	var state := _read_json_dictionary(ACTIVE_STATE_PATH)
	return str(state.get("ThemeId", ""))


func _find_theme_record(theme_id: String) -> Dictionary:
	for theme in _list_themes():
		if str(theme["id"]) == theme_id:
			return theme
	return {}


func _format_theme_details(theme_id: String, is_active: bool) -> String:
	var theme := _find_theme_record(theme_id)
	if theme.is_empty():
		return "[color=#ff8877]Тема с ID %s больше не найдена.[/color]" % theme_id
	var status := "[color=#83e69a]активна в preview[/color]" if is_active else "не активна в preview"
	return (
		"[b]%s[/b]\nID: [code]%s[/code]\nФормат: ExchangerThemeDlc v%d\nСтатус: %s\n"
		+ "Production-исходники: [code]themes/%s/package/[/code]"
	) % [theme["display_name"], theme_id, theme["format_version"], status, theme_id]


func _on_select_confirmed() -> void:
	var selected_index := _theme_options.selected
	if selected_index < 0:
		return
	var theme_id := str(_theme_options.get_item_metadata(selected_index))
	_activate_theme(theme_id)


func _show_create_dialog() -> void:
	if _busy:
		_show_message("Операция уже выполняется.", true)
		return
	_theme_id_input.clear()
	_display_name_input.clear()
	_update_create_validation()
	_create_dialog.popup_centered_clamped(CREATE_DIALOG_SIZE, 0.9)
	_theme_id_input.grab_focus()


func _on_create_field_changed(_new_text: String) -> void:
	_update_create_validation()


func _update_create_validation() -> void:
	var theme_id := _theme_id_input.text.strip_edges()
	var display_name := _display_name_input.text.strip_edges()
	var validation_message := ""
	if theme_id.is_empty():
		validation_message = "Введите ID темы."
	elif _theme_id_regex.search(theme_id) == null:
		validation_message = "ID: строчные латинские буквы, цифры и одиночные дефисы."
	elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(THEMES_ROOT.path_join(theme_id))):
		validation_message = "Тема с таким ID уже существует."
	elif display_name.is_empty():
		validation_message = "Введите название темы."

	_create_validation.text = validation_message if not validation_message.is_empty() else "Будет создан themes/%s." % theme_id
	_create_validation.modulate = Color(1.0, 0.55, 0.45) if not validation_message.is_empty() else Color(0.55, 0.9, 0.6)
	_create_dialog.get_ok_button().disabled = not validation_message.is_empty()
	if validation_message.is_empty():
		_create_details.text = (
			"Будет создана тема [b]%s[/b] с ID [code]%s[/code].\n"
			+ "Источник: [code]themes/example/[/code]\nНазначение: [code]themes/%s/[/code]\n"
			+ "После копирования тема сразу станет активной и откроется в preview."
		) % [display_name, theme_id, theme_id]
	else:
		_create_details.text = (
			"Этапы: проверка ID → копирование example → запись manifest.json → "
			+ "активация темы → открытие preview.\nИсходники будут созданы в themes/<id>/package/."
		)


func _on_create_confirmed() -> void:
	var theme_id := _theme_id_input.text.strip_edges()
	var display_name := _display_name_input.text.strip_edges()
	if _busy:
		return
	_create_and_activate_theme(theme_id, display_name)


func _show_export_dialog() -> void:
	if _busy:
		_show_message("Операция уже выполняется.", true)
		return
	_refresh_export_theme_options()
	if _export_theme_options.item_count == 0:
		_show_message("В themes/ не найдено ни одной валидной темы manifest v2.", true)
		return
	_export_theme_dialog.popup_centered_clamped(EXPORT_THEME_DIALOG_SIZE, 0.9)


func _refresh_export_theme_options() -> void:
	_export_theme_options.clear()
	var active_theme_id := _read_active_theme_id()
	var selected_index := 0
	for theme in _list_themes():
		var item_index := _export_theme_options.item_count
		var theme_id := str(theme["id"])
		_export_theme_options.add_item("%s  —  ID: %s" % [theme["display_name"], theme_id])
		_export_theme_options.set_item_metadata(item_index, theme_id)
		if theme_id == active_theme_id:
			selected_index = item_index
	_export_theme_options.select(selected_index)
	_on_export_theme_changed(selected_index)


func _on_export_theme_changed(selected_index: int) -> void:
	if selected_index < 0 or selected_index >= _export_theme_options.item_count:
		_export_theme_details.text = ""
		return
	var theme_id := str(_export_theme_options.get_item_metadata(selected_index))
	_export_theme_details.text = (
		_format_theme_details(theme_id, theme_id == _read_active_theme_id())
		+ "\n\nЭкспорт этой темы не переключит текущий preview."
	)


func _on_export_theme_confirmed() -> void:
	var selected_index := _export_theme_options.selected
	if selected_index < 0:
		return
	_pending_export_theme_id = str(_export_theme_options.get_item_metadata(selected_index))
	var theme := _find_theme_record(_pending_export_theme_id)
	if theme.is_empty():
		_pending_export_theme_id = ""
		_show_message("Выбранная тема больше не найдена. Обновите список и повторите экспорт.", true)
		return
	_export_file_dialog.title = "Экспортировать «%s» — %s" % [theme["display_name"], _pending_export_theme_id]
	_export_file_dialog.current_dir = ProjectSettings.globalize_path("res://build")
	_export_file_dialog.current_file = "%s.pck" % _pending_export_theme_id
	_export_file_dialog.popup_centered_clamped(EXPORT_FILE_DIALOG_SIZE, 0.9)


func _on_export_file_selected(selected_path: String) -> void:
	if _pending_export_theme_id.is_empty():
		return
	var theme_id := _pending_export_theme_id
	_pending_export_theme_id = ""
	var output_path := selected_path.simplify_path()
	if output_path.get_extension().to_lower() != "pck":
		output_path += ".pck"
	_start_theme_build(theme_id, output_path, false)


func _on_export_canceled() -> void:
	_pending_export_theme_id = ""


func _show_apply_dialog() -> void:
	if _busy:
		_show_message("Операция уже выполняется.", true)
		return

	var active_theme := _get_active_theme_record()
	if active_theme.is_empty():
		_show_message("Сначала выберите тему через «Редактор → Выбрать тему».", true)
		return

	var active_theme_id := str(active_theme["id"])
	_pending_apply_theme_id = active_theme_id
	_apply_details.text = (
		"[b]%s[/b]\nID: [code]%s[/code]\n\n"
		+ "Файл назначения:\n[code]%s[/code]\n\n"
		+ "[color=#ffd27d]Перед применением закройте Exchanger. После установки запустите его заново.[/color]"
	) % [active_theme["display_name"], active_theme_id, _get_default_install_path()]
	_apply_dialog.popup_centered_clamped(APPLY_DIALOG_SIZE, 0.9)


func _on_apply_confirmed() -> void:
	if _busy or _pending_apply_theme_id.is_empty():
		return
	var theme_id := _pending_apply_theme_id
	_pending_apply_theme_id = ""
	_start_theme_build(theme_id, "", true)


func _get_active_theme_record() -> Dictionary:
	var active_theme_id := _read_active_theme_id()
	for theme in _list_themes():
		if str(theme["id"]) == active_theme_id:
			return theme
	return {}


func _start_theme_build(theme_id: String, output_path: String, install_to_exchanger: bool) -> void:
	if _busy:
		return
	_busy = true
	_active_build_theme_id = theme_id
	_active_build_output_path = output_path
	_active_build_installs = install_to_exchanger
	_active_progress_path = ProjectSettings.globalize_path(
		"res://build/theme-manager-progress-%d.json" % OS.get_process_id()
	).simplify_path()
	if FileAccess.file_exists(_active_progress_path):
		DirAccess.remove_absolute(_active_progress_path)
	_progress_poll_elapsed = 0.0
	var operation_title := "Сборка и применение темы" if install_to_exchanger else "Экспорт темы"
	var destination := _get_default_install_path() if install_to_exchanger else output_path
	_begin_operation_progress(
		operation_title,
		"Подготовка запуска…",
		"Тема: %s\nНазначение: %s\nОжидание запуска PowerShell-сценария."
		% [theme_id, destination],
		2,
	)

	var script_path := ProjectSettings.globalize_path(BUILD_SCRIPT_PATH)
	_build_thread = Thread.new()
	var start_error := _build_thread.start(
		_build_theme_in_thread.bind(
			theme_id,
			script_path,
			output_path,
			install_to_exchanger,
			_active_progress_path,
		)
	)
	if start_error != OK:
		_build_thread = null
		_busy = false
		_clear_active_build()
		_finish_operation_progress(
			"Не удалось запустить сборку",
			"Ошибка запуска фоновой задачи: %s." % error_string(start_error),
			true,
		)
		return
	set_process(true)


func _process(delta: float) -> void:
	if _build_thread == null:
		return
	_progress_poll_elapsed += delta
	if _progress_poll_elapsed >= BUILD_PROGRESS_POLL_INTERVAL:
		_progress_poll_elapsed = 0.0
		_poll_build_progress()
	if _build_thread.is_alive():
		return
	_poll_build_progress()
	var thread_result: Variant = _build_thread.wait_to_finish()
	_build_thread = null
	set_process(false)
	_busy = false

	var result: Dictionary = {}
	if thread_result is Dictionary:
		result = thread_result
	var exit_code := int(result.get("exit_code", -1))
	var output := str(result.get("output", ""))
	if exit_code != 0:
		var failure_heading := "Применение темы не выполнено" if _active_build_installs else "Экспорт темы не выполнен"
		_finish_operation_progress(
			failure_heading,
			"Код ошибки: %d\n\n%s" % [exit_code, _format_output_tail(output)],
			true,
		)
		_clear_active_build()
		return

	EditorInterface.get_resource_filesystem().scan()
	if _active_build_installs:
		_finish_operation_progress(
			"Тема собрана и применена",
			"ID: %s\nФайл: %s\n\nТеперь запустите Exchanger заново."
			% [_active_build_theme_id, _get_default_install_path()],
		)
	else:
		if not FileAccess.file_exists(_active_build_output_path):
			_finish_operation_progress(
				"Экспорт не подтверждён",
				"Сборка завершилась, но экспортированный PCK не найден:\n%s"
				% _active_build_output_path,
				true,
			)
		else:
			_finish_operation_progress(
				"Тема успешно экспортирована",
				"ID: %s\nГотовый PCK:\n%s"
				% [_active_build_theme_id, _active_build_output_path],
			)
	_clear_active_build()


func _build_theme_in_thread(
	theme_id: String,
	script_path: String,
	output_path: String,
	install_to_exchanger: bool,
	progress_path: String,
) -> Dictionary:
	var output: Array = []
	var arguments := PackedStringArray([
		"-NoLogo",
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		script_path,
		"-ThemeId",
		theme_id,
		"-ProgressPath",
		progress_path,
	])
	if not output_path.is_empty():
		arguments.append("-OutputPath")
		arguments.append(output_path)
	if not install_to_exchanger:
		arguments.append("-PreserveActiveTheme")
	if install_to_exchanger:
		arguments.append("-InstallToDefaultUserPath")
	var exit_code := OS.execute(
		"powershell.exe",
		arguments,
		output,
		true,
		false,
	)
	var combined_output := ""
	for line in output:
		combined_output += str(line)
	return {
		"exit_code": exit_code,
		"output": combined_output.strip_edges(),
	}


func _clear_active_build() -> void:
	if not _active_progress_path.is_empty() and FileAccess.file_exists(_active_progress_path):
		DirAccess.remove_absolute(_active_progress_path)
	_active_build_theme_id = ""
	_active_build_output_path = ""
	_active_build_installs = false
	_active_progress_path = ""
	_progress_poll_elapsed = 0.0


func _get_default_install_path() -> String:
	var app_data := OS.get_environment("APPDATA")
	if app_data.is_empty():
		return "%APPDATA%\\Godot\\app_userdata\\Exchanger\\theme_dlc\\active_theme.pck"
	return app_data.path_join("Godot/app_userdata/Exchanger/theme_dlc/active_theme.pck")


func _format_output_tail(output: String, maximum_lines := 10) -> String:
	var stripped := output.strip_edges()
	if stripped.is_empty():
		return "PowerShell не вернул диагностический вывод."
	var lines := stripped.split("\n", false)
	var first_line := maxi(0, lines.size() - maximum_lines)
	return "\n".join(lines.slice(first_line))


func _poll_build_progress() -> void:
	if _active_progress_path.is_empty() or not FileAccess.file_exists(_active_progress_path):
		return
	var progress := _read_json_dictionary(_active_progress_path)
	if progress.is_empty():
		return
	var stage_id := str(progress.get("Stage", "build"))
	# Windows PowerShell 5.1 читает UTF-8 scripts без BOM через системную
	# code page. Поэтому пользовательский текст берём только из GDScript,
	# а JSON сборщика используем как ASCII-протокол идентификаторов этапов.
	var message := str(BUILD_STAGE_LABELS.get(stage_id, "Выполняется сборка…"))
	var percent := int(progress.get("Percent", 0))
	var destination := str(progress.get("OutputPath", _active_build_output_path))
	if _active_build_installs:
		destination = _get_default_install_path()
	_update_operation_progress(
		message,
		"Тема: %s\nНазначение: %s\nПрогресс обновляется автоматически."
		% [_active_build_theme_id, destination],
		percent,
	)


func _begin_operation_progress(
	title: String,
	stage: String,
	details: String,
	percent: int = 0,
) -> void:
	_message_dialog.hide()
	_progress_dialog.hide()
	_progress_dialog.title = title
	_progress_dialog.get_ok_button().disabled = true
	_progress_stage.modulate = Color.WHITE
	_update_operation_progress(stage, details, percent)
	_progress_dialog.popup_centered_clamped(PROGRESS_DIALOG_SIZE, 0.9)


func _update_operation_progress(stage: String, details: String, percent: int) -> void:
	_progress_stage.text = stage
	_progress_bar.value = clampi(percent, 0, 100)
	_progress_details.text = details


func _finish_operation_progress(title: String, details: String, is_error := false) -> void:
	_progress_dialog.title = "Ошибка управления темами" if is_error else title
	_progress_stage.text = title
	_progress_stage.modulate = Color(1.0, 0.55, 0.45) if is_error else Color(0.55, 0.9, 0.6)
	_progress_bar.value = 100.0
	_progress_details.text = details
	_progress_dialog.get_ok_button().disabled = false
	if not _progress_dialog.visible:
		_progress_dialog.popup_centered_clamped(PROGRESS_DIALOG_SIZE, 0.9)


func _create_and_activate_theme(theme_id: String, display_name: String) -> void:
	_busy = true
	_begin_operation_progress(
		"Создание темы",
		"Проверка параметров новой темы…",
		"ID: %s\nНазвание: %s" % [theme_id, display_name],
		5,
	)
	var created: bool = await _create_theme(theme_id, display_name)
	if not created:
		_busy = false
		return
	await _activate_theme(
		theme_id,
		"Тема «%s» создана и выбрана." % display_name,
		true,
	)


func _create_theme(theme_id: String, display_name: String) -> bool:
	_update_operation_progress(
		"Проверка ID и путей…",
		"ID: %s\nПроверяется themes/%s/." % [theme_id, theme_id],
		10,
	)
	await get_tree().process_frame
	if _theme_id_regex.search(theme_id) == null or display_name.is_empty():
		_finish_operation_progress("Тема не создана", "Некорректные данные новой темы.", true)
		return false

	var source_path := ProjectSettings.globalize_path(THEMES_ROOT.path_join(EXAMPLE_THEME_ID)).simplify_path()
	var themes_path := ProjectSettings.globalize_path(THEMES_ROOT).simplify_path()
	var destination_path := themes_path.path_join(theme_id).simplify_path()
	if not DirAccess.dir_exists_absolute(source_path):
		_finish_operation_progress("Тема не создана", "Не найдена тема-шаблон themes/example.", true)
		return false
	if destination_path.get_base_dir() != themes_path or DirAccess.dir_exists_absolute(destination_path):
		_finish_operation_progress(
			"Тема не создана",
			"Небезопасный или уже существующий путь новой темы.",
			true,
		)
		return false

	_update_operation_progress(
		"Копирование темы-шаблона…",
		"Источник: themes/example/\nНазначение: themes/%s/" % theme_id,
		30,
	)
	await get_tree().process_frame
	var copy_error := _copy_directory_recursive(source_path, destination_path)
	if copy_error != OK:
		_remove_created_theme(destination_path, themes_path)
		_finish_operation_progress(
			"Тема не создана",
			"Не удалось скопировать example: ошибка %s." % error_string(copy_error),
			true,
		)
		return false

	_update_operation_progress(
		"Запись manifest.json…",
		"Назначаются ThemeId и DisplayName новой темы.",
		55,
	)
	await get_tree().process_frame
	var manifest_path := destination_path.path_join("package/manifest.json")
	var manifest := _read_json_dictionary(manifest_path)
	if manifest.is_empty():
		_remove_created_theme(destination_path, themes_path)
		_finish_operation_progress(
			"Тема не создана",
			"В example отсутствует корректный manifest.json.",
			true,
		)
		return false
	manifest["ThemeId"] = theme_id
	manifest["DisplayName"] = display_name
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_remove_created_theme(destination_path, themes_path)
		_finish_operation_progress("Тема не создана", "Не удалось записать manifest новой темы.", true)
		return false
	manifest_file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	_update_operation_progress(
		"Тема создана. Выполняется активация…",
		"Исходники готовы: themes/%s/package/." % theme_id,
		65,
	)
	return true


func _copy_directory_recursive(source_path: String, destination_path: String) -> Error:
	var make_error := DirAccess.make_dir_recursive_absolute(destination_path)
	if make_error != OK:
		return make_error
	var source_directory := DirAccess.open(source_path)
	if source_directory == null:
		return DirAccess.get_open_error()
	source_directory.list_dir_begin()
	while true:
		var entry_name := source_directory.get_next()
		if entry_name.is_empty():
			break
		if (
			entry_name == "."
			or entry_name == ".."
			or entry_name == ".gdignore"
			or entry_name.get_extension() == "import"
			or entry_name.get_extension() == "uid"
		):
			continue
		var source_entry := source_path.path_join(entry_name)
		var destination_entry := destination_path.path_join(entry_name)
		var entry_error := OK
		if source_directory.current_is_dir():
			entry_error = _copy_directory_recursive(source_entry, destination_entry)
		else:
			entry_error = DirAccess.copy_absolute(source_entry, destination_entry)
		if entry_error != OK:
			source_directory.list_dir_end()
			return entry_error
	source_directory.list_dir_end()
	return OK


func _remove_created_theme(destination_path: String, themes_path: String) -> void:
	if destination_path.get_base_dir() != themes_path:
		return
	_remove_directory_recursive(destination_path)


func _remove_directory_recursive(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var entry_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_remove_directory_recursive(entry_path)
		else:
			DirAccess.remove_absolute(entry_path)
	directory.list_dir_end()
	DirAccess.remove_absolute(directory_path)


func _activate_theme(
	theme_id: String,
	success_message: String = "",
	continuing_operation: bool = false,
) -> void:
	if _busy and not continuing_operation:
		return
	_busy = true
	if not continuing_operation:
		_begin_operation_progress(
			"Выбор темы",
			"Подготовка preview…",
			"Тема: %s" % theme_id,
			5,
		)
	var was_playing := EditorInterface.is_playing_scene()
	_update_operation_progress(
		"Остановка запущенного preview…" if was_playing else "Подготовка редактора…",
		"Тема: %s\nТекущее состояние preview сохранено." % theme_id,
		70 if continuing_operation else 15,
	)
	await get_tree().process_frame
	if was_playing:
		EditorInterface.stop_playing_scene()
		await get_tree().process_frame

	_update_operation_progress(
		"Активация темы…",
		"Обновляется build/active-theme.json для ID %s." % theme_id,
		78 if continuing_operation else 40,
	)
	await get_tree().process_frame
	var output: Array = []
	var script_path := ProjectSettings.globalize_path(ACTIVATE_SCRIPT_PATH)
	var exit_code := OS.execute(
		"powershell.exe",
		PackedStringArray([
			"-NoLogo",
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			script_path,
			"-ThemeId",
			theme_id,
		]),
		output,
		true,
		false,
	)
	if exit_code != 0:
		_busy = false
		_finish_operation_progress(
			"Тема не выбрана",
			"Не удалось выбрать тему «%s».\n\n%s" % [theme_id, _join_output(output)],
			true,
		)
		return

	_update_operation_progress(
		"Обновление ресурсов редактора…",
		"Godot сканирует package выбранной темы и открывает общую preview-сцену.",
		90 if continuing_operation else 75,
	)
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().process_frame
	EditorInterface.open_scene_from_path(PREVIEW_SCENE_PATH)
	if was_playing:
		_update_operation_progress(
			"Повторный запуск preview…",
			"Ожидание обновления импортированных ресурсов.",
			96 if continuing_operation else 90,
		)
		await get_tree().create_timer(0.6).timeout
		EditorInterface.play_main_scene()

	_busy = false
	var message := success_message
	if message.is_empty():
		message = "Тема «%s» выбрана и открыта напрямую из package." % theme_id
	_finish_operation_progress("Тема выбрана", message)


func _join_output(output: Array) -> String:
	var text := ""
	for line in output:
		text += str(line)
	return text.strip_edges()


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _show_message(message: String, is_error := false) -> void:
	_message_dialog.hide()
	_message_dialog.get_ok_button().disabled = false
	_message_dialog.title = "Ошибка управления темами" if is_error else "Темы Exchanger"
	_message_dialog.dialog_text = message
	_message_dialog.popup_centered_clamped(MESSAGE_DIALOG_SIZE, 0.9)
