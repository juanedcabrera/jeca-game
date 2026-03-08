extends Node2D

var _email_input:    LineEdit
var _password_input: LineEdit
var _status_label:   Label
var _sign_in_btn:    Button
var _sign_up_btn:    Button
var _loading:        bool = false
var _time:           float = 0.0
var _title_label:    Label

# Animated elements
var _cloud_positions: Array = []
var _cloud_speeds: Array = []
var _fireflies: Array = []  # [{pos, speed, phase, alpha}]
var _birds: Array = []      # [{pos, speed, wing_phase}]

func _ready() -> void:
	# If already logged in (e.g., session restored), skip to start screen
	if Supabase.is_logged_in:
		GameManager.change_scene("start_screen")
		return

	# Listen for OAuth completion (Google sign-in redirects back here)
	Supabase.auth_changed.connect(_on_auth_changed)

	# Seed RNG for varied decorations
	randomize()
	_init_fireflies()
	_init_clouds()
	_init_birds()
	_build_scene()

	# On desktop, auto-focus email input; on web, let the user tap
	# (mobile browsers require user gesture to open virtual keyboard)
	if not OS.has_feature("web"):
		await get_tree().process_frame
		if _email_input:
			_email_input.grab_focus()

func _on_auth_changed(logged_in: bool) -> void:
	if logged_in:
		GameManager.change_scene("start_screen")

func _init_fireflies() -> void:
	for i in range(18):
		_fireflies.append({
			"pos": Vector2(randf_range(20, 940), randf_range(280, 530)),
			"speed": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
			"phase": randf_range(0, TAU),
			"base_alpha": randf_range(0.3, 0.7),
		})

func _init_clouds() -> void:
	for i in range(5):
		_cloud_positions.append(Vector2(randf_range(-100, 960), randf_range(25, 120)))
		_cloud_speeds.append(randf_range(10, 25))

func _init_birds() -> void:
	for i in range(3):
		_birds.append({
			"pos": Vector2(randf_range(-60, 960), randf_range(40, 150)),
			"speed": randf_range(30, 55),
			"wing_phase": randf_range(0, TAU),
		})

func _build_scene() -> void:
	# Sky gradient (drawn procedurally)
	var sky_drawer = _SkyDrawer.new()
	add_child(sky_drawer)

	# Hills (layered with depth)
	var hills = _HillsDrawer.new()
	add_child(hills)

	# Farm detail decorations (fence, barn silhouette, flowers)
	var farm_details = _FarmDetailsDrawer.new()
	add_child(farm_details)

	# Grass tufts at the bottom
	var grass = _GrassTuftsDrawer.new()
	add_child(grass)

	# Tree sprites on sides
	_add_tree_decorations()

	# Chicken sprite
	_add_chicken()

	# Cloud and bird drawer (above sky/hills, below UI)
	var _sky_anim_drawer = _SkyAnimDrawer.new()
	_sky_anim_drawer.login_screen = self
	_sky_anim_drawer.z_index = 1
	add_child(_sky_anim_drawer)

	# Sun with glow
	var sun_node = Node2D.new()
	sun_node.position = Vector2(820, 80)
	var sun_drawer = _SunDrawer.new()
	sun_node.add_child(sun_drawer)
	add_child(sun_node)

	# Title banner ribbon
	var banner = _BannerDrawer.new()
	banner.position = Vector2(480, 46)
	add_child(banner)

	# Title
	_title_label = Label.new()
	_title_label.text = "CABRERA HARVEST"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.45, 0.2, 0.0))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.position = Vector2(180, 38)
	_title_label.size = Vector2(600, 60)
	_title_label.z_index = 5
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	# Title outline (second label behind, slightly offset for outline effect)
	for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var outline = Label.new()
		outline.text = "CABRERA HARVEST"
		outline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outline.add_theme_font_size_override("font_size", 42)
		outline.add_theme_color_override("font_color", Color(0.35, 0.15, 0.0))
		outline.position = Vector2(180 + offset.x * 2, 38 + offset.y * 2)
		outline.size = Vector2(600, 60)
		outline.z_index = 4
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(outline)

	# Card (wooden plank style)
	var card_drawer = _WoodCardDrawer.new()
	card_drawer.position = Vector2(280, 118)
	card_drawer.z_index = 3
	add_child(card_drawer)

	# Subtitle
	var sub = Label.new()
	sub.text = "Sign in to play"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.position = Vector2(280, 138)
	sub.size = Vector2(400, 28)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.z_index = 5
	add_child(sub)

	# Email
	var email_lbl = GameManager.make_label("Email:", Vector2(310, 182), 15, Color(0.9, 0.85, 0.65))
	email_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	email_lbl.z_index = 5
	add_child(email_lbl)
	_email_input = _make_input("family@email.com", Vector2(310, 202), false)
	_email_input.z_index = 5
	add_child(_email_input)

	# Password
	var pw_lbl = GameManager.make_label("Password:", Vector2(310, 256), 15, Color(0.9, 0.85, 0.65))
	pw_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pw_lbl.z_index = 5
	add_child(pw_lbl)
	_password_input = _make_input("", Vector2(310, 276), true)
	_password_input.z_index = 5
	add_child(_password_input)

	# Status label (errors / success messages)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_status_label.position = Vector2(280, 330)
	_status_label.size = Vector2(400, 22)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.z_index = 5
	add_child(_status_label)

	# Sign In button
	_sign_in_btn = _make_wood_button("Sign In", Vector2(310, 356), Vector2(170, 48), Color(0.22, 0.52, 0.18))
	_sign_in_btn.add_theme_font_size_override("font_size", 20)
	_sign_in_btn.pressed.connect(_on_sign_in)
	_sign_in_btn.z_index = 5
	add_child(_sign_in_btn)

	# Create Account button
	_sign_up_btn = _make_wood_button("Create Account", Vector2(500, 356), Vector2(170, 48), Color(0.25, 0.38, 0.58))
	_sign_up_btn.add_theme_font_size_override("font_size", 17)
	_sign_up_btn.pressed.connect(_on_sign_up)
	_sign_up_btn.z_index = 5
	add_child(_sign_up_btn)

	# Divider ("or")
	var divider_left = ColorRect.new()
	divider_left.color = Color(0.55, 0.45, 0.3, 0.5)
	divider_left.size = Vector2(140, 1)
	divider_left.position = Vector2(310, 418)
	divider_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider_left.z_index = 5
	add_child(divider_left)

	var or_label = Label.new()
	or_label.text = "or"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_font_size_override("font_size", 14)
	or_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	or_label.position = Vector2(455, 408)
	or_label.size = Vector2(50, 20)
	or_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	or_label.z_index = 5
	add_child(or_label)

	var divider_right = ColorRect.new()
	divider_right.color = Color(0.55, 0.45, 0.3, 0.5)
	divider_right.size = Vector2(140, 1)
	divider_right.position = Vector2(510, 418)
	divider_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider_right.z_index = 5
	add_child(divider_right)

	# Google Sign In button
	var google_btn = _make_wood_button("Sign in with Google", Vector2(340, 430), Vector2(280, 44), Color(0.55, 0.22, 0.18))
	google_btn.add_theme_font_size_override("font_size", 17)
	google_btn.pressed.connect(_on_google_sign_in)
	google_btn.z_index = 5
	add_child(google_btn)

func _make_input(placeholder: String, pos: Vector2, secret: bool) -> LineEdit:
	var input = LineEdit.new()
	input.placeholder_text = placeholder
	input.position = pos
	input.size = Vector2(340, 44)
	input.add_theme_font_size_override("font_size", 20)
	input.secret = secret
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.focus_mode = Control.FOCUS_ALL
	input.virtual_keyboard_enabled = true

	# Normal style - warm parchment with border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.92, 0.82)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.55, 0.4, 0.2)
	# Inner shadow effect - darker at top
	style.shadow_color = Color(0.3, 0.2, 0.1, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	input.add_theme_stylebox_override("normal", style)

	# Focus style - slightly brighter border
	var focus_style = style.duplicate()
	focus_style.border_color = Color(0.75, 0.55, 0.2)
	focus_style.border_width_top = 3
	focus_style.border_width_bottom = 3
	focus_style.border_width_left = 3
	focus_style.border_width_right = 3
	input.add_theme_stylebox_override("focus", focus_style)

	# Text color
	input.add_theme_color_override("font_color", Color(0.2, 0.15, 0.08))
	input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.45, 0.35))

	return input

func _make_wood_button(text: String, pos: Vector2, sz: Vector2, base_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_ALL

	# Normal style - wood grain feel
	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_top = 2
	normal.border_width_bottom = 3
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_color = Color(base_color.r * 0.6, base_color.g * 0.6, base_color.b * 0.6)
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(1, 2)
	# Add horizontal "grain" lines via expand margin trick
	normal.content_margin_top = 4
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	# Hover style - lighter and raised
	var hover = normal.duplicate()
	hover.bg_color = Color(
		min(base_color.r + 0.12, 1.0),
		min(base_color.g + 0.12, 1.0),
		min(base_color.b + 0.08, 1.0)
	)
	hover.border_color = Color(0.75, 0.6, 0.2)
	hover.shadow_size = 4
	hover.shadow_offset = Vector2(1, 3)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed style - darker and pushed in
	var pressed = normal.duplicate()
	pressed.bg_color = Color(
		base_color.r * 0.8,
		base_color.g * 0.8,
		base_color.b * 0.8
	)
	pressed.shadow_size = 0
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed)

	# Text
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))

	return btn

func _add_tree_decorations() -> void:
	var tree_variants = [
		"res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
		"res://Pixelwood Valley 1.1.2/Trees/2.png",
		"res://Pixelwood Valley 1.1.2/Trees/3.png",
		"res://Pixelwood Valley 1.1.2/Trees/4.png",
		"res://Pixelwood Valley 1.1.2/Trees/5.png",
		"res://Pixelwood Valley 1.1.2/Trees/6.png",
	]
	# Left side trees
	var left_positions = [Vector2(55, 455), Vector2(120, 470), Vector2(30, 500)]
	for p in left_positions:
		var spr = Sprite2D.new()
		spr.texture = load(tree_variants[randi() % tree_variants.size()])
		spr.scale = Vector2(0.75, 0.75)
		spr.position = p + Vector2(0, -35)
		spr.z_index = 2
		add_child(spr)

	# Right side trees
	var right_positions = [Vector2(850, 460), Vector2(920, 475), Vector2(940, 505)]
	for p in right_positions:
		var spr = Sprite2D.new()
		spr.texture = load(tree_variants[randi() % tree_variants.size()])
		spr.scale = Vector2(0.75, 0.75)
		spr.position = p + Vector2(0, -35)
		spr.z_index = 2
		add_child(spr)

func _add_chicken() -> void:
	var chicken = Sprite2D.new()
	chicken.texture = load("res://Cute_Fantasy_Free/Animals/Chicken/Chicken.png")
	chicken.hframes = 2
	chicken.vframes = 2
	chicken.frame = 0
	chicken.scale = Vector2(1.5, 1.5)
	chicken.position = Vector2(185, 490)
	chicken.z_index = 3
	add_child(chicken)

func _process(delta: float) -> void:
	_time += delta

	# Animate title bob
	if _title_label:
		_title_label.position.y = 38 + sin(_time * 1.5) * 3.0

	# Move clouds
	for i in range(_cloud_positions.size()):
		_cloud_positions[i].x += _cloud_speeds[i] * delta
		if _cloud_positions[i].x > 1040:
			_cloud_positions[i].x = -120
			_cloud_positions[i].y = randf_range(25, 120)

	# Move fireflies
	for f in _fireflies:
		f["pos"] += f["speed"] * delta
		# Gentle drift change
		f["speed"].x += randf_range(-5, 5) * delta
		f["speed"].y += randf_range(-3, 3) * delta
		f["speed"].x = clampf(f["speed"].x, -15, 15)
		f["speed"].y = clampf(f["speed"].y, -10, 10)
		# Wrap around
		if f["pos"].x < -10: f["pos"].x = 970
		if f["pos"].x > 970: f["pos"].x = -10
		if f["pos"].y < 260: f["pos"].y = 530
		if f["pos"].y > 535: f["pos"].y = 280

	# Move birds
	for b in _birds:
		b["pos"].x += b["speed"] * delta
		b["wing_phase"] += delta * 6.0
		if b["pos"].x > 1020:
			b["pos"].x = -60
			b["pos"].y = randf_range(40, 150)
			b["speed"] = randf_range(30, 55)

	queue_redraw()
	# Also redraw the sky animation drawer
	for child in get_children():
		if child is _SkyAnimDrawer:
			child.queue_redraw()

func _set_loading(on: bool) -> void:
	_loading = on
	_sign_in_btn.disabled = on
	_sign_up_btn.disabled = on
	if on:
		_status_label.text = "Please wait..."
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		# Add disabled style for buttons
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.35, 0.35, 0.35)
		disabled_style.corner_radius_top_left = 8
		disabled_style.corner_radius_top_right = 8
		disabled_style.corner_radius_bottom_left = 8
		disabled_style.corner_radius_bottom_right = 8
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

func _on_google_sign_in() -> void:
	if _loading:
		return
	if not OS.has_feature("web"):
		_status_label.text = "Google sign-in only works in the web version."
		return
	Supabase.sign_in_with_google()


# == Inner drawers =============================================================

class _SkyDrawer extends Node2D:
	func _draw() -> void:
		# Gradient sky: warm dawn/dusk tones
		var steps = 20
		var step_h = 540.0 / steps
		for i in range(steps):
			var t = float(i) / steps
			# Top: warm peach-pink, bottom: soft blue with golden horizon
			var top_color = Color(0.85, 0.55, 0.4)   # warm peach at top
			var mid_color = Color(0.95, 0.75, 0.45)   # golden horizon
			var bot_color = Color(0.5, 0.72, 0.88)    # soft blue low sky
			var color: Color
			if t < 0.4:
				var mt = t / 0.4
				color = top_color.lerp(mid_color, mt)
			else:
				var mt = (t - 0.4) / 0.6
				color = mid_color.lerp(bot_color, mt)
			draw_rect(Rect2(0, i * step_h, 960, step_h + 1), color)


class _SunDrawer extends Node2D:
	func _draw() -> void:
		# Outer glow halos
		draw_circle(Vector2.ZERO, 80, Color(1.0, 0.9, 0.5, 0.06))
		draw_circle(Vector2.ZERO, 65, Color(1.0, 0.85, 0.4, 0.1))
		draw_circle(Vector2.ZERO, 52, Color(1.0, 0.8, 0.3, 0.15))
		# Main sun body - warm gradient effect
		draw_circle(Vector2.ZERO, 42, Color(1.0, 0.88, 0.35))
		draw_circle(Vector2.ZERO, 36, Color(1.0, 0.92, 0.5))
		draw_circle(Vector2.ZERO, 28, Color(1.0, 0.96, 0.7))
		# Rays
		var gold = Color(1.0, 0.88, 0.25, 0.8)
		for i in range(12):
			var angle = i * PI / 6.0
			var inner_r = 48.0
			var outer_r = 70.0
			if i % 2 == 0:
				outer_r = 62.0
			draw_line(
				Vector2(cos(angle), sin(angle)) * inner_r,
				Vector2(cos(angle), sin(angle)) * outer_r,
				gold, 3.5, true
			)


class _HillsDrawer extends Node2D:
	func _draw() -> void:
		# Far hills (lighter, more blue-green) - misty distance
		var pts0 = PackedVector2Array()
		pts0.append(Vector2(-10, 540))
		pts0.append(Vector2(-10, 350))
		for x in range(0, 971, 15):
			var y = 350 - sin(x * 0.005 + 0.5) * 45 - cos(x * 0.011) * 25
			pts0.append(Vector2(x, y))
		pts0.append(Vector2(970, 540))
		draw_colored_polygon(pts0, Color(0.42, 0.6, 0.38, 0.6))

		# Mid hills (main green)
		var pts1 = PackedVector2Array()
		pts1.append(Vector2(-10, 540))
		pts1.append(Vector2(-10, 390))
		for x in range(0, 971, 15):
			pts1.append(Vector2(x, 390 - sin(x * 0.008) * 60 - cos(x * 0.013) * 30))
		pts1.append(Vector2(970, 540))
		draw_colored_polygon(pts1, Color(0.36, 0.56, 0.29))

		# Flower patches on mid hill
		_draw_flower_patches()

		# Front hills (darker)
		var pts2 = PackedVector2Array()
		pts2.append(Vector2(-10, 540))
		pts2.append(Vector2(-10, 440))
		for x in range(0, 971, 15):
			pts2.append(Vector2(x, 450 - sin(x * 0.012 + 1.0) * 40 - cos(x * 0.007) * 25))
		pts2.append(Vector2(970, 540))
		draw_colored_polygon(pts2, Color(0.29, 0.47, 0.22))

		# Ground strip
		draw_rect(Rect2(0, 500, 960, 40), Color(0.26, 0.42, 0.19))

	func _draw_flower_patches() -> void:
		# Scatter flower dots on the hillside
		var flower_colors = [
			Color(1.0, 0.4, 0.4, 0.8),   # red
			Color(1.0, 0.85, 0.2, 0.8),   # yellow
			Color(0.9, 0.5, 0.8, 0.8),    # pink
			Color(1.0, 1.0, 0.9, 0.7),    # white
		]
		# Use deterministic positions based on x for consistency
		var seed_positions = [
			Vector2(80, 400), Vector2(95, 395), Vector2(110, 398),
			Vector2(150, 385), Vector2(165, 382), Vector2(175, 388),
			Vector2(750, 392), Vector2(765, 388), Vector2(780, 394),
			Vector2(820, 395), Vector2(840, 390), Vector2(855, 397),
			Vector2(200, 420), Vector2(215, 416), Vector2(700, 425),
			Vector2(50, 410), Vector2(60, 405), Vector2(900, 400),
		]
		var ci = 0
		for p in seed_positions:
			var col = flower_colors[ci % flower_colors.size()]
			draw_circle(p, 2.5, col)
			draw_circle(p + Vector2(3, -2), 2.0, col)
			ci += 1


class _FarmDetailsDrawer extends Node2D:
	func _draw() -> void:
		# Fence posts along the lower hill
		var fence_color = Color(0.55, 0.38, 0.18)
		var fence_dark = Color(0.4, 0.28, 0.12)

		# Left fence section
		for i in range(5):
			var x = 20.0 + i * 28.0
			var y = 468.0 + sin(i * 0.5) * 3.0
			# Post
			draw_rect(Rect2(x, y - 22, 5, 22), fence_color)
			draw_rect(Rect2(x + 1, y - 22, 1, 22), fence_dark)
			# Post cap
			draw_rect(Rect2(x - 1, y - 24, 7, 4), fence_color)

		# Horizontal rails for left fence
		draw_line(Vector2(20, 452), Vector2(148, 455), fence_color, 2.5)
		draw_line(Vector2(20, 460), Vector2(148, 463), fence_color, 2.5)

		# Right fence section
		for i in range(4):
			var x = 830.0 + i * 30.0
			var y = 470.0 + sin(i * 0.7) * 3.0
			draw_rect(Rect2(x, y - 22, 5, 22), fence_color)
			draw_rect(Rect2(x + 1, y - 22, 1, 22), fence_dark)
			draw_rect(Rect2(x - 1, y - 24, 7, 4), fence_color)

		draw_line(Vector2(830, 454), Vector2(942, 457), fence_color, 2.5)
		draw_line(Vector2(830, 462), Vector2(942, 465), fence_color, 2.5)

		# Barn silhouette (far left background)
		_draw_barn_silhouette(Vector2(680, 348))

		# Small windmill silhouette (far right)
		_draw_windmill_silhouette(Vector2(240, 340))

	func _draw_barn_silhouette(pos: Vector2) -> void:
		var col = Color(0.3, 0.46, 0.24, 0.7)
		# Barn body
		draw_rect(Rect2(pos.x, pos.y, 40, 30), col)
		# Barn roof (triangle)
		var roof = PackedVector2Array([
			Vector2(pos.x - 4, pos.y),
			Vector2(pos.x + 20, pos.y - 18),
			Vector2(pos.x + 44, pos.y),
		])
		draw_colored_polygon(roof, col)
		# Silo next to barn
		draw_rect(Rect2(pos.x + 42, pos.y + 5, 10, 25), col)
		draw_circle(Vector2(pos.x + 47, pos.y + 5), 5, col)

	func _draw_windmill_silhouette(pos: Vector2) -> void:
		var col = Color(0.34, 0.5, 0.28, 0.6)
		# Tower
		var tower = PackedVector2Array([
			Vector2(pos.x - 6, pos.y + 35),
			Vector2(pos.x - 3, pos.y),
			Vector2(pos.x + 3, pos.y),
			Vector2(pos.x + 6, pos.y + 35),
		])
		draw_colored_polygon(tower, col)
		# Blades (simplified X shape)
		draw_line(pos, pos + Vector2(-14, -10), col, 2.0)
		draw_line(pos, pos + Vector2(14, -10), col, 2.0)
		draw_line(pos, pos + Vector2(-8, 14), col, 2.0)
		draw_line(pos, pos + Vector2(8, 14), col, 2.0)


class _GrassTuftsDrawer extends Node2D:
	func _draw() -> void:
		# Grass tufts along the very bottom
		var grass_colors = [
			Color(0.32, 0.55, 0.22),
			Color(0.28, 0.48, 0.18),
			Color(0.35, 0.58, 0.25),
		]
		# Deterministic grass positions
		var positions = []
		for i in range(40):
			positions.append(Vector2(i * 24.0 + 5, 522 + sin(i * 1.3) * 6))
		for p in positions:
			var ci = int(p.x) % grass_colors.size()
			var col = grass_colors[ci]
			# Each tuft is 3-4 blades
			var base_y = p.y
			draw_line(Vector2(p.x, base_y), Vector2(p.x - 3, base_y - 12), col, 1.5)
			draw_line(Vector2(p.x + 2, base_y), Vector2(p.x + 5, base_y - 14), col, 1.5)
			draw_line(Vector2(p.x + 1, base_y), Vector2(p.x, base_y - 16), col, 1.8)


class _BannerDrawer extends Node2D:
	## Draws a ribbon/banner behind the title text, centered at this node's position
	func _draw() -> void:
		var w = 340.0
		var h = 44.0
		var fold = 22.0  # ribbon fold width

		# Ribbon shadow
		var shadow_col = Color(0, 0, 0, 0.2)
		draw_rect(Rect2(-w/2 + 3, -h/2 + 3, w, h), shadow_col)

		# Main ribbon body
		var ribbon_col = Color(0.55, 0.2, 0.08)
		draw_rect(Rect2(-w/2, -h/2, w, h), ribbon_col)

		# Lighter center strip
		draw_rect(Rect2(-w/2 + 4, -h/2 + 3, w - 8, h - 6), Color(0.65, 0.28, 0.1))

		# Top and bottom edge highlights
		draw_line(Vector2(-w/2, -h/2), Vector2(w/2, -h/2), Color(0.75, 0.4, 0.15), 1.5)
		draw_line(Vector2(-w/2, h/2), Vector2(w/2, h/2), Color(0.4, 0.15, 0.05), 1.5)

		# Left fold
		var left_fold = PackedVector2Array([
			Vector2(-w/2, -h/2),
			Vector2(-w/2 - fold, -h/2 - 6),
			Vector2(-w/2 - fold + 6, 0),
			Vector2(-w/2 - fold, h/2 + 6),
			Vector2(-w/2, h/2),
		])
		draw_colored_polygon(left_fold, Color(0.5, 0.18, 0.06))

		# Right fold
		var right_fold = PackedVector2Array([
			Vector2(w/2, -h/2),
			Vector2(w/2 + fold, -h/2 - 6),
			Vector2(w/2 + fold - 6, 0),
			Vector2(w/2 + fold, h/2 + 6),
			Vector2(w/2, h/2),
		])
		draw_colored_polygon(right_fold, Color(0.5, 0.18, 0.06))


class _WoodCardDrawer extends Node2D:
	## Draws a wooden plank card at the node's position. Size: 400x380
	func _draw() -> void:
		var w = 400.0
		var h = 380.0

		# Outer shadow
		draw_rect(Rect2(4, 4, w, h), Color(0, 0, 0, 0.3))

		# Main wood background
		var wood_base = Color(0.35, 0.22, 0.1, 0.95)
		draw_rect(Rect2(0, 0, w, h), wood_base)

		# Wood plank lines (horizontal grain)
		var grain_col = Color(0.3, 0.18, 0.08, 0.4)
		var grain_light = Color(0.42, 0.28, 0.14, 0.25)
		for i in range(18):
			var y = i * 19.0 + 8
			if y > h - 5:
				break
			draw_line(Vector2(6, y), Vector2(w - 6, y), grain_col, 1.0)
			# Subtle light line above
			draw_line(Vector2(6, y - 1), Vector2(w - 6, y - 1), grain_light, 0.5)

		# Vertical plank dividers
		var divider_col = Color(0.25, 0.15, 0.06, 0.5)
		draw_line(Vector2(w * 0.33, 4), Vector2(w * 0.33, h - 4), divider_col, 1.5)
		draw_line(Vector2(w * 0.66, 4), Vector2(w * 0.66, h - 4), divider_col, 1.5)

		# Border frame
		var border_col = Color(0.55, 0.38, 0.15)
		draw_rect(Rect2(0, 0, w, h), border_col, false, 3.0)

		# Inner border (lighter)
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.48, 0.33, 0.14, 0.5), false, 1.5)

		# Corner nails/rivets
		_draw_nail(Vector2(12, 12))
		_draw_nail(Vector2(w - 12, 12))
		_draw_nail(Vector2(12, h - 12))
		_draw_nail(Vector2(w - 12, h - 12))

		# Inner shadow at top and left
		var shadow_top = Color(0, 0, 0, 0.15)
		draw_rect(Rect2(5, 5, w - 10, 6), shadow_top)
		draw_rect(Rect2(5, 5, 6, h - 10), shadow_top)

	func _draw_nail(pos: Vector2) -> void:
		# Nail head
		draw_circle(pos, 5.0, Color(0.45, 0.4, 0.35))
		draw_circle(pos, 4.0, Color(0.55, 0.5, 0.45))
		# Highlight
		draw_circle(pos + Vector2(-1, -1), 1.5, Color(0.7, 0.65, 0.6, 0.7))
		# Dark center
		draw_circle(pos, 1.2, Color(0.35, 0.3, 0.25))


class _SkyAnimDrawer extends Node2D:
	## Draws clouds, birds, and fireflies — separate node so z_index works above sky/hills
	var login_screen: Node2D

	func _draw() -> void:
		if not login_screen:
			return

		var t = login_screen._time

		# Draw clouds
		for pos in login_screen._cloud_positions:
			var c = Color(1, 1, 1, 0.7)
			draw_circle(pos, 24, c)
			draw_circle(pos + Vector2(26, 6), 18, c)
			draw_circle(pos + Vector2(-22, 6), 16, c)
			draw_circle(pos + Vector2(8, -8), 20, c)
			draw_rect(Rect2(pos + Vector2(-34, 6), Vector2(90, 22)), c)

		# Draw birds
		for b in login_screen._birds:
			var pos = b["pos"]
			var wing_y = sin(b["wing_phase"]) * 4.0
			var col = Color(0.2, 0.15, 0.1, 0.75)
			draw_circle(pos, 2.5, col)
			draw_line(pos, pos + Vector2(-6, -2 + wing_y), col, 1.5, true)
			draw_line(pos + Vector2(-6, -2 + wing_y), pos + Vector2(-10, wing_y), col, 1.2, true)
			draw_line(pos, pos + Vector2(6, -2 + wing_y), col, 1.5, true)
			draw_line(pos + Vector2(6, -2 + wing_y), pos + Vector2(10, wing_y), col, 1.2, true)

		# Draw fireflies
		for f in login_screen._fireflies:
			var alpha = f["base_alpha"] * (0.5 + 0.5 * sin(t * 2.5 + f["phase"]))
			if alpha > 0.1:
				draw_circle(f["pos"], 4.0, Color(1.0, 0.95, 0.5, alpha * 0.3))
				draw_circle(f["pos"], 1.5, Color(1.0, 1.0, 0.7, alpha))
