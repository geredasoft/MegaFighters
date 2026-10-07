@tool
extends VBoxContainer

signal generate_requested
signal palette_created(stem: String)

const SWATCH_SIZE := 24
const DRAG_KEY := "live_palette_entry"
const SCAN_EXTENSIONS := ["tscn", "escn", "tres", "theme"]

var palette: LivePaletteData
var palette_set: LivePaletteSet
var undo: EditorUndoRedoManager
var _stem: String = LivePaletteSet.DEFAULT_STEM
var _palette_picker: OptionButton

var _rows: VBoxContainer
var _drop_row := -1
var _empty_hint: Label
var _uses_dlg: AcceptDialog
var _uses_list: ItemList
var _variant_picker: OptionButton
var _variant_dialog: AcceptDialog
var _variant_field: LineEdit
var _variant_action := ""


func setup(p_set: LivePaletteSet, p_undo: EditorUndoRedoManager) -> void:
	palette_set = p_set
	undo = p_undo
	if not palette_set.palettes.has(_stem):
		_stem = String(palette_set.stems()[0]) if not palette_set.is_empty() else LivePaletteSet.DEFAULT_STEM
	palette = palette_set.get_palette(_stem)
	for stem in palette_set.palettes:
		var data: LivePaletteData = palette_set.palettes[stem]
		if not data.changed.is_connected(_sync):
			data.changed.connect(_sync)


func select_palette(p_stem: String) -> void:
	if not palette_set.palettes.has(p_stem):
		return
	_stem = p_stem
	palette = palette_set.get_palette(p_stem)
	_sync_palettes()
	_sync_variants()
	_rebuild()


func _ready() -> void:
	var palette_bar := HBoxContainer.new()
	_palette_picker = OptionButton.new()
	_palette_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_picker.tooltip_text = "Which palette these rows edit.\nEvery palette applies at once; each has its own colors, variants and generated class."
	_palette_picker.item_selected.connect(_on_palette_selected)
	palette_bar.add_child(_palette_picker)
	var add_palette := Button.new()
	add_palette.icon = get_theme_icon(&"Add", &"EditorIcons")
	add_palette.tooltip_text = "Create another palette (a separate .tres and generated class)"
	add_palette.pressed.connect(_ask_palette_name)
	palette_bar.add_child(add_palette)
	add_child(palette_bar)

	var bar := HBoxContainer.new()
	_variant_picker = OptionButton.new()
	_variant_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variant_picker.tooltip_text = "The variant shown here and applied to open scenes.\nAt runtime: LivePaletteRuntime.set_variant(\"...\")."
	_variant_picker.item_selected.connect(_on_variant_selected)
	bar.add_child(_variant_picker)
	var add_variant := Button.new()
	add_variant.icon = get_theme_icon(&"Add", &"EditorIcons")
	add_variant.tooltip_text = "Add a variant, copying the current one"
	add_variant.pressed.connect(func() -> void: _ask_variant_name("add"))
	bar.add_child(add_variant)
	var rename_variant := Button.new()
	rename_variant.icon = get_theme_icon(&"Rename", &"EditorIcons")
	rename_variant.tooltip_text = "Rename this variant"
	rename_variant.pressed.connect(func() -> void: _ask_variant_name("rename"))
	bar.add_child(rename_variant)
	var drop_variant := Button.new()
	drop_variant.icon = get_theme_icon(&"Remove", &"EditorIcons")
	drop_variant.tooltip_text = "Delete this variant (the last one cannot be deleted)"
	drop_variant.pressed.connect(_on_variant_removed)
	bar.add_child(drop_variant)
	add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.set_drag_forwarding(Callable(), _list_can_drop, _list_drop)
	scroll.add_child(list)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.draw.connect(_draw_drop_indicator)
	list.add_child(_rows)
	_empty_hint = Label.new()
	_empty_hint.text = "Empty palette — add a color below"
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.modulate = Color(1, 1, 1, 0.45)
	list.add_child(_empty_hint)
	var add_btn := Button.new()
	add_btn.text = "Add Color"
	add_btn.icon = get_theme_icon(&"Add", &"EditorIcons")
	add_btn.pressed.connect(_on_add_pressed)
	list.add_child(add_btn)
	var gen_btn := Button.new()
	gen_btn.text = "Regenerate Constants"
	gen_btn.icon = get_theme_icon(&"Reload", &"EditorIcons")
	gen_btn.tooltip_text = "Rewrite res://live_palette/palette_const.gd — the LivePalette.MY_COLOR API.\nIt is kept in sync automatically; use this if the file was deleted or edited by hand."
	gen_btn.pressed.connect(func() -> void: generate_requested.emit())
	add_child(gen_btn)
	var io := HBoxContainer.new()
	var imp := Button.new()
	imp.text = "Import"
	imp.icon = get_theme_icon(&"Load", &"EditorIcons")
	imp.tooltip_text = "Append colors from a GIMP .gpl palette file (the format Lospec, Aseprite and Krita export)."
	imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imp.pressed.connect(func() -> void: _pick_gpl_file(false))
	io.add_child(imp)
	var exp := Button.new()
	exp.text = "Export"
	exp.icon = get_theme_icon(&"Save", &"EditorIcons")
	exp.tooltip_text = "Write the palette as a GIMP .gpl file. The format is RGB — alpha is flattened."
	exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp.pressed.connect(func() -> void: _pick_gpl_file(true))
	io.add_child(exp)
	add_child(io)
	_sync_palettes()
	_sync_variants()
	_rebuild()


func _sync_palettes() -> void:
	if _palette_picker == null or palette_set == null:
		return
	_palette_picker.clear()
	var stems := palette_set.stems()
	for i in stems.size():
		_palette_picker.add_item(String(stems[i]).capitalize(), i)
		if stems[i] == _stem:
			_palette_picker.select(i)
	_palette_picker.visible = stems.size() > 1


func _on_palette_selected(p_index: int) -> void:
	var stems := palette_set.stems()
	if p_index < stems.size():
		select_palette(String(stems[p_index]))


func _ask_palette_name() -> void:
	_variant_action = "palette"
	_ensure_name_dialog()
	_variant_dialog.title = "New palette (file name)"
	_variant_field.text = ""
	_variant_dialog.popup_centered()
	_variant_field.grab_focus()


func _create_palette(p_name: String) -> void:
	var stem := p_name.to_snake_case()
	if stem.is_empty() or palette_set.palettes.has(stem):
		push_warning("LivePalette: '%s' is not a usable new palette name" % p_name)
		return
	var path := "%s/%s.tres" % [LivePaletteSet.DIR, stem]
	var created := LivePaletteData.new()
	if ResourceSaver.save(created, path) != OK:
		push_error("LivePalette: could not create %s" % path)
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	palette_created.emit(stem)


func _sync_variants() -> void:
	if _variant_picker == null:
		return
	_variant_picker.clear()
	for i in palette.variants.size():
		_variant_picker.add_item(palette.variants[i], i)
		if palette.variants[i] == palette.active_variant:
			_variant_picker.select(i)


func _on_variant_selected(p_index: int) -> void:
	var chosen := String(_variant_picker.get_item_text(p_index))
	if chosen == palette.active_variant:
		return
	undo.create_action("Palette: switch variant")
	undo.add_do_method(palette, &"set_active_variant", chosen)
	undo.add_undo_method(palette, &"set_active_variant", palette.active_variant)
	undo.commit_action()


func _ensure_name_dialog() -> void:
	if _variant_dialog != null:
		return
	_variant_dialog = AcceptDialog.new()
	_variant_field = LineEdit.new()
	_variant_field.custom_minimum_size = Vector2(240, 0) * EditorInterface.get_editor_scale()
	_variant_dialog.add_child(_variant_field)
	_variant_dialog.register_text_enter(_variant_field)
	_variant_dialog.confirmed.connect(_on_variant_name_confirmed)
	add_child(_variant_dialog)


func _ask_variant_name(p_action: String) -> void:
	_variant_action = p_action
	_ensure_name_dialog()
	_variant_dialog.title = "New variant" if p_action == "add" else "Rename variant"
	_variant_field.text = palette.active_variant if p_action == "rename" else ""
	_variant_dialog.popup_centered()
	_variant_field.grab_focus()
	_variant_field.select_all()


func _on_variant_name_confirmed() -> void:
	var wanted := _variant_field.text.strip_edges()
	if wanted.is_empty():
		return
	if _variant_action == "palette":
		_create_palette(wanted)
		return
	if wanted in palette.variants:
		return
	if _variant_action == "add":
		undo.create_action("Palette: add variant")
		undo.add_do_method(palette, &"add_variant", wanted, palette.active_variant)
		undo.add_do_method(palette, &"set_active_variant", wanted)
		undo.add_undo_method(palette, &"set_active_variant", palette.active_variant)
		undo.add_undo_method(palette, &"remove_variant", wanted)
		undo.commit_action()
	else:
		var previous := palette.active_variant
		undo.create_action("Palette: rename variant")
		undo.add_do_method(palette, &"rename_variant", previous, wanted)
		undo.add_undo_method(palette, &"rename_variant", wanted, previous)
		undo.commit_action()


func _on_variant_removed() -> void:
	if palette.variants.size() <= 1:
		push_warning("LivePalette: a palette keeps at least one variant")
		return
	var doomed := palette.active_variant
	var colors := {}
	for e in palette.entries:
		colors[e["id"]] = palette.color_of(e, doomed)
	undo.create_action("Palette: remove variant")
	undo.add_do_method(palette, &"remove_variant", doomed)
	undo.add_undo_method(palette, &"add_variant", doomed, palette.base_variant())
	for id in colors:
		undo.add_undo_method(palette, &"set_color", id, colors[id], doomed)
	undo.add_undo_method(palette, &"set_active_variant", doomed)
	undo.commit_action()


func _sync() -> void:
	if not is_instance_valid(_rows):
		return
	_sync_variants()
	var ids: Array = palette.entries.map(func(e: Dictionary) -> Variant: return e["id"])
	if _row_ids() != ids:
		_rebuild()
		return
	for i in _rows.get_child_count():
		var row := _rows.get_child(i)
		var pick: ColorPickerButton = row.get_node("Pick")
		var edit: LineEdit = row.get_node("Name")
		pick.color = palette.color_of(palette.entries[i])
		pick.tooltip_text = LivePaletteData.hex(pick.color)
		if not edit.has_focus():
			edit.text = str(palette.entries[i]["name"])


func _row_ids() -> Array:
	var ids := []
	for row in _rows.get_children():
		ids.append(row.get_meta(&"entry_id"))
	return ids


func _rebuild() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for e in palette.entries:
		_rows.add_child(_make_row(e))
	_empty_hint.visible = palette.entries.is_empty()


func _make_row(p_entry: Dictionary) -> HBoxContainer:
	var id: String = p_entry["id"]
	var row := HBoxContainer.new()
	row.set_meta(&"entry_id", id)
	row.set_drag_forwarding(_drag_entry.bind(id, row), _row_can_drop.bind(row), _row_drop.bind(row))

	var grip := TextureRect.new()
	grip.texture = get_theme_icon(&"TripleBar", &"EditorIcons")
	grip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.tooltip_text = "Drag to reorder"
	grip.set_drag_forwarding(_drag_entry.bind(id, grip), Callable(), Callable())
	row.add_child(grip)

	var pick := ColorPickerButton.new()
	pick.name = "Pick"
	var side := SWATCH_SIZE * EditorInterface.get_editor_scale()
	pick.custom_minimum_size = Vector2(side, side)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	pick.color = palette.color_of(p_entry)
	pick.tooltip_text = LivePaletteData.hex(pick.color)
	var pre_edit := [Color.WHITE]
	pick.pressed.connect(func() -> void:
		pre_edit[0] = palette.get_color_by_id(id))
	pick.color_changed.connect(func(p_color: Color) -> void:
		palette.set_color(id, p_color))
	pick.popup_closed.connect(func() -> void:
		if not pick.color.is_equal_approx(pre_edit[0]):
			undo.create_action("Palette: set color")
			undo.add_do_method(palette, &"set_color", id, pick.color)
			undo.add_undo_method(palette, &"set_color", id, pre_edit[0])
			undo.commit_action())
	row.add_child(pick)

	var edit := LineEdit.new()
	edit.name = "Name"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text = str(p_entry["name"])
	var commit_rename := func() -> void:
		var i := palette.find_index(id)
		if i < 0:
			return
		var old_name: String = palette.entries[i]["name"]
		if edit.text.is_empty() or edit.text == old_name:
			edit.text = old_name
			return
		undo.create_action("Palette: rename color")
		undo.add_do_method(palette, &"rename_entry", id, edit.text)
		undo.add_undo_method(palette, &"rename_entry", id, old_name)
		undo.commit_action()
		var settled := palette.find_index(id)
		if settled >= 0:
			edit.text = str(palette.entries[settled]["name"])
	edit.text_submitted.connect(func(_t: String) -> void: commit_rename.call())
	edit.focus_exited.connect(commit_rename)
	row.add_child(edit)

	var find := Button.new()
	find.icon = get_theme_icon(&"Search", &"EditorIcons")
	find.tooltip_text = "Find uses of this color in saved scenes and resources"
	find.pressed.connect(func() -> void: _find_uses(id))
	row.add_child(find)

	var del := Button.new()
	del.icon = get_theme_icon(&"Remove", &"EditorIcons")
	del.tooltip_text = "Remove color (existing links keep their last color)"
	del.pressed.connect(func() -> void:
		var i := palette.find_index(id)
		if i < 0:
			return
		var e: Dictionary = palette.entries[i].duplicate(true)
		undo.create_action("Palette: remove color")
		undo.add_do_method(palette, &"remove_entry", id)
		undo.add_undo_method(palette, &"add_entry", id, e["name"], palette.color_of(e), i)
		for variant in palette.variants:
			undo.add_undo_method(palette, &"set_color", id, palette.color_of(e, variant), variant)
		undo.commit_action())
	row.add_child(del)
	return row


func _drag_entry(_at: Vector2, p_id: String, p_from: Control) -> Variant:
	var i := palette.find_index(p_id)
	if i < 0:
		return null
	var side := SWATCH_SIZE * EditorInterface.get_editor_scale()
	var preview := ColorRect.new()
	preview.color = palette.color_of(palette.entries[i])
	preview.custom_minimum_size = Vector2(side, side)
	preview.size = Vector2(side, side)
	p_from.set_drag_preview(preview)
	return {DRAG_KEY: p_id}


func _row_can_drop(p_at: Vector2, p_data: Variant, p_row: Control) -> bool:
	if not (p_data is Dictionary and p_data.has(DRAG_KEY)):
		return false
	_set_drop_row(_drop_before(p_row, p_at.y))
	return true


func _row_drop(p_at: Vector2, p_data: Variant, p_row: Control) -> void:
	_commit_move(str(p_data[DRAG_KEY]), _drop_before(p_row, p_at.y))


func _list_can_drop(_at: Vector2, p_data: Variant) -> bool:
	if not (p_data is Dictionary and p_data.has(DRAG_KEY)):
		return false
	_set_drop_row(_rows.get_child_count())
	return true


func _list_drop(_at: Vector2, p_data: Variant) -> void:
	_commit_move(str(p_data[DRAG_KEY]), _rows.get_child_count())


func _commit_move(p_id: String, p_before: int) -> void:
	var from := palette.find_index(p_id)
	var to := final_index(from, p_before)
	_set_drop_row(-1)
	if from < 0 or to == from:
		return
	undo.create_action("Palette: reorder colors")
	undo.add_do_method(palette, &"move_entry", p_id, to)
	undo.add_undo_method(palette, &"move_entry", p_id, from)
	undo.commit_action()


func _drop_before(p_row: Control, p_local_y: float) -> int:
	return p_row.get_index() if p_local_y < p_row.size.y * 0.5 else p_row.get_index() + 1


static func final_index(p_from: int, p_before: int) -> int:
	return p_before - 1 if p_from < p_before else p_before


func _set_drop_row(p_before: int) -> void:
	if _drop_row != p_before:
		_drop_row = p_before
		_rows.queue_redraw()


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_DRAG_END:
		_set_drop_row(-1)


func _draw_drop_indicator() -> void:
	if _drop_row < 0:
		return
	var y := _rows.size.y
	if _drop_row < _rows.get_child_count():
		y = (_rows.get_child(_drop_row) as Control).position.y
	_rows.draw_line(Vector2(0, y), Vector2(_rows.size.x, y), get_theme_color(&"accent_color", &"Editor"), 2.0)


func _pick_gpl_file(p_save: bool) -> void:
	var dlg := EditorFileDialog.new()
	dlg.access = EditorFileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if p_save else EditorFileDialog.FILE_MODE_OPEN_FILE
	dlg.add_filter("*.gpl", "GIMP Palette")
	dlg.title = "Export Palette as .gpl" if p_save else "Import .gpl Palette"
	if p_save:
		dlg.current_file = "palette.gpl"
	dlg.file_selected.connect(_export_gpl if p_save else _import_gpl)
	dlg.canceled.connect(dlg.queue_free)
	dlg.file_selected.connect(func(_path: String) -> void: dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered_ratio(0.5)


func _import_gpl(p_path: String) -> void:
	var parsed := LivePaletteData.parse_gpl(FileAccess.get_file_as_string(p_path))
	if parsed.is_empty():
		push_warning("LivePalette: nothing importable in %s" % p_path)
		return
	var taken := {}
	undo.create_action("Palette: import %s" % p_path.get_file())
	for i in parsed.size():
		var id := palette_set.new_id()
		while taken.has(id):
			id = palette_set.new_id()
		taken[id] = true
		var entry_name := str(parsed[i]["name"])
		if entry_name.is_empty():
			entry_name = "Color %d" % (palette.entries.size() + i + 1)
		undo.add_do_method(palette, &"add_entry", id, entry_name, parsed[i]["color"], -1)
		undo.add_undo_method(palette, &"remove_entry", id)
	undo.commit_action()


func _export_gpl(p_path: String) -> void:
	var f := FileAccess.open(p_path, FileAccess.WRITE)
	if f == null:
		push_error("LivePalette: can't write %s (%s)" % [p_path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(palette.to_gpl(str(ProjectSettings.get_setting("application/config/name", "Palette"))))
	f.close()


func _find_uses(p_id: String) -> void:
	var i := palette.find_index(p_id)
	if i < 0:
		return
	var hits: Array[Dictionary] = []
	var files := PackedStringArray()
	LivePaletteData.scan_bound_files("res://", SCAN_EXTENSIONS, files)
	for path in files:
		var n := LivePaletteData.find_uses_in_text(FileAccess.get_file_as_string(path), p_id)
		if n > 0:
			hits.append({"path": path, "count": n})
	if _uses_dlg == null:
		_uses_dlg = AcceptDialog.new()
		_uses_list = ItemList.new()
		_uses_list.custom_minimum_size = Vector2(420, 240) * EditorInterface.get_editor_scale()
		_uses_list.item_activated.connect(_on_use_activated)
		_uses_dlg.add_child(_uses_list)
		add_child(_uses_dlg)
	_uses_dlg.title = "Uses of \"%s\"" % palette.entries[i]["name"]
	_uses_list.clear()
	if hits.is_empty():
		_uses_list.add_item("No uses found in saved scenes/resources.")
		_uses_list.set_item_disabled(0, true)
	else:
		for h in hits:
			_uses_list.add_item("%s  (%d)" % [h["path"], h["count"]])
			_uses_list.set_item_metadata(_uses_list.item_count - 1, h["path"])
	_uses_dlg.popup_centered()


func _on_use_activated(p_index: int) -> void:
	var path := str(_uses_list.get_item_metadata(p_index))
	if path.get_extension() in ["tscn", "escn"]:
		EditorInterface.open_scene_from_path(path)
	else:
		EditorInterface.edit_resource(load(path))


func _on_add_pressed() -> void:
	var id := palette_set.new_id()
	undo.create_action("Palette: add color")
	undo.add_do_method(palette, &"add_entry", id, "Color %d" % (palette.entries.size() + 1), Color.WHITE, -1)
	undo.add_undo_method(palette, &"remove_entry", id)
	undo.commit_action()
