@tool
class_name LivePaletteData
extends Resource

const META := &"_live_palette_bindings"
const DEFAULT_VARIANT := "Default"

@export var entries: Array[Dictionary] = []

@export var variants: PackedStringArray = PackedStringArray([DEFAULT_VARIANT])

@export var active_variant: String = DEFAULT_VARIANT


func find_index(p_id: String) -> int:
	for i in entries.size():
		if entries[i]["id"] == p_id:
			return i
	return -1


func get_color_by_id(p_id: String, p_variant: String = "") -> Color:
	var i := find_index(p_id)
	if i < 0:
		return Color.WHITE
	return color_of(entries[i], p_variant)


func get_color_by_name(p_name: StringName, p_variant: String = "") -> Color:
	for e in entries:
		if e["name"] == String(p_name):
			return color_of(e, p_variant)
	push_warning("LivePalette: no color named '%s'" % p_name)
	return Color.WHITE


func has_color_name(p_name: StringName) -> bool:
	for e in entries:
		if e["name"] == String(p_name):
			return true
	return false


func color_of(p_entry: Dictionary, p_variant: String = "") -> Color:
	if not p_entry.has("colors"):
		return p_entry.get("color", Color.WHITE)
	var colors: Dictionary = p_entry["colors"]
	var wanted: String = p_variant if p_variant != "" else active_variant
	if colors.has(wanted):
		return colors[wanted]
	var fallback: String = variants[0] if not variants.is_empty() else DEFAULT_VARIANT
	if colors.has(fallback):
		return colors[fallback]
	return colors.values()[0] if not colors.is_empty() else Color.WHITE


func base_variant() -> String:
	return variants[0] if not variants.is_empty() else DEFAULT_VARIANT


func add_variant(p_name: String, p_copy_from: String = "") -> void:
	if p_name.is_empty() or p_name in variants:
		return
	variants.append(p_name)
	var source: String = p_copy_from if p_copy_from != "" else active_variant
	for e in entries:
		if e.has("colors"):
			e["colors"][p_name] = color_of(e, source)
	emit_changed()


func remove_variant(p_name: String) -> void:
	if variants.size() <= 1 or not p_name in variants:
		return
	variants.remove_at(variants.find(p_name))
	for e in entries:
		if e.has("colors"):
			e["colors"].erase(p_name)
	if active_variant == p_name:
		active_variant = base_variant()
	emit_changed()


func rename_variant(p_from: String, p_to: String) -> void:
	if p_to.is_empty() or p_to in variants or not p_from in variants:
		return
	variants[variants.find(p_from)] = p_to
	for e in entries:
		if e.has("colors") and e["colors"].has(p_from):
			e["colors"][p_to] = e["colors"][p_from]
			e["colors"].erase(p_from)
	if active_variant == p_from:
		active_variant = p_to
	emit_changed()


func set_active_variant(p_name: String) -> void:
	if p_name == active_variant or not p_name in variants:
		return
	active_variant = p_name
	emit_changed()


func migrate() -> bool:
	var changed := false
	if variants.is_empty():
		variants = PackedStringArray([DEFAULT_VARIANT])
		changed = true
	if not active_variant in variants:
		active_variant = base_variant()
		changed = true
	for e in entries:
		if e.has("colors"):
			continue
		e["colors"] = {base_variant(): e.get("color", Color.WHITE)}
		e.erase("color")
		changed = true
	var seen := {}
	for e in entries:
		var display: String = str(e["name"])
		if seen.has(display):
			e["name"] = unique_name(display, str(e["id"]))
			changed = true
		seen[str(e["name"])] = true
	if changed:
		emit_changed()
	return changed


func unique_name(p_name: String, p_except_id: String = "") -> String:
	var wanted := p_name.strip_edges()
	if wanted.is_empty():
		wanted = "Color"
	if not _name_taken(wanted, p_except_id):
		return wanted
	var n := 2
	while _name_taken("%s %d" % [wanted, n], p_except_id):
		n += 1
	return "%s %d" % [wanted, n]


func _name_taken(p_name: String, p_except_id: String) -> bool:
	for e in entries:
		if str(e["id"]) != p_except_id and str(e["name"]) == p_name:
			return true
	return false


func new_id(p_also_avoid: PackedStringArray = PackedStringArray()) -> String:
	var id := generate_scene_unique_id()
	while find_index(id) >= 0 or id in p_also_avoid:
		id = generate_scene_unique_id()
	return id


func add_entry(p_id: String, p_name: String, p_color: Color, p_index: int = -1) -> void:
	var colors := {}
	for variant in variants:
		colors[variant] = p_color
	var e := {"id": p_id, "name": unique_name(p_name, p_id), "colors": colors}
	if p_index < 0 or p_index >= entries.size():
		entries.append(e)
	else:
		entries.insert(p_index, e)
	emit_changed()


func remove_entry(p_id: String) -> void:
	var i := find_index(p_id)
	if i >= 0:
		entries.remove_at(i)
		emit_changed()


func rename_entry(p_id: String, p_name: String) -> void:
	var i := find_index(p_id)
	if i >= 0:
		entries[i]["name"] = unique_name(p_name, p_id)
		emit_changed()


func move_entry(p_id: String, p_to_index: int) -> void:
	var i := find_index(p_id)
	if i < 0:
		return
	var e: Dictionary = entries[i]
	entries.remove_at(i)
	entries.insert(clampi(p_to_index, 0, entries.size()), e)
	emit_changed()


func set_color(p_id: String, p_color: Color, p_variant: String = "") -> void:
	var i := find_index(p_id)
	if i < 0:
		return
	var variant: String = p_variant if p_variant != "" else active_variant
	if not entries[i].has("colors"):
		entries[i]["colors"] = {base_variant(): entries[i].get("color", Color.WHITE)}
		entries[i].erase("color")
	entries[i]["colors"][variant] = p_color
	emit_changed()


static func const_identifier(p_name: String) -> String:
	var out := ""
	for c in p_name.to_upper():
		out += c if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.lstrip("_").rstrip("_")
	if out.is_empty():
		return ""
	if out[0] >= "0" and out[0] <= "9":
		out = "C_" + out
	return out


func build_const_body(p_owner: String, p_indent: String = "") -> String:
	var consts := PackedStringArray()
	var pairs := PackedStringArray()
	var used := {}
	var base := base_variant()
	var named := []
	var claimed := {}
	var duplicates := PackedStringArray()
	for e in entries:
		var ident := const_identifier(str(e["name"]))
		if ident.is_empty():
			ident = "C_" + str(e["id"]).to_upper()
		var stem := ident
		var n := 2
		while used.has(ident):
			ident = "%s_%d" % [stem, n]
			n += 1
		used[ident] = true
		consts.append("const %s := %s" % [ident, var_to_str(color_of(e, base))])
		var display := str(e["name"])
		if claimed.has(display):
			if not display in duplicates:
				duplicates.append(display)
			continue
		claimed[display] = true
		named.append({"entry": e, "ident": ident})
		pairs.append("\t%s: %s," % [var_to_str(display), ident])
	if not duplicates.is_empty():
		push_warning("LivePalette: %s named more than once; name lookups resolve to the first, the rest are reachable as constants only." % ", ".join(duplicates))

	var variant_rows := PackedStringArray()
	for variant in variants:
		var cells := PackedStringArray()
		for item in named:
			cells.append("\t\t%s: %s," % [
					var_to_str(str(item["entry"]["name"])), var_to_str(color_of(item["entry"], variant))])
		variant_rows.append("\t%s: {\n%s\n\t}," % [var_to_str(variant), "\n".join(cells)])

	var body := PackedStringArray()
	body.append("## The constants are the \"%s\" variant; switching variants at runtime goes" % base)
	body.append("## through the LivePaletteRuntime autoload, which re-applies bound properties.")
	body.append_array(consts)
	body.append("")
	body.append("## Palette name -> color, for lookups by a name held in a variable.")
	body.append("## Prefer the constants above: they are checked at compile time.")
	body.append("const BY_NAME := {")
	body.append_array(pairs)
	body.append("}")
	body.append("")
	body.append("## Variant name -> {name -> color}, for reading a variant you are not on.")
	body.append("const VARIANTS := {")
	body.append_array(variant_rows)
	body.append("}")
	body.append("")
	body.append("")
	body.append("static func color(p_name: StringName) -> Color:")
	body.append("\tvar key := str(p_name)")
	body.append("\tif BY_NAME.has(key):")
	body.append("\t\treturn BY_NAME[key]")
	body.append("\tpush_warning(\"%s: no color named '%%s'\" %% p_name)" % p_owner)
	body.append("\treturn Color.WHITE")
	body.append("")
	body.append("")
	body.append("static func has_color(p_name: StringName) -> bool:")
	body.append("\treturn BY_NAME.has(str(p_name))")
	body.append("")
	body.append("")
	body.append("## A color from a specific variant, falling back to the base variant.")
	body.append("static func color_in(p_variant: StringName, p_name: StringName) -> Color:")
	body.append("\tvar table: Dictionary = VARIANTS.get(str(p_variant), {})")
	body.append("\tif table.has(str(p_name)):")
	body.append("\t\treturn table[str(p_name)]")
	body.append("\treturn color(p_name)")
	body.append("")
	body.append("")
	body.append("static func variant_names() -> PackedStringArray:")
	body.append("\treturn PackedStringArray(VARIANTS.keys())")

	if p_indent.is_empty():
		return "\n".join(body)
	var indented := PackedStringArray()
	for line in "\n".join(body).split("\n"):
		indented.append(p_indent + line if not line.is_empty() else "")
	return "\n".join(indented)


static func parse_gpl(p_text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rgba := false
	for raw in p_text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var lower := line.to_lower()
		if lower.begins_with("gimp palette") or lower.begins_with("name:") or lower.begins_with("columns:"):
			continue
		if lower.begins_with("channels:"):
			rgba = lower.contains("rgba")
			continue
		var tokens := line.replace("\t", " ").split(" ", false)
		var want := 4 if rgba else 3
		if tokens.size() < want:
			continue
		var numeric := true
		for i in want:
			if not tokens[i].is_valid_int():
				numeric = false
				break
		if not numeric:
			continue
		var a := clampi(tokens[3].to_int(), 0, 255) if rgba else 255
		var c := Color8(clampi(tokens[0].to_int(), 0, 255), clampi(tokens[1].to_int(), 0, 255), clampi(tokens[2].to_int(), 0, 255), a)
		out.append({"name": " ".join(tokens.slice(want)), "color": c})
	return out


func to_gpl(p_palette_name: String) -> String:
	var lines := PackedStringArray(["GIMP Palette",
			"Name: %s (%s)" % [p_palette_name, active_variant], "Columns: 8", "#"])
	for e in entries:
		var c: Color = color_of(e)
		lines.append("%d %d %d\t%s" % [c.r8, c.g8, c.b8, e["name"]])
	return "\n".join(lines) + "\n"


static func scan_bound_files(p_dir: String, p_extensions: Array, p_out: PackedStringArray) -> void:
	var d := DirAccess.open(p_dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while not f.is_empty():
		var path := p_dir.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				scan_bound_files(path, p_extensions, p_out)
		elif f.get_extension() in p_extensions and FileAccess.get_file_as_string(path).contains(String(META)):
			p_out.append(path)
		f = d.get_next()


static func owner_file(p_res: Resource) -> String:
	var path := p_res.resource_path
	var sep := path.find("::")
	if sep >= 0:
		path = path.substr(0, sep)
	return path if path.begins_with("res://") else ""


static func find_uses_in_text(p_text: String, p_id: String) -> int:
	var needle := "\"%s\"" % p_id
	var n := 0
	var from := p_text.find(String(META))
	while from >= 0:
		var close := p_text.find("}", from)
		if close < 0:
			close = p_text.length()
		n += p_text.substr(from, close - from).count(needle)
		from = p_text.find(String(META), close + 1)
	return n


static func hex(p_color: Color) -> String:
	return "#" + p_color.to_html(p_color.a < 1.0).to_upper()


func apply_to_tree(p_root: Node, p_dirty_files: Dictionary = {}) -> int:
	return _apply_recursive(p_root, {}, p_dirty_files)


func _apply_recursive(p_node: Node, p_visited: Dictionary, p_dirty_files: Dictionary) -> int:
	var n := apply_to_object(p_node, p_visited, p_dirty_files)
	for c in p_node.get_children():
		n += _apply_recursive(c, p_visited, p_dirty_files)
	return n


func apply_to_object(p_obj: Object, p_visited: Dictionary, p_dirty_files: Dictionary = {}) -> int:
	var iid := p_obj.get_instance_id()
	if p_visited.has(iid):
		return 0
	p_visited[iid] = true
	var n := 0
	if p_obj.has_meta(META):
		var bindings: Dictionary = p_obj.get_meta(META)
		for prop in bindings:
			var i := find_index(str(bindings[prop]))
			if i < 0:
				continue
			var c: Color = color_of(entries[i])
			var cur: Variant = p_obj.get(prop)
			if cur is Color and not cur.is_equal_approx(c):
				p_obj.set(prop, c)
				n += 1
	if n > 0 and p_obj is Resource:
		var file := owner_file(p_obj)
		if not file.is_empty():
			p_dirty_files[file] = true
	for p in p_obj.get_property_list():
		if p["type"] == TYPE_OBJECT and (p["usage"] & PROPERTY_USAGE_STORAGE) and p["name"] != "script":
			var v: Variant = p_obj.get(p["name"])
			if v is Resource:
				n += apply_to_object(v, p_visited, p_dirty_files)
	return n
