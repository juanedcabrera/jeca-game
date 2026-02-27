extends Node2D

var _email_input:    LineEdit
var _password_input: LineEdit
var _status_label:   Label
var _sign_in_btn:    Button
var _sign_up_btn:    Button
var _loading:        bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	# Sky
	var sky = ColorRect.new()
	sky.color = Color(0.39, 0.69, 1.0)
	sky.size = Vector2(960, 540)
	add_child(sky)

	# Hills
	var hills = _HillsDrawer.new()
	add_child(hills)

	# Sun
	var sun_node = Node2D.new()
	sun_node.position = Vector2(820, 80)
	var sun_drawer = _SunDrawer.new()
	sun_node.add_child(sun_drawer)
	add_child(sun_node)

	# Title
	var title = Label.new()
	title.text = "CABRERA HARVEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0.5, 0.25, 0.0))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(160, 36)
	title.size = Vector2(640, 70)
	add_child(title)

	# Card border
	var border = ColorRect.new()
	border.color = Color(0.65, 0.48, 0.18)
	border.size = Vector2(404, 334)
	border.position = Vector2(278, 126)
	add_child(border)

	# Card background
	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.06, 0.02, 0.94)
	panel.size = Vector2(400, 330)
	panel.position = Vector2(280, 128)
	add_child(panel)

	# Subtitle
	var sub = Label.new()
	sub.text = "Sign in to play"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.9, 0.85, 0.65))
	sub.position = Vector2(280, 144)
	sub.size = Vector2(400, 28)
	add_child(sub)

	# Email
	var email_lbl = GameManager.make_label("Email:", Vector2(310, 188), 15, Color(0.85, 0.8, 0.6))
	add_child(email_lbl)
	_email_input = _make_input("family@email.com", Vector2(310, 208), false)
	add_child(_email_input)

	# Password
	var pw_lbl = GameManager.make_label("Password:", Vector2(310, 262), 15, Color(0.85, 0.8, 0.6))
	add_child(pw_lbl)
	_password_input = _make_input("••••••••", Vector2(310, 282), true)
	add_child(_password_input)

	# Status label (errors / success messages)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_status_label.position = Vector2(280, 336)
	_status_label.size = Vector2(400, 22)
	add_child(_status_label)

	# Sign In button
	_sign_in_btn = GameManager.make_button("Sign In", Vector2(310, 362), Vector2(170, 48), Color(0.15, 0.5, 0.15))
	_sign_in_btn.add_theme_font_size_override("font_size", 20)
	_sign_in_btn.pressed.connect(_on_sign_in)
	add_child(_sign_in_btn)

	# Create Account button
	_sign_up_btn = GameManager.make_button("Create Account", Vector2(500, 362), Vector2(170, 48), Color(0.2, 0.35, 0.6))
	_sign_up_btn.add_theme_font_size_override("font_size", 17)
	_sign_up_btn.pressed.connect(_on_sign_up)
	add_child(_sign_up_btn)

	# Hint
	var hint = Label.new()
	hint.text = "One family account — up to 3 kids can play"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.5))
	hint.position = Vector2(280, 424)
	hint.size = Vector2(400, 22)
	add_child(hint)

func _make_input(placeholder: String, pos: Vector2, secret: bool) -> LineEdit:
	var input = LineEdit.new()
	input.placeholder_text = placeholder
	input.position = pos
	input.size = Vector2(340, 44)
	input.add_theme_font_size_override("font_size", 20)
	input.secret = secret
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.92, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	input.add_theme_stylebox_override("normal", style)
	return input

func _set_loading(on: bool) -> void:
	_loading = on
	_sign_in_btn.disabled = on
	_sign_up_btn.disabled = on
	if on:
		_status_label.text = "Please wait…"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		# Add disabled style for buttons
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.35, 0.35, 0.35)
		disabled_style.corner_radius_top_left = 10
		disabled_style.corner_radius_top_right = 10
		disabled_style.corner_radius_bottom_left = 10
		disabled_style.corner_radius_bottom_right = 10
		_sign_in_btn.add_theme_stylebox_override("disabled", disabled_style)
		_sign_up_btn.add_theme_stylebox_override("disabled", disabled_style)
	else:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

func _on_sign_in() -> void:
	if _loading:
		return
	var email    = _email_input.text.strip_edges()
	var password = _password_input.text
	if email.is_empty() or password.is_empty():
		_status_label.text = "Please enter your email and password."
		return
	_set_loading(true)
	var result = await Supabase.sign_in(email, password)
	_set_loading(false)
	if result.has("error"):
		_status_label.text = result["error"]
	else:
		GameManager.change_scene("start_screen")

func _on_sign_up() -> void:
	if _loading:
		return
	var email    = _email_input.text.strip_edges()
	var password = _password_input.text
	if email.is_empty() or password.is_empty():
		_status_label.text = "Please enter an email and password."
		return
	if password.length() < 6:
		_status_label.text = "Password must be at least 6 characters."
		return
	_set_loading(true)
	var result = await Supabase.sign_up(email, password)
	_set_loading(false)
	if result.has("error"):
		_status_label.text = result["error"]
	elif Supabase.is_logged_in:
		GameManager.change_scene("start_screen")
	else:
		# Supabase may require email confirmation (disable in dashboard for games)
		_status_label.text = "Check your email to confirm, then sign in!"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))


# ── Inner drawers ─────────────────────────────────────────────────────────────

class _SunDrawer extends Node2D:
	func _draw() -> void:
		var gold = Color(1.0, 0.85, 0.1)
		draw_circle(Vector2.ZERO, 42, gold)
		for i in range(8):
			var angle = i * PI / 4.0
			draw_line(
				Vector2(cos(angle), sin(angle)) * 50,
				Vector2(cos(angle), sin(angle)) * 68,
				gold, 5, true
			)

class _HillsDrawer extends Node2D:
	func _draw() -> void:
		var pts1 = PackedVector2Array()
		pts1.append(Vector2(-10, 540))
		pts1.append(Vector2(-10, 390))
		for x in range(0, 971, 20):
			pts1.append(Vector2(x, 390 - sin(x * 0.008) * 60 - cos(x * 0.013) * 30))
		pts1.append(Vector2(970, 540))
		draw_colored_polygon(pts1, Color(0.36, 0.56, 0.29))

		var pts2 = PackedVector2Array()
		pts2.append(Vector2(-10, 540))
		pts2.append(Vector2(-10, 440))
		for x in range(0, 971, 20):
			pts2.append(Vector2(x, 450 - sin(x * 0.012 + 1.0) * 40 - cos(x * 0.007) * 25))
		pts2.append(Vector2(970, 540))
		draw_colored_polygon(pts2, Color(0.29, 0.47, 0.22))
