extends Node2D

var _selected_gender: String = "boy"
var _name_input: LineEdit
var _preview_node: Node2D
var _boy_btn: Button
var _girl_btn: Button

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.56, 0.76, 0.46)
	bg.size = Vector2(960, 540)
	add_child(bg)

	# Sky strip
	var sky = ColorRect.new()
	sky.color = Color(0.6, 0.82, 1.0)
	sky.size = Vector2(960, 160)
	add_child(sky)

	# Title
	var title = Label.new()
	title.text = "Create Your Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.15, 0.05, 0.0))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.9, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(160, 18)
	title.size = Vector2(640, 60)
	add_child(title)

	# Main panel
	var panel = ColorRect.new()
	panel.color = Color(0.93, 0.85, 0.68)
	panel.size = Vector2(600, 380)
	panel.position = Vector2(180, 90)
	add_child(panel)

	# Panel border
	var border = ColorRect.new()
	border.color = Color(0.55, 0.35, 0.15)
	border.size = Vector2(606, 386)
	border.position = Vector2(177, 87)
	add_child(border)
	add_child(panel)  # Re-add on top of border

	# Character preview area
	_preview_node = CharacterPreview.new()
	_preview_node.position = Vector2(480, 310)
	_preview_node.gender = _selected_gender
	add_child(_preview_node)

	# Gender label
	var gender_lbl = GameManager.make_label("Who are you?", Vector2(220, 110), 22, Color(0.3, 0.1, 0.0))
	add_child(gender_lbl)

	# Boy button
	_boy_btn = GameManager.make_button("Boy", Vector2(220, 148), Vector2(130, 52), Color(0.2, 0.45, 0.75))
	_boy_btn.pressed.connect(func(): _select_gender("boy"))
	add_child(_boy_btn)

	# Girl button
	_girl_btn = GameManager.make_button("Girl", Vector2(370, 148), Vector2(130, 52), Color(0.75, 0.3, 0.55))
	_girl_btn.pressed.connect(func(): _select_gender("girl"))
	add_child(_girl_btn)

	# Name label
	var name_lbl = GameManager.make_label("Your Name:", Vector2(220, 222), 22, Color(0.3, 0.1, 0.0))
	add_child(name_lbl)

	# Name input
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter your name..."
	_name_input.position = Vector2(220, 255)
	_name_input.size = Vector2(310, 48)
	_name_input.add_theme_font_size_override("font_size", 22)
	_name_input.max_length = 14

	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(1.0, 0.98, 0.92)
	input_style.border_width_top = 2
	input_style.border_width_bottom = 2
	input_style.border_width_left = 2
	input_style.border_width_right = 2
	input_style.border_color = Color(0.55, 0.35, 0.15)
	input_style.corner_radius_top_left = 8
	input_style.corner_radius_top_right = 8
	input_style.corner_radius_bottom_left = 8
	input_style.corner_radius_bottom_right = 8
	_name_input.add_theme_stylebox_override("normal", input_style)
	add_child(_name_input)

	# Start button
	var start_btn = GameManager.make_button("Begin Your Adventure!", Vector2(210, 330), Vector2(360, 60), Color(0.15, 0.5, 0.15))
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_on_start_pressed)
	add_child(start_btn)

	# Decorative cows/plants on right side
	var deco = _SideDeco.new()
	deco.position = Vector2.ZERO
	add_child(deco)

	# Hint text
	var hint = GameManager.make_label("You will farm, learn, and grow!", Vector2(220, 410), 17, Color(0.4, 0.2, 0.05))
	add_child(hint)

	_update_gender_buttons()

func _select_gender(gender: String) -> void:
	_selected_gender = gender
	if _preview_node:
		_preview_node.gender = gender
		_preview_node._load_sprite()
	_update_gender_buttons()

func _update_gender_buttons() -> void:
	var boy_style = StyleBoxFlat.new()
	boy_style.corner_radius_top_left = 10
	boy_style.corner_radius_top_right = 10
	boy_style.corner_radius_bottom_left = 10
	boy_style.corner_radius_bottom_right = 10
	var girl_style = boy_style.duplicate()

	if _selected_gender == "boy":
		boy_style.bg_color = Color(0.15, 0.35, 0.7)
		girl_style.bg_color = Color(0.6, 0.25, 0.45)
	else:
		boy_style.bg_color = Color(0.25, 0.5, 0.8)
		girl_style.bg_color = Color(0.85, 0.35, 0.65)

	_boy_btn.add_theme_stylebox_override("normal", boy_style)
	_girl_btn.add_theme_stylebox_override("normal", girl_style)

func _on_start_pressed() -> void:
	var name_val = _name_input.text.strip_edges()
	if name_val.length() == 0:
		name_val = "Friend"
	PlayerData.player_name = name_val
	PlayerData.player_gender = _selected_gender
	PlayerData.game_started = true
	PlayerData._init_farm_tiles()
	PlayerData.save_game()  # Write initial save to the chosen slot
	GameManager.change_scene("house_interior")


# ── Character preview ─────────────────────────────────────────────────────────

# Pixelwood Valley character sprites for preview
# Boy = NPC 3, Girl = NPC 4
const PW_CHAR = {
	"boy": "res://Pixelwood Valley 1.1.2/NPCs/3.png",
	"girl": "res://Pixelwood Valley 1.1.2/NPCs/4.png",
	# Trees for decoration
	"tree": "res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
}

class CharacterPreview extends Node2D:
	var gender: String = "boy"
	var _bob: float = 0.0
	var _sprite: Sprite2D

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.scale = Vector2(3.0, 3.0)
		_sprite.position = Vector2(0, -20)
		_load_sprite()
		add_child(_sprite)

	func _load_sprite() -> void:
		var path = PW_CHAR["boy"] if gender == "boy" else PW_CHAR["girl"]
		_sprite.texture = load(path)
		# NPC PNGs: 236×343, hframes=4 vframes=7 → each frame 59×49
		_sprite.hframes = 4
		_sprite.vframes = 7

	func _process(delta: float) -> void:
		_bob += delta * 2.0
		position.y = 310 + sin(_bob) * 5.0
		# Animate through NPC frames
		if _sprite:
			_sprite.frame = int(_bob) % 4

	func _draw() -> void:
		pass


class _SideDeco extends Node2D:
	func _ready() -> void:
		# Trees using Pixelwood Valley sprites
		for pos in [Vector2(89, 310), Vector2(869, 310)]:
			var spr = Sprite2D.new()
			spr.texture = load(PW_CHAR["tree"])
			spr.scale = Vector2(1.5, 1.5)
			spr.position = pos
			add_child(spr)

	func _draw() -> void:
		# Flowers
		for i in range(6):
			var x = 90 + i * 130
			draw_circle(Vector2(x, 502), 7, Color(1.0, 0.85, 0.2))
			draw_circle(Vector2(x, 502), 3, Color(0.6, 0.35, 0.1))
			draw_line(Vector2(x, 502), Vector2(x, 525), Color(0.3, 0.6, 0.2), 2)
