# Live Palette

A named color palette for Godot 4. Pick palette colors anywhere in the Inspector, and
when you change one later, everything that used it follows. Open scenes update as you
edit, scenes you open afterwards correct themselves, resources saved as their own files
are rewritten on disk, and the running game fixes itself at startup.

![The Palette dock, tabbed next to the Inspector](https://raw.githubusercontent.com/auxterlibre/live-palette/main/addons/live_palette/screenshot_01.png)

![A StyleBox bg_color linked to a palette entry, with the swatch grid open](https://raw.githubusercontent.com/auxterlibre/live-palette/main/addons/live_palette/screenshot_02.png)

## Features

- A Palette dock for adding, renaming, recoloring, deleting and drag-reordering named
  colors. All of it is undoable.
- Every `Color` property in the Inspector gets a Palette row, on nodes and on resources
  alike (theme overrides, StyleBoxes, Theme items, shader `source_color` uniforms).
  Pick from the swatch grid to set the color and link the property to that entry. The
  built-in color picker stays where it was.
- Each link stores a stable id rather than a name, so renaming an entry doesn't break it.
- A small autoload re-applies the palette when the game starts, so a scene saved with
  old colors still runs with the right ones. It reaches every node and the resources
  their properties point at; a resource your code loads on its own goes through
  `LivePaletteRuntime.apply(res)`.
- The addon writes a constants file to `res://live_palette/palette_const.gd` and keeps
  it current:

  ```gdscript
  $Sprite2D.modulate = LivePalette.SKY_BLUE      # autocompleted, checked at compile time
  var c := LivePalette.color("Sky Blue")         # lookup when the name is in a variable
  if LivePalette.has_color("Sky Blue"): ...
  ```

- Several palettes at once: keep a `palette` for the game world and a `ui` beside it,
  each with its own colors and variants. They all apply together; the dock's picker
  only chooses which one you are editing. Everything is reached through one class:

  ```gdscript
  LivePalette.SAND            # the default palette, res://live_palette/palette.tres
  LivePalette.UI.ACCENT       # ui.tres
  LivePalette.UI.color("Accent")
  ```
- Variants: one set of named colors, several palettes of values. Add a Dark variant
  beside your Default, switch with the dropdown at the top of the dock, and the editor
  retints as you look at it. At runtime one call does the same to a live game:

  ```gdscript
  LivePaletteRuntime.set_variant("Dark")     # every bound property follows
  var ink := LivePalette.color_in("Dark", "Ink")
  ```

  Links are stored by id, so adding variants changes nothing in your saved scenes.
- Names stay unique inside a palette. Import a `.gpl` holding a name you already use
  and it arrives as "Panel 2" rather than a second "Panel", so `LivePalette.PANEL`
  always means one particular colour.
- You can import and export GIMP `.gpl` files, so a palette from Lospec, Aseprite or
  Krita lands in the dock in one step. The import is a single undoable action.
- Each row has a search button that lists every saved scene or resource using that
  color. Double-click a result to open it.

## Install

1. Copy `addons/live_palette/` into your project, or install it from the Asset Library.
2. Enable Live Palette in Project Settings > Plugins.

Enabling it registers the `LivePaletteRuntime` autoload and creates
`res://live_palette/` for the palette resource and the generated constants. Needs Godot
4.4 or newer.

## Quick start

1. Open the Palette dock (it tabs next to the Inspector) and add a few colors.
2. Select a node, find any Color property, and link a color through its Palette row.
3. Change that color in the dock. Everything linked follows, in the editor and in game.
4. In code, use `LivePalette.MY_COLOR`, or `LivePalette.color("My Color")` by name.

## How it works

Picking a palette color writes `{property: entry_id}` into the object's
`_live_palette_bindings` metadata. That metadata is hidden in the Inspector and saved
with the scene or resource. In the editor, the plugin re-applies bindings to open scenes
whenever the palette changes, and to other scenes as you open them. A `.tres` saved on
its own is applied and rewritten on disk shortly after a palette change, so it holds the
current colors before the game or another scene loads it. At runtime the
`LivePaletteRuntime` autoload does one pass over the tree at startup, then watches
`node_added`; both cover nodes and the resources reachable from their properties. Ids
never change, so renames are free.

## Notes and limitations

- The `LivePalette.*` constants are a snapshot, rewritten on every palette save. If you
  change the palette while the game runs, read live values with
  `LivePaletteRuntime.color()` instead. The constants come from the first variant, so
  they stay put when you switch the active one; `LivePalette.color_in()` reads the rest.
- The autoload applies bindings to nodes and to the resources their properties point
  at. A bound resource that only your code loads (`load()`, `preload()`) is not on that
  path: call `LivePaletteRuntime.apply(res)` after loading it, and again if the palette
  or variant changes while the game runs. The editor rewrites such files after a palette
  change, so a fresh load already holds the current colors.
- The editor's rewrite covers `.tres` files outside `res://addons/` that carry palette
  bindings, and only those whose bound colors differ. Open scenes are handled as you
  edit them, and closed scenes correct themselves when opened.
- `.gpl` export writes the variant you are looking at, and import fills it.
- Colors inside `Array` or `Dictionary` properties of resources are not walked. Direct
  resource properties are.
- Find Uses reads saved text files (`.tscn`, `.tres`, `.escn`, `.theme`). It can't see
  binary `.scn`/`.res` files, or changes you haven't saved yet.
- `.gpl` is an RGB format, so export flattens alpha. The importer also reads Krita's
  RGBA variant.
- The palette lives at `res://live_palette/palette.tres` and is picked up by the default
  "export all resources" setting.
- The names `LivePalette`, `LivePaletteRuntime` and `LivePaletteData` need to stay free
  in your project, because Godot refuses an autoload that shares its name with a global
  class. The plugin checks for this and tells you which script clashes, rather than
  failing with Godot's own error dialog.

## License

MIT, see [LICENSE](LICENSE). Copyright Thiago Rocha.
