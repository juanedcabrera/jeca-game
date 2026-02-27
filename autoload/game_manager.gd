extends Node

const SCENES: Dictionary = {
	"start_screen": "res://scenes/start_screen.tscn",
	"login_screen": "res://scenes/login_screen.tscn",
	"character_creation": "res://scenes/character_creation.tscn",
	"farm": "res://scenes/farm.tscn",
	"house_interior": "res://scenes/house_interior.tscn",
	"math_mines": "res://scenes/math_mines.tscn",
	"literacy_library": "res://scenes/literacy_library.tscn",
	"juarez_market": "res://scenes/juarez_market.tscn",
}

var current_scene: String = "start_screen"
var previous_scene: String = ""

# Where the player spawns when returning to farm
var farm_spawn: Dictionary = {
	"from_house": Vector2(180, 300),
	"from_mines": Vector2(480, 100),
	"from_library": Vector2(860, 270),
	"from_market": Vector2(480, 460),
	"default": Vector2(180, 300),
}
var farm_spawn_key: String = "default"

func change_scene(scene_name: String) -> void:
	if not scene_name in SCENES:
		push_error("GameManager: Unknown scene: " + scene_name)
		return
	previous_scene = current_scene
	current_scene = scene_name
	get_tree().change_scene_to_file(SCENES[scene_name])

func go_to_farm(spawn_key: String = "default") -> void:
	farm_spawn_key = spawn_key
	change_scene("farm")

func get_farm_spawn() -> Vector2:
	return farm_spawn.get(farm_spawn_key, farm_spawn["default"])

func show_message(parent: Node, text: String, duration: float = 2.0) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(480 - 240, 450)
	label.size = Vector2(480, 52)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.position = label.position - Vector2(8, 6)
	bg.size = label.size + Vector2(16, 12)

	parent.add_child(bg)
	parent.add_child(label)

	var tween = parent.create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func():
		label.queue_free()
		bg.queue_free()
	)

func make_button(text: String, pos: Vector2, size: Vector2, color: Color = Color(0.2, 0.6, 0.2)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_size_override("font_size", 22)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

func make_label(text: String, pos: Vector2, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func make_panel(pos: Vector2, size: Vector2, color: Color = Color(0.15, 0.1, 0.05, 0.92)) -> ColorRect:
	var panel = ColorRect.new()
	panel.position = pos
	panel.size = size
	panel.color = color
	return panel

# ── Pause overlay ─────────────────────────────────────────────────────────────
# Call show_pause_menu(self) from any scene to show a save-and-exit overlay.
# Returns the overlay node; caller may hold reference if needed.
func show_pause_menu(scene_root: Node) -> Control:
	# Guard: don't open a second overlay if one already exists
	if scene_root.has_node("_PauseOverlay"):
		return scene_root.get_node("_PauseOverlay")

	# Root container — process_mode ALWAYS so it works while tree is paused
	var overlay = Control.new()
	overlay.name = "_PauseOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	scene_root.add_child(overlay)

	# Dim background
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(960, 540)
	overlay.add_child(dim)

	# Border (drawn before panel so panel sits on top)
	var border = ColorRect.new()
	border.color = Color(0.65, 0.48, 0.18)
	border.size = Vector2(364, 244)
	border.position = Vector2(298, 148)
	overlay.add_child(border)

	# Panel
	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.06, 0.02, 0.95)
	panel.size = Vector2(360, 240)
	panel.position = Vector2(300, 150)
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.position = Vector2(300, 168)
	title.size = Vector2(360, 50)
	overlay.add_child(title)

	# Resume button
	var resume_btn = make_button("Resume", Vector2(360, 238), Vector2(240, 52), Color(0.18, 0.48, 0.18))
	resume_btn.add_theme_font_size_override("font_size", 22)
	overlay.add_child(resume_btn)

	# Save & Exit button
	var exit_btn = make_button("Save & Exit", Vector2(360, 306), Vector2(240, 52), Color(0.5, 0.2, 0.1))
	exit_btn.add_theme_font_size_override("font_size", 22)
	overlay.add_child(exit_btn)

	resume_btn.pressed.connect(func():
		get_tree().paused = false
		overlay.queue_free()
	)

	exit_btn.pressed.connect(func():
		get_tree().paused = false
		PlayerData.save_game()
		change_scene("start_screen")
	)

	get_tree().paused = true
	return overlay
