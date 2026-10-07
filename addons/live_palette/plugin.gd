@tool
extends EditorPlugin

const DATA_DIR := "res://live_palette"
const PALETTE_PATH := DATA_DIR + "/palette.tres"
const CONST_SCRIPT_PATH := DATA_DIR + "/palette_const.gd"
const CONST_CLASS := "LivePalette"
const RUNTIME_PATH := "res://addons/live_palette/palette_runtime.gd"
const AUTOLOAD_NAME := "LivePaletteRuntime"

var palette: LivePaletteData
var palette_set: LivePaletteSet
var dock
var inspector
var _save_timer: Timer
var _bound_files := PackedStringArray()
var _bound_files_stale := true
var _bound_pass_pending := false
var _dirty_files := {}


func _enter_tree() -> void:
	_migrate_legacy_autoload()
	if not ResourceLoader.exists(PALETTE_PATH):
		_ensure_data_dir()
		ResourceSaver.save(LivePaletteData.new(), PALETTE_PATH)
	palette_set = LivePaletteSet.new()
	_reload_palettes()
	palette = palette_set.get_palette(LivePaletteSet.DEFAULT_STEM)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	dock = load("res://addons/live_palette/dock.gd").new()
	dock.name = "Palette"
	dock.setup(palette_set, get_undo_redo())
	dock.generate_requested.connect(_write_const_script)
	dock.palette_created.connect(_on_palette_created)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	inspector = load("res://addons/live_palette/inspector_plugin.gd").new()
	inspector.setup(palette_set, get_undo_redo())
	add_inspector_plugin(inspector)
	scene_changed.connect(_on_scene_changed)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	_apply_all.call_deferred()
	_write_const_script.call_deferred()


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_on_filesystem_changed)
	remove_inspector_plugin(inspector)
	remove_control_from_docks(dock)
	dock.free()
	if _save_timer and not _save_timer.is_stopped():
		_flush_save()


func _enable_plugin() -> void:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == AUTOLOAD_NAME:
			push_error("LivePalette: can't register the '%s' autoload — that name is already a class_name in %s. Rename that class, or register the autoload yourself under a different name." % [AUTOLOAD_NAME, c["path"]])
			return
	add_autoload_singleton(AUTOLOAD_NAME, RUNTIME_PATH)


func _migrate_legacy_autoload() -> void:
	var key := "autoload/" + CONST_CLASS
	if not ProjectSettings.has_setting(key):
		return
	if not _resolve_autoload_path(str(ProjectSettings.get_setting(key))).ends_with("palette_runtime.gd"):
		return
	remove_autoload_singleton(CONST_CLASS)
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, RUNTIME_PATH)
	ProjectSettings.save()
	push_warning("LivePalette: renamed the leftover '%s' autoload from an older version to '%s'. Restart the editor if scripts still report a collision." % [CONST_CLASS, AUTOLOAD_NAME])


func _resolve_autoload_path(p_value: String) -> String:
	var v := p_value.trim_prefix("*")
	if v.begins_with("uid://"):
		var id := ResourceUID.text_to_id(v)
		return ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	return v


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _reload_palettes() -> void:
	palette_set.load_all()
	var repaired := palette_set.repair_duplicate_ids()
	for stem in palette_set.palettes:
		var data: LivePaletteData = palette_set.palettes[stem]
		if data.migrate() or stem in repaired:
			ResourceSaver.save(data)
		if not data.changed.is_connected(_on_palette_changed):
			data.changed.connect(_on_palette_changed)


func _on_palette_created(p_stem: String) -> void:
	_reload_palettes()
	palette = palette_set.get_palette(LivePaletteSet.DEFAULT_STEM)
	dock.setup(palette_set, get_undo_redo())
	dock.select_palette(p_stem)
	_write_const_script()


func _on_palette_changed() -> void:
	_apply_all()
	_bound_pass_pending = true
	_save_timer.start()


func _on_scene_changed(p_root: Node) -> void:
	if p_root and palette_set and palette_set.apply_to_tree(p_root, _dirty_files) > 0:
		EditorInterface.mark_scene_as_unsaved()
	_queue_dirty_save()


func _on_filesystem_changed() -> void:
	_bound_files_stale = true


func _apply_all() -> void:
	var current := EditorInterface.get_edited_scene_root()
	for root in _open_roots():
		if palette_set.apply_to_tree(root, _dirty_files) > 0 and root == current:
			EditorInterface.mark_scene_as_unsaved()
	var obj := EditorInterface.get_inspector().get_edited_object()
	if obj != null and not obj is LivePaletteData:
		palette_set.apply_to_object(obj, {}, _dirty_files)
	_queue_dirty_save()


func _queue_dirty_save() -> void:
	if not _dirty_files.is_empty() and _save_timer.is_stopped():
		_save_timer.start()


func _open_roots() -> Array:
	if EditorInterface.has_method("get_open_scene_roots"):
		return EditorInterface.call("get_open_scene_roots")
	var r := EditorInterface.get_edited_scene_root()
	return [r] if r else []


func _flush_save() -> void:
	_save_timer.stop()
	for stem in palette_set.palettes:
		ResourceSaver.save(palette_set.palettes[stem])
	_write_const_script()
	_save_bound_files()
	var obj := EditorInterface.get_inspector().get_edited_object()
	if obj:
		obj.notify_property_list_changed()


func _save_bound_files() -> void:
	var held := {}
	if _bound_pass_pending:
		_bound_pass_pending = false
		_refresh_bound_files()
		for path in _bound_files:
			var res: Resource = load(path)
			if res != null:
				held[path] = res
				palette_set.apply_to_object(res, {}, _dirty_files)
	if _dirty_files.is_empty():
		return
	var fs := EditorInterface.get_resource_filesystem()
	for path in _dirty_files:
		if not _is_bound_file_writable(path):
			continue
		var res: Resource = held[path] if held.has(path) else load(path)
		if res == null:
			continue
		var err := ResourceSaver.save(res, path)
		if err != OK:
			push_warning("LivePalette: could not rewrite %s with its palette colors (%s)" % [path, error_string(err)])
			continue
		fs.update_file(path)
	_dirty_files.clear()


func _refresh_bound_files() -> void:
	if not _bound_files_stale:
		return
	_bound_files_stale = false
	_bound_files.clear()
	var found := PackedStringArray()
	LivePaletteData.scan_bound_files("res://", ["tres"], found)
	for path in found:
		if _is_bound_file_writable(path):
			_bound_files.append(path)


func _is_bound_file_writable(p_path: String) -> bool:
	if p_path.get_extension() != "tres":
		return false
	return not p_path.begins_with("res://addons/") and not p_path.begins_with(LivePaletteSet.DIR + "/")


func _ensure_data_dir() -> void:
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		DirAccess.make_dir_recursive_absolute(DATA_DIR)


func _write_const_script() -> void:
	if ProjectSettings.has_setting("autoload/" + CONST_CLASS):
		push_error("LivePalette: an autoload named '%s' already exists, so the generated class can't use that name (Godot: \"hides an autoload singleton\"). Rename that autoload in Project Settings > Autoload, then delete %s to regenerate it." % [CONST_CLASS, CONST_SCRIPT_PATH])
		return
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == CONST_CLASS and str(c["path"]) != CONST_SCRIPT_PATH:
			push_error("LivePalette: can't generate %s — the class name '%s' is already used by %s." % [CONST_SCRIPT_PATH, CONST_CLASS, c["path"]])
			return
	_ensure_data_dir()
	_remove_stale_const_scripts()
	var text: String = palette_set.build_const_script()
	var existed := FileAccess.file_exists(CONST_SCRIPT_PATH)
	if existed and FileAccess.get_file_as_string(CONST_SCRIPT_PATH) == text:
		return
	var f := FileAccess.open(CONST_SCRIPT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("LivePalette: can't write %s (%s)" % [CONST_SCRIPT_PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()
	var fs := EditorInterface.get_resource_filesystem()
	fs.update_file(CONST_SCRIPT_PATH)
	if not existed:
		fs.scan()


func _remove_stale_const_scripts() -> void:
	for file in DirAccess.get_files_at(DATA_DIR):
		var path := "%s/%s" % [DATA_DIR, file]
		if not file.ends_with("_const.gd") or path == CONST_SCRIPT_PATH:
			continue
		if not FileAccess.get_file_as_string(path).begins_with("# Generated by the Live Palette addon"):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var uid_path := path + ".uid"
		if FileAccess.file_exists(uid_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(uid_path))
		EditorInterface.get_resource_filesystem().update_file(path)
		push_warning("LivePalette: removed %s; every palette is now reached through the single %s class (e.g. %s.UI.PANEL)." % [path, CONST_CLASS, CONST_CLASS])


func _save_external_data() -> void:
	if palette:
		_flush_save()


func _build() -> bool:
	if palette:
		_flush_save()
	return true
