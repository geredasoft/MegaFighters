@tool
extends EditorInspectorPlugin

var palette_set: LivePaletteSet
var undo: EditorUndoRedoManager


func setup(p_set: LivePaletteSet, p_undo: EditorUndoRedoManager) -> void:
	palette_set = p_set
	undo = p_undo


func _can_handle(p_object: Object) -> bool:
	return not (p_object is LivePaletteData)


func _parse_property(p_object: Object, p_type: Variant.Type, p_name: String, p_hint: PropertyHint, p_hint_string: String, p_usage: int, p_wide: bool) -> bool:
	if p_type == TYPE_COLOR:
		add_property_editor(p_name, PaletteProp.new(palette_set, undo), true, "Palette")
	return false


class PaletteProp:
	extends EditorProperty

	const COLUMNS := 8
	const CELL := 24

	var _set: LivePaletteSet
	var _undo: EditorUndoRedoManager
	var _btn := Button.new()
	var _popup := PopupPanel.new()
	var _groups := VBoxContainer.new()
	var _unlink := Button.new()
	var _empty := Label.new()

	func _init(p_set: LivePaletteSet, p_undo: EditorUndoRedoManager) -> void:
		_set = p_set
		_undo = p_undo
		_btn.text = "Palette..."
		_btn.clip_text = true
		_btn.pressed.connect(_open_popup)
		add_child(_btn)
		add_focusable(_btn)
		var vb := VBoxContainer.new()
		_popup.add_child(vb)
		vb.add_child(_groups)
		_empty.text = "(no colors yet)"
		vb.add_child(_empty)
		_unlink.text = "Unlink"
		_unlink.pressed.connect(func() -> void: _pick(""))
		vb.add_child(_unlink)
		add_child(_popup)
		for stem in _set.palettes:
			(_set.palettes[stem] as LivePaletteData).changed.connect(update_property)

	func _open_popup() -> void:
		for c in _groups.get_children():
			_groups.remove_child(c)
			c.queue_free()
		var cur := _current_id()
		var side := CELL * EditorInterface.get_editor_scale()
		var stems := _set.stems()
		var total := 0
		for stem in stems:
			var data: LivePaletteData = _set.get_palette(String(stem))
			if data == null or data.entries.is_empty():
				continue
			total += data.entries.size()
			if stems.size() > 1:
				var title := Label.new()
				title.text = String(stem).capitalize()
				title.modulate = Color(1, 1, 1, 0.6)
				_groups.add_child(title)
			var grid := GridContainer.new()
			grid.columns = COLUMNS
			_groups.add_child(grid)
			for e in data.entries:
				grid.add_child(_make_cell(data, e, cur, side))
		_empty.visible = total == 0
		_unlink.visible = not cur.is_empty()
		_popup.reset_size()
		_popup.popup_on_parent(Rect2i(Vector2i(_btn.get_global_position() + Vector2(0, _btn.size.y)), _popup.size))

	func _make_cell(p_data: LivePaletteData, p_entry: Dictionary, p_current: String, p_side: float) -> Button:
		var id := str(p_entry["id"])
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(p_side, p_side)
		var swatch_color: Color = p_data.color_of(p_entry)
		cell.tooltip_text = "%s\n%s" % [p_entry["name"], LivePaletteData.hex(swatch_color)]
		cell.add_theme_stylebox_override(&"normal", _cell_style(swatch_color, id == p_current))
		var hi := _cell_style(swatch_color, true)
		cell.add_theme_stylebox_override(&"hover", hi)
		cell.add_theme_stylebox_override(&"pressed", hi)
		cell.add_theme_stylebox_override(&"focus", hi)
		cell.pressed.connect(func() -> void: _pick(id))
		return cell

	static func _cell_style(p_color: Color, p_outlined: bool) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = p_color
		if p_outlined:
			sb.set_border_width_all(2)
			sb.border_color = Color.WHITE
		return sb

	func _current_id() -> String:
		var obj := get_edited_object()
		if not obj:
			return ""
		var b: Dictionary = obj.get_meta(LivePaletteData.META, {})
		return str(b.get(str(get_edited_property()), ""))

	func _pick(p_entry_id: String) -> void:
		_popup.hide()
		var entry_id := p_entry_id
		var obj := get_edited_object()
		var prop := str(get_edited_property())
		var old_meta: Dictionary = (obj.get_meta(LivePaletteData.META, {}) as Dictionary).duplicate()
		var new_meta := old_meta.duplicate()
		var action_name := "Palette: bind %s" % prop
		if entry_id.is_empty():
			new_meta.erase(prop)
			action_name = "Palette: unlink %s" % prop
		else:
			new_meta[prop] = entry_id
		_undo.create_action(action_name)
		if not entry_id.is_empty():
			_undo.add_do_property(obj, prop, _set.get_color_by_id(entry_id))
			_undo.add_undo_property(obj, prop, obj.get(prop))
		if new_meta.is_empty():
			_undo.add_do_method(obj, &"remove_meta", LivePaletteData.META)
		else:
			_undo.add_do_method(obj, &"set_meta", LivePaletteData.META, new_meta)
		if old_meta.is_empty():
			_undo.add_undo_method(obj, &"remove_meta", LivePaletteData.META)
		else:
			_undo.add_undo_method(obj, &"set_meta", LivePaletteData.META, old_meta)
		_undo.commit_action()
		update_property()

	func _update_property() -> void:
		var id := _current_id()
		if id.is_empty():
			_btn.text = "Palette..."
			_btn.icon = null
			return
		var found := _set.find_entry(id)
		if found.is_empty():
			_btn.text = "missing: %s" % id
			_btn.icon = null
		else:
			var data: LivePaletteData = found["palette"]
			var entry: Dictionary = data.entries[found["index"]]
			_btn.text = str(entry["name"])
			_btn.icon = _swatch(data.color_of(entry))

	func _set_read_only(p_read_only: bool) -> void:
		_btn.disabled = p_read_only

	static func _swatch(p_color: Color) -> ImageTexture:
		var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(p_color)
		return ImageTexture.create_from_image(img)
