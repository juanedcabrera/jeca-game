extends Node2D
# Reusable "walk back to farm" exit element for activity scenes.

var pressed_callback: Callable
var _hovered: bool = false

func _ready() -> void:
	set_process_input(true)

func _draw() -> void:
	var ground = Color(0.52, 0.40, 0.24)
	var path   = Color(0.65, 0.52, 0.32)
	var wood   = Color(0.45, 0.28, 0.10)
	var sign_c = Color(0.62, 0.42, 0.18)
	var text_c = Color(0.18, 0.10, 0.02)

	# Hover highlight
	if _hovered:
		draw_rect(Rect2(-4, -50, 232, 140), Color(1.0, 0.92, 0.55, 0.18))

	# Dirt path strip
	draw_rect(Rect2(0, 20, 220, 75), ground)
	# Path lane dashes
	for i in range(5):
		draw_rect(Rect2(18 + i * 38, 45, 22, 8), path)

	# Wooden arch posts
	draw_rect(Rect2(162, -8, 14, 100), wood)
	draw_rect(Rect2(196, -8, 14, 100), wood)
	# Arch crossbar
	draw_rect(Rect2(159, -14, 54, 12), wood)
	# Sign plank on arch
	draw_rect(Rect2(162, -42, 52, 26), sign_c)
	draw_string(ThemeDB.fallback_font, Vector2(167, -22),
		"FARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_c)
	# Arrow + label on ground
	draw_string(ThemeDB.fallback_font, Vector2(6, 16),
		"← Back to Farm", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.85, 0.7))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local = to_local(event.position)
		var new_hovered = Rect2(-4, -50, 232, 140).has_point(local)
		if new_hovered != _hovered:
			_hovered = new_hovered
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local = to_local(event.position)
		if Rect2(-4, -50, 232, 140).has_point(local):
			if pressed_callback != null:
				pressed_callback.call()
