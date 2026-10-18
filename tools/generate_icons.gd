extends SceneTree
## One-time original mobile icon generator. Run with Godot 4.5.1:
## godot --headless --path . --script res://tools/generate_icons.gd

func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://assets")
	var err := DirAccess.make_dir_recursive_absolute(dir)
	assert(err == OK, "Unable to create asset directory")
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	assert(svg.length() > 100, "Missing base SVG icon")
	_render(svg, 1.5, "res://assets/icon_192.png")
	var transparent := svg.replace('<rect width="128" height="128" rx="30" fill="#bcebe1"/>', "")
	assert(transparent != svg, "Unable to remove SVG background")
	_render(transparent, 3.375, "res://assets/adaptive_foreground_432.png")
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(Color("#bcebe1"))
	assert(background.save_png("res://assets/adaptive_background_432.png") == OK)
	print("PASS: original Android icons generated")
	quit(0)

func _render(svg: String, scale: float, dest: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	assert(err == OK, "Unable to render " + dest)
	assert(img.save_png(dest) == OK, "Unable to save " + dest)
