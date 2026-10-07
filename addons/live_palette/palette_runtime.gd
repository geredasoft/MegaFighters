extends Node

signal variant_changed(variant: String)

const PALETTE_PATH := "res://live_palette/palette.tres"

var _set: LivePaletteSet


func _enter_tree() -> void:
	_set = LivePaletteSet.new()
	_set.load_all()
	get_tree().node_added.connect(_on_node_added)
	_set.apply_to_tree(get_tree().root)


func _on_node_added(p_node: Node) -> void:
	_set.apply_to_object(p_node, {})


func apply(p_object: Object) -> int:
	return _set.apply_to_object(p_object, {})


func palettes() -> Dictionary:
	return _set.palettes


func get_palette(p_stem: String) -> LivePaletteData:
	return _set.get_palette(p_stem)


func color(p_name: StringName, p_stem: String = "") -> Color:
	return _set.get_color_by_name(p_name, p_stem)


func has_color(p_name: StringName) -> bool:
	return _set.has_color_name(p_name)


func set_variant(p_variant: String) -> bool:
	var switched := _set.set_variant(p_variant)
	if switched == 0:
		push_warning("LivePalette: no palette has a variant named '%s'" % p_variant)
		return false
	_set.apply_to_tree(get_tree().root)
	variant_changed.emit(p_variant)
	return true


func get_variant(p_stem: String = LivePaletteSet.DEFAULT_STEM) -> String:
	var data := _set.get_palette(p_stem)
	return data.active_variant if data else ""


func variants() -> PackedStringArray:
	return _set.variant_names()
