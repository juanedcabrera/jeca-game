extends Node2D

var _cloud_positions: Array = []
var _cloud_speeds: Array = []
var _cloud_shapes: Array = []  # Pre-generated cloud shapes
var _title_bob: float = 0.0
var _title_label: Label
var _time: float = 0.0

# Slot cards are rebuilt whenever we return to the start screen
var _slot_cards: Array = []  # Array of Control nodes (for rebuild)
var _sync_label: Label       # "Syncing..." indicator

# Pre-generated random positions for decorations (avoids flickering from randf in _draw)
var _grass_positions: Array = []
var _flower_positions: Array = []
var _flower_colors: Array = []
var _firefly_positions: Array = []
var _firefly_phases: Array = []
var _star_positions: Array = []
var _star_phases: Array = []

func _ready() -> void:
	# If not logged in, check if OAuth callback is in progress
	if not Supabase.is_logged_in:
		var has_hash = OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.hash")).length() > 1
		if has_hash or Supabase.oauth_pending:
			# Show loading screen so user doesn't see gray
			_show_oauth_loading()
			# Wait for auth or timeout
			var timer = get_tree().create_timer(12.0)
			await _await_first(Supabase.auth_changed, timer.timeout)
			# Clean up loading screen
			_clear_oauth_loading()
			if not Supabase.is_logged_in:
				GameManager.change_scene("login_screen")
				return
		else:
			GameManager.change_scene("login_screen")
			return

	# Pre-generate random decoration positions
	_generate_decoration_data()

	_build_scene()
	# Async: sync cloud saves, then show cards
	_sync_label.visible = true
	await Supabase.fetch_and_sync_slots()
	_sync_label.visible = false
	_build_slot_cards()

var _oauth_loading_nodes: Array = []

func _show_oauth_loading() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.03)
	bg.position = Vector2.ZERO
	bg.size = Vector2(960, 540)
	add_child(bg)
	_oauth_loading_nodes.append(bg)

	# "Signing in..." message
	var lbl = Label.new()
	lbl.text = "Signing in..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = Vector2(0, 220)
	lbl.size = Vector2(960, 100)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_oauth_loading_nodes.append(lbl)

func _clear_oauth_loading() -> void:
	for node in _oauth_loading_nodes:
		node.queue_free()
	_oauth_loading_nodes.clear()

## Await whichever signal fires first; returns when either completes.
func _await_first(sig1: Signal, sig2: Signal) -> void:
	var done = false
	var cb1 = func(_a = null): done = true
	var cb2 = func(): done = true
	sig1.connect(cb1, CONNECT_ONE_SHOT)
	sig2.connect(cb2, CONNECT_ONE_SHOT)
	while not done:
		await get_tree().process_frame
	# Clean up remaining connections (one already fired as ONE_SHOT)
	if sig1.is_connected(cb1):
		sig1.disconnect(cb1)
	# SceneTreeTimer may already be freed; guard with is_instance_valid
	if sig2.get_object() != null and is_instance_valid(sig2.get_object()):
		if sig2.is_connected(cb2):
			sig2.disconnect(cb2)

func _generate_decoration_data() -> void:
	# Grass tufts
	for i in range(40):
		_grass_positions.append(Vector2(randf() * 960, 380 + randf() * 160))

	# Flower patches
	for i in range(18):
		_flower_positions.append(Vector2(randf() * 960, 400 + randf() * 120))
		var flower_col_options = [
			Color(1.0, 0.4, 0.4),   # Red
			Color(1.0, 0.85, 0.2),  # Yellow
			Color(0.9, 0.5, 0.9),   # Purple
			Color(1.0, 0.6, 0.2),   # Orange
			Color(0.6, 0.7, 1.0),   # Blue
		]
		_flower_colors.append(flower_col_options[randi() % flower_col_options.size()])

	# Fireflies
	for i in range(12):
		_firefly_positions.append(Vector2(randf() * 960, 300 + randf() * 200))
		_firefly_phases.append(randf() * TAU)

	# Stars (faint in golden hour sky)
	for i in range(8):
		_star_positions.append(Vector2(50 + randf() * 600, 10 + randf() * 80))
		_star_phases.append(randf() * TAU)

	# Cloud shapes - pre-generate offsets for fluffier clouds
	for i in range(5):
		var cx = randf_range(-60, 900)
		var cy = randf_range(30, 130)
		_cloud_positions.append(Vector2(cx, cy))
		_cloud_speeds.append(randf_range(10, 28))
		# Each cloud gets a set of bubble offsets for fluffiness
		var bubbles = []
		var num_bubbles = randi_range(5, 8)
		for b in range(num_bubbles):
			bubbles.append({
				"offset": Vector2(randf_range(-45, 50), randf_range(-18, 12)),
				"radius": randf_range(14, 30),
			})
		_cloud_shapes.append(bubbles)

func _build_scene() -> void:
	# Gradient sky (golden hour) - drawn by _SkyDrawer
	var sky_drawer = _SkyDrawer.new()
	add_child(sky_drawer)

	# Sun with warm glow
	var sun = _make_sun()
	add_child(sun)

	# Green hills (enhanced with layers)
	var hills = _HillsDrawer.new()
	hills.position = Vector2.ZERO
	add_child(hills)

	# Farm decorations (sprites: trees, animals, fence, mill)
	_add_decorations()

	# Title: wooden sign style
	var title_sign = _TitleSignDrawer.new()
	title_sign.position = Vector2(480, 75)
	title_sign.z_index = 5
	add_child(title_sign)

	# Title
	_title_label = Label.new()
	_title_label.text = "CABRERA HARVEST"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.35, 0.18, 0.0))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.position = Vector2(170, 52)
	_title_label.size = Vector2(620, 72)
	_title_label.z_index = 6
	add_child(_title_label)

	# Subtitle
	var sub = Label.new()
	sub.text = "Choose Your Player"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	sub.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.6))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.position = Vector2(280, 130)
	sub.size = Vector2(400, 28)
	sub.z_index = 6
	add_child(sub)

	# "Syncing..." label (visible while cloud fetch is in progress)
	_sync_label = Label.new()
	_sync_label.text = "Syncing saves..."
	_sync_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sync_label.add_theme_font_size_override("font_size", 18)
	_sync_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_sync_label.position = Vector2(330, 310)
	_sync_label.size = Vector2(300, 30)
	_sync_label.visible = false  # shown in _ready() before sync
	_sync_label.z_index = 6
	add_child(_sync_label)

	# Footer bar
	var footer_drawer = _FooterDrawer.new()
	footer_drawer.z_index = 8
	add_child(footer_drawer)

	# Signed-in email
	var email_lbl = Label.new()
	email_lbl.text = Supabase.get_user_email()
	email_lbl.add_theme_font_size_override("font_size", 13)
	email_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 0.7))
	email_lbl.position = Vector2(20, 514)
	email_lbl.size = Vector2(700, 22)
	email_lbl.z_index = 9
	add_child(email_lbl)

	var sign_out_btn = GameManager.make_button("Sign Out", Vector2(820, 506), Vector2(120, 30), Color(0.35, 0.15, 0.1))
	sign_out_btn.add_theme_font_size_override("font_size", 14)
	sign_out_btn.pressed.connect(_on_sign_out)
	sign_out_btn.z_index = 9
	add_child(sign_out_btn)

	# Credits
	var credit = Label.new()
	credit.text = "Made with love by the Cabrera Family"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 13)
	credit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.75))
	credit.position = Vector2(260, 494)
	credit.size = Vector2(440, 22)
	credit.z_index = 9
	add_child(credit)

func _build_slot_cards() -> void:
	# Remove old cards if any (for rebuild)
	for c in _slot_cards:
		c.queue_free()
	_slot_cards.clear()

	# Card layout: 3 cards side by side
	# Screen: 960x540; cards at y=160, each 270x230 with 20px gap
	var card_w = 270.0
	var card_h = 230.0
	var total_w = card_w * 3 + 20 * 2  # 850
	var start_x = (960 - total_w) / 2.0

	for slot in range(3):
		var cx = start_x + slot * (card_w + 20)
		var cy = 160.0
		var preview = PlayerData.read_slot_preview(slot)
		var card = _make_slot_card(slot, cx, cy, card_w, card_h, preview)
		card.z_index = 7
		add_child(card)
		_slot_cards.append(card)

func _make_slot_card(slot: int, x: float, y: float, w: float, h: float, preview: Dictionary) -> Control:
	var container = Control.new()
	container.position = Vector2(x, y)
	container.size = Vector2(w, h)

	var has_save = preview.get("exists", false)

	# Wood-plank card drawer (background + border + corner accents)
	var card_drawer = _CardDrawer.new()
	card_drawer.card_size = Vector2(w, h)
	card_drawer.has_save = has_save
	card_drawer.slot_index = slot
	container.add_child(card_drawer)

	# Slot number badge
	var badge = Label.new()
	badge.text = "Player %d" % (slot + 1)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.position = Vector2(10, 10)
	badge.size = Vector2(w - 20, 24)
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	badge.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.7))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	container.add_child(badge)

	if has_save:
		# Character avatar with circular background
		var gender = preview.get("player_gender", "boy")
		var avatar = _MiniAvatar.new()
		avatar.gender = gender
		avatar.position = Vector2(w / 2.0, 85)
		container.add_child(avatar)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = preview.get("player_name", "Friend")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, 125)
		name_lbl.size = Vector2(w, 28)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.5))
		name_lbl.add_theme_constant_override("shadow_offset_x", 1)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		container.add_child(name_lbl)

		# Day + coins
		var info_lbl = Label.new()
		info_lbl.text = "Day %d  •  %d coins" % [preview.get("day", 1), preview.get("coins", 10)]
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.position = Vector2(0, 152)
		info_lbl.size = Vector2(w, 22)
		info_lbl.add_theme_font_size_override("font_size", 14)
		info_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.65))
		container.add_child(info_lbl)

		# Play button
		var play_btn = GameManager.make_button("Play", Vector2(20, 182), Vector2(w - 80, 38), Color(0.15, 0.5, 0.15))
		play_btn.add_theme_font_size_override("font_size", 18)
		play_btn.pressed.connect(func(): _on_slot_play(slot))
		container.add_child(play_btn)

		# Delete button (small, red)
		var del_btn = GameManager.make_button("X", Vector2(w - 54, 182), Vector2(34, 38), Color(0.55, 0.12, 0.12))
		del_btn.add_theme_font_size_override("font_size", 16)
		del_btn.pressed.connect(func(): _on_slot_delete(slot))
		container.add_child(del_btn)
	else:
		# Empty slot — "+" label and New Game button
		# The _CardDrawer handles the sparkle/glow for empty slots
		var plus_lbl = Label.new()
		plus_lbl.text = "+"
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.position = Vector2(0, 60)
		plus_lbl.size = Vector2(w, 60)
		plus_lbl.add_theme_font_size_override("font_size", 52)
		plus_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.4, 0.9))
		container.add_child(plus_lbl)

		var hint_lbl = Label.new()
		hint_lbl.text = "Start a new adventure!"
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.position = Vector2(0, 120)
		hint_lbl.size = Vector2(w, 24)
		hint_lbl.add_theme_font_size_override("font_size", 13)
		hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 0.7))
		container.add_child(hint_lbl)

		var new_btn = GameManager.make_button("New Game", Vector2(35, 170), Vector2(w - 70, 44), Color(0.18, 0.48, 0.18))
		new_btn.add_theme_font_size_override("font_size", 18)
		new_btn.pressed.connect(func(): _on_slot_new(slot))
		container.add_child(new_btn)

	return container

func _make_sun() -> Node2D:
	var sun_node = Node2D.new()
	sun_node.position = Vector2(820, 85)
	var drawer = _SunDrawer.new()
	sun_node.add_child(drawer)
	return sun_node

func _add_decorations() -> void:
	var decor = _DecorDrawer.new()
	decor.position = Vector2.ZERO
	decor.z_index = 3
	add_child(decor)

func _process(delta: float) -> void:
	if _cloud_positions.is_empty():
		return  # Scene not built yet (redirecting to login)
	_time += delta

	# Bob the title
	_title_bob += delta * 1.5
	if _title_label:
		_title_label.position.y = 52 + sin(_title_bob) * 4.0

	# Move clouds
	for i in range(_cloud_positions.size()):
		_cloud_positions[i].x += _cloud_speeds[i] * delta
		if _cloud_positions[i].x > 1050:
			_cloud_positions[i].x = -130
	queue_redraw()

func _draw() -> void:
	# Draw clouds
	for i in range(_cloud_positions.size()):
		_draw_cloud(_cloud_positions[i], i)

	# Draw fireflies
	for i in range(_firefly_positions.size()):
		var p = _firefly_positions[i]
		var phase = _firefly_phases[i]
		var alpha = 0.3 + sin(_time * 1.8 + phase) * 0.3
		if alpha > 0.05:
			# Drift slightly
			var drift = Vector2(sin(_time * 0.7 + phase) * 8, cos(_time * 0.5 + phase) * 6)
			var fp = p + drift
			draw_circle(fp, 3.5, Color(1.0, 0.95, 0.4, alpha * 0.4))
			draw_circle(fp, 1.5, Color(1.0, 1.0, 0.7, alpha))

	# Draw faint stars in sky
	for i in range(_star_positions.size()):
		var sp = _star_positions[i]
		var sph = _star_phases[i]
		var sa = 0.15 + sin(_time * 1.2 + sph) * 0.1
		draw_circle(sp, 1.2, Color(1.0, 1.0, 0.9, sa))

func _draw_cloud(pos: Vector2, cloud_idx: int) -> void:
	if cloud_idx >= _cloud_shapes.size():
		return
	var bubbles = _cloud_shapes[cloud_idx]
	# Shadow
	for b in bubbles:
		draw_circle(pos + b["offset"] + Vector2(3, 5), b["radius"], Color(0.0, 0.0, 0.0, 0.06))
	# Cloud body (warm white)
	for b in bubbles:
		draw_circle(pos + b["offset"], b["radius"], Color(1.0, 0.97, 0.92, 0.7))
	# Cloud highlight (top-left bubbles brighter)
	for b in bubbles:
		if b["offset"].y < 0:
			draw_circle(pos + b["offset"] + Vector2(-2, -2), b["radius"] * 0.6, Color(1.0, 1.0, 1.0, 0.35))

# -- Slot actions --------------------------------------------------------------

func _on_slot_play(slot: int) -> void:
	if PlayerData.load_slot(slot):
		GameManager.go_to_farm("from_house")

func _on_slot_new(slot: int) -> void:
	PlayerData.reset()
	PlayerData.current_slot = slot
	GameManager.change_scene("character_creation")

func _on_slot_delete(slot: int) -> void:
	PlayerData.delete_slot(slot)
	_build_slot_cards()  # Refresh cards immediately from local state
	Supabase.delete_slot_from_db(slot)  # Fire-and-forget cloud delete

func _on_sign_out() -> void:
	Supabase.sign_out()
	GameManager.change_scene("login_screen")


# -- Inner drawers -------------------------------------------------------------

class _SkyDrawer extends Node2D:
	func _draw() -> void:
		# Golden hour gradient sky
		var top_color = Color(0.15, 0.15, 0.45)       # Deep blue-purple top
		var mid_color = Color(0.55, 0.35, 0.55)       # Warm purple middle
		var low_color = Color(0.95, 0.55, 0.25)       # Orange near horizon
		var horizon_color = Color(1.0, 0.78, 0.35)    # Golden horizon

		var steps = 30
		for i in range(steps):
			var t = float(i) / float(steps)
			var y = t * 540.0
			var h = 540.0 / float(steps) + 1.0
			var col: Color
			if t < 0.3:
				# Top to mid
				var lt = t / 0.3
				col = top_color.lerp(mid_color, lt)
			elif t < 0.6:
				# Mid to low
				var lt = (t - 0.3) / 0.3
				col = mid_color.lerp(low_color, lt)
			else:
				# Low to horizon
				var lt = (t - 0.6) / 0.4
				col = low_color.lerp(horizon_color, lt)
			draw_rect(Rect2(0, y, 960, h), col)


class _SunDrawer extends Node2D:
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		# Outer halo glow (large, soft)
		var halo_alpha = 0.08 + sin(_time * 0.8) * 0.03
		draw_circle(Vector2.ZERO, 120, Color(1.0, 0.85, 0.3, halo_alpha))
		draw_circle(Vector2.ZERO, 85, Color(1.0, 0.8, 0.2, halo_alpha + 0.05))
		draw_circle(Vector2.ZERO, 60, Color(1.0, 0.85, 0.3, 0.15))

		# Sun rays
		for i in range(12):
			var angle = i * PI / 6.0 + _time * 0.15
			var inner_r = 48.0
			var outer_r = 75.0 + sin(_time * 1.5 + i * 0.8) * 8.0
			var ray_w = 3.5 - sin(_time + i) * 0.8
			var inner_pt = Vector2(cos(angle), sin(angle)) * inner_r
			var outer_pt = Vector2(cos(angle), sin(angle)) * outer_r
			draw_line(inner_pt, outer_pt, Color(1.0, 0.88, 0.3, 0.55), ray_w, true)

		# Sun body - warm gradient effect
		draw_circle(Vector2.ZERO, 44, Color(1.0, 0.7, 0.15))
		draw_circle(Vector2.ZERO, 38, Color(1.0, 0.82, 0.2))
		draw_circle(Vector2.ZERO, 30, Color(1.0, 0.9, 0.4))
		draw_circle(Vector2(- 6, -6), 16, Color(1.0, 0.95, 0.65, 0.4))  # Highlight


class _HillsDrawer extends Node2D:
	func _draw() -> void:
		# Far hills (lighter, more distant)
		var pts0 = PackedVector2Array()
		pts0.append(Vector2(-10, 540))
		pts0.append(Vector2(-10, 350))
		for x in range(0, 971, 15):
			var y = 350 - sin(x * 0.006) * 50 - cos(x * 0.01 + 0.5) * 30 - sin(x * 0.018) * 15
			pts0.append(Vector2(x, y))
		pts0.append(Vector2(970, 540))
		draw_colored_polygon(pts0, Color(0.3, 0.45, 0.28, 0.5))

		# Mid hills (main)
		var pts1 = PackedVector2Array()
		pts1.append(Vector2(-10, 540))
		pts1.append(Vector2(-10, 390))
		for x in range(0, 971, 15):
			var y = 390 - sin(x * 0.008) * 60 - cos(x * 0.013) * 30
			pts1.append(Vector2(x, y))
		pts1.append(Vector2(970, 540))
		draw_colored_polygon(pts1, Color(0.32, 0.52, 0.26))

		# Near hills (darker, foreground)
		var pts2 = PackedVector2Array()
		pts2.append(Vector2(-10, 540))
		pts2.append(Vector2(-10, 440))
		for x in range(0, 971, 15):
			var y = 450 - sin(x * 0.012 + 1.0) * 40 - cos(x * 0.007) * 25
			pts2.append(Vector2(x, y))
		pts2.append(Vector2(970, 540))
		draw_colored_polygon(pts2, Color(0.25, 0.42, 0.18))

		# Fence line silhouette on the mid-hill
		var fence_y_base = 395.0
		for fx in range(50, 350, 28):
			var fy = fence_y_base - sin(fx * 0.008) * 60 - cos(fx * 0.013) * 30
			# Fence post
			draw_line(Vector2(fx, fy), Vector2(fx, fy - 14), Color(0.35, 0.25, 0.12, 0.6), 2.0)
			# Horizontal rail
			if fx < 330:
				var fy2 = fence_y_base - sin((fx + 28) * 0.008) * 60 - cos((fx + 28) * 0.013) * 30
				draw_line(Vector2(fx, fy - 10), Vector2(fx + 28, fy2 - 10), Color(0.35, 0.25, 0.12, 0.5), 1.5)
				draw_line(Vector2(fx, fy - 5), Vector2(fx + 28, fy2 - 5), Color(0.35, 0.25, 0.12, 0.4), 1.5)

		# Windmill silhouette on far hill
		var mill_x = 700.0
		var mill_y = 350 - sin(mill_x * 0.006) * 50 - cos(mill_x * 0.01 + 0.5) * 30 - sin(mill_x * 0.018) * 15
		var mill_col = Color(0.22, 0.32, 0.18, 0.65)
		# Tower
		draw_rect(Rect2(mill_x - 6, mill_y - 35, 12, 35), mill_col)
		# Roof
		var roof_pts = PackedVector2Array([
			Vector2(mill_x - 10, mill_y - 35),
			Vector2(mill_x, mill_y - 45),
			Vector2(mill_x + 10, mill_y - 35),
		])
		draw_colored_polygon(roof_pts, mill_col)


# Title sign - wooden plank style
class _TitleSignDrawer extends Node2D:
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		# Sign position is centered at (0, 0), sign is 620x80
		var sw = 620.0
		var sh = 80.0
		var sx = -sw / 2.0
		var sy = -sh / 2.0

		# Hanging ropes
		draw_line(Vector2(sx + 30, sy - 10), Vector2(sx + 30, sy + 5), Color(0.5, 0.35, 0.15, 0.8), 2.5)
		draw_line(Vector2(sx + sw - 30, sy - 10), Vector2(sx + sw - 30, sy + 5), Color(0.5, 0.35, 0.15, 0.8), 2.5)

		# Sign shadow
		draw_rect(Rect2(sx + 4, sy + 4, sw, sh), Color(0.0, 0.0, 0.0, 0.2))

		# Main wooden plank
		var wood_dark = Color(0.4, 0.25, 0.1)
		var wood_light = Color(0.55, 0.35, 0.15)
		draw_rect(Rect2(sx, sy, sw, sh), wood_dark)

		# Wood grain lines (horizontal)
		for i in range(8):
			var ly = sy + 8 + i * 9.5
			var grain_col = wood_light
			grain_col.a = 0.25 + fmod(i * 0.37, 0.2)
			draw_line(Vector2(sx + 5, ly), Vector2(sx + sw - 5, ly), grain_col, 1.0)

		# Plank border (lighter wood)
		draw_rect(Rect2(sx, sy, sw, sh), Color(0.6, 0.4, 0.18), false, 3.0)
		# Inner border line
		draw_rect(Rect2(sx + 4, sy + 4, sw - 8, sh - 8), Color(0.45, 0.3, 0.12, 0.5), false, 1.5)

		# Corner nails
		var nail_col = Color(0.5, 0.5, 0.5, 0.7)
		var nail_highlight = Color(0.75, 0.75, 0.75, 0.5)
		var nail_positions = [
			Vector2(sx + 12, sy + 12),
			Vector2(sx + sw - 12, sy + 12),
			Vector2(sx + 12, sy + sh - 12),
			Vector2(sx + sw - 12, sy + sh - 12),
		]
		for np in nail_positions:
			draw_circle(np, 4, nail_col)
			draw_circle(np + Vector2(-1, -1), 1.5, nail_highlight)

		# Leaf vine accents on corners
		var vine_col = Color(0.3, 0.6, 0.2, 0.6)
		# Top-left vine
		_draw_leaf(Vector2(sx + 2, sy + 2), vine_col, false)
		# Top-right vine
		_draw_leaf(Vector2(sx + sw - 2, sy + 2), vine_col, true)
		# Bottom-left vine
		_draw_leaf(Vector2(sx + 2, sy + sh - 2), vine_col, false)
		# Bottom-right vine
		_draw_leaf(Vector2(sx + sw - 2, sy + sh - 2), vine_col, true)

	func _draw_leaf(pos: Vector2, col: Color, flip: bool) -> void:
		var dir = -1.0 if flip else 1.0
		var pts = PackedVector2Array([
			pos,
			pos + Vector2(dir * 12, -6),
			pos + Vector2(dir * 18, -2),
			pos + Vector2(dir * 12, 3),
		])
		draw_colored_polygon(pts, col)
		# Second leaf
		var pts2 = PackedVector2Array([
			pos + Vector2(dir * 4, 0),
			pos + Vector2(dir * 10, 6),
			pos + Vector2(dir * 16, 5),
			pos + Vector2(dir * 10, -1),
		])
		draw_colored_polygon(pts2, Color(col.r + 0.05, col.g + 0.1, col.b, col.a * 0.8))


class _CardDrawer extends Node2D:
	var card_size: Vector2 = Vector2(270, 230)
	var has_save: bool = false
	var slot_index: int = 0
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var w = card_size.x
		var h = card_size.y

		# Card shadow
		draw_rect(Rect2(4, 4, w, h), Color(0.0, 0.0, 0.0, 0.25))

		if has_save:
			_draw_filled_card(w, h)
		else:
			_draw_empty_card(w, h)

	func _draw_filled_card(w: float, h: float) -> void:
		# Dark wood background
		var wood_base = Color(0.18, 0.1, 0.04, 0.92)
		draw_rect(Rect2(0, 0, w, h), wood_base)

		# Wood plank texture lines
		var plank_col = Color(0.25, 0.15, 0.06, 0.3)
		for i in range(12):
			var ly = 5 + i * 19.0
			draw_line(Vector2(3, ly), Vector2(w - 3, ly), plank_col, 1.0)

		# Subtle gradient overlay from top
		for i in range(6):
			var t = float(i) / 6.0
			draw_rect(Rect2(0, t * 40, w, 8), Color(0.3, 0.2, 0.08, 0.08 * (1.0 - t)))

		# Avatar area background circle
		var center_x = w / 2.0
		draw_circle(Vector2(center_x, 85), 32, Color(0.12, 0.25, 0.1, 0.5))
		draw_circle(Vector2(center_x, 85), 32, Color(0.3, 0.5, 0.2, 0.15))
		draw_arc(Vector2(center_x, 85), 33, 0, TAU, 32, Color(0.5, 0.4, 0.15, 0.4), 1.5)

		# Wooden frame border
		draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.38, 0.15), false, 3.5)
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.4, 0.28, 0.1, 0.5), false, 1.5)

		# Corner rivets
		_draw_rivet(Vector2(10, 10))
		_draw_rivet(Vector2(w - 10, 10))
		_draw_rivet(Vector2(10, h - 10))
		_draw_rivet(Vector2(w - 10, h - 10))

		# Top accent bar
		draw_rect(Rect2(8, 32, w - 16, 2), Color(0.5, 0.38, 0.15, 0.4))

	func _draw_empty_card(w: float, h: float) -> void:
		# Lighter, more inviting background
		draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.14, 0.06, 0.82))

		# Subtle wood texture
		var plank_col = Color(0.15, 0.22, 0.1, 0.2)
		for i in range(12):
			var ly = 5 + i * 19.0
			draw_line(Vector2(3, ly), Vector2(w - 3, ly), plank_col, 1.0)

		# Pulsing glow behind "+" area
		var glow_alpha = 0.06 + sin(_time * 2.0) * 0.04
		var center = Vector2(w / 2.0, 95)
		draw_circle(center, 50, Color(0.4, 0.8, 0.3, glow_alpha))
		draw_circle(center, 35, Color(0.5, 0.9, 0.4, glow_alpha + 0.03))

		# Sparkle dots rotating around center
		for i in range(6):
			var angle = _time * 0.8 + i * TAU / 6.0
			var dist = 42.0 + sin(_time * 1.5 + i) * 5.0
			var sp = center + Vector2(cos(angle), sin(angle)) * dist
			var sa = 0.3 + sin(_time * 2.5 + i * 1.2) * 0.25
			if sa > 0.05:
				draw_circle(sp, 2.0, Color(0.8, 1.0, 0.5, sa))

		# Green border with gentle pulse
		var border_alpha = 0.5 + sin(_time * 1.5) * 0.1
		draw_rect(Rect2(0, 0, w, h), Color(0.3, 0.55, 0.2, border_alpha), false, 2.5)
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.25, 0.45, 0.18, border_alpha * 0.5), false, 1.0)

		# Corner leaf accents
		_draw_corner_leaf(Vector2(6, 6), 1, 1)
		_draw_corner_leaf(Vector2(w - 6, 6), -1, 1)
		_draw_corner_leaf(Vector2(6, h - 6), 1, -1)
		_draw_corner_leaf(Vector2(w - 6, h - 6), -1, -1)

	func _draw_rivet(pos: Vector2) -> void:
		draw_circle(pos, 4.5, Color(0.4, 0.35, 0.25, 0.7))
		draw_circle(pos, 3.0, Color(0.5, 0.45, 0.3, 0.6))
		draw_circle(pos + Vector2(-1, -1), 1.5, Color(0.65, 0.6, 0.45, 0.4))

	func _draw_corner_leaf(pos: Vector2, dx: float, dy: float) -> void:
		var col = Color(0.35, 0.6, 0.25, 0.5)
		var pts = PackedVector2Array([
			pos,
			pos + Vector2(dx * 14, dy * 3),
			pos + Vector2(dx * 10, dy * 10),
			pos + Vector2(dx * 3, dy * 14),
		])
		draw_colored_polygon(pts, col)


class _MiniAvatar extends Node2D:
	var gender: String = "boy"

	func _ready() -> void:
		var spr = Sprite2D.new()
		# Player Idle/Down: 236x49, hframes=4, each frame 59x49
		spr.texture = load("res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png")
		spr.hframes = 4
		spr.frame = 0
		spr.scale = Vector2(1.8, 1.8)
		if gender == "girl":
			spr.modulate = Color(1.05, 0.78, 0.92)
		add_child(spr)

	func _draw() -> void:
		pass


class _FooterDrawer extends Node2D:
	func _draw() -> void:
		# Dark gradient footer bar
		for i in range(8):
			var t = float(i) / 8.0
			var alpha = t * 0.85
			draw_rect(Rect2(0, 480 + i * 8, 960, 9), Color(0.06, 0.04, 0.02, alpha))
		# Full dark at bottom
		draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.04, 0.02, 0.88))
		# Gold accent line at top of footer
		draw_line(Vector2(20, 498), Vector2(940, 498), Color(0.55, 0.4, 0.15, 0.35), 1.0)


# Pixelwood Valley sprites for start screen
const PW_START = {
	"tree": "res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
}

class _DecorDrawer extends Node2D:
	var _tree_sprites: Array = []
	var _animal_sprites: Array = []
	var _tree_variants = [
		"res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
		"res://Pixelwood Valley 1.1.2/Trees/2.png",
		"res://Pixelwood Valley 1.1.2/Trees/3.png",
		"res://Pixelwood Valley 1.1.2/Trees/4.png",
		"res://Pixelwood Valley 1.1.2/Trees/5.png",
		"res://Pixelwood Valley 1.1.2/Trees/6.png",
	]
	# Pre-generated positions for grass and flowers
	var _grass_pts: Array = []
	var _flower_pts: Array = []
	var _flower_cols: Array = []

	func _ready() -> void:
		# Trees on hillside
		var tree_positions = [
			Vector2(40, 460), Vector2(110, 475), Vector2(160, 465),
			Vector2(790, 470), Vector2(860, 458), Vector2(920, 472),
		]
		for p in tree_positions:
			var spr = Sprite2D.new()
			spr.texture = load(_tree_variants[randi() % _tree_variants.size()])
			spr.scale = Vector2(0.75, 0.75)
			spr.position = p + Vector2(0, -35)
			_tree_sprites.append(spr)
			add_child(spr)

		# Chicken on the hillside
		var chicken = Sprite2D.new()
		chicken.texture = load("res://Cute_Fantasy_Free/Animals/Chicken/Chicken.png")
		chicken.hframes = 2
		chicken.vframes = 2
		chicken.frame = 0
		chicken.scale = Vector2(1.5, 1.5)
		chicken.position = Vector2(200, 450)
		_animal_sprites.append(chicken)
		add_child(chicken)

		# Cow on the other side
		var cow = Sprite2D.new()
		cow.texture = load("res://Cute_Fantasy_Free/Animals/Cow/Cow.png")
		cow.hframes = 2
		cow.vframes = 2
		cow.frame = 0
		cow.scale = Vector2(1.3, 1.3)
		cow.position = Vector2(750, 455)
		_animal_sprites.append(cow)
		add_child(cow)

		# Fence segment on the near hill
		var fence = Sprite2D.new()
		fence.texture = load("res://Cute_Fantasy_Free/Outdoor decoration/Fences.png")
		fence.scale = Vector2(1.2, 1.2)
		fence.position = Vector2(680, 442)
		add_child(fence)

		# Mill on the hill
		var mill = Sprite2D.new()
		mill.texture = load("res://Pixelwood Valley 1.1.2/Farm/Mill/1.png")
		mill.scale = Vector2(1.5, 1.5)
		mill.position = Vector2(520, 390)
		add_child(mill)

		# Directional sign
		var sign_post = Sprite2D.new()
		sign_post.texture = load("res://Pixelwood Valley 1.1.2/Wooden/4.png")
		sign_post.scale = Vector2(1.8, 1.8)
		sign_post.position = Vector2(350, 450)
		add_child(sign_post)

		# Pre-generate grass tufts and flowers
		for i in range(35):
			_grass_pts.append(Vector2(randf() * 960, 410 + randf() * 130))
		for i in range(12):
			_flower_pts.append(Vector2(randf() * 960, 415 + randf() * 110))
			var cols = [
				Color(1.0, 0.4, 0.4, 0.7),
				Color(1.0, 0.85, 0.2, 0.7),
				Color(0.9, 0.5, 0.9, 0.7),
				Color(1.0, 0.6, 0.2, 0.7),
			]
			_flower_cols.append(cols[randi() % cols.size()])

	func _draw() -> void:
		# Grass tufts
		for p in _grass_pts:
			var gc = Color(0.28, 0.48, 0.2, 0.5)
			draw_line(p, p + Vector2(-2, -5), gc, 1.5)
			draw_line(p, p + Vector2(2, -6), gc, 1.5)
			draw_line(p, p + Vector2(0, -7), gc, 1.5)

		# Small flowers
		for i in range(_flower_pts.size()):
			var fp = _flower_pts[i]
			var fc = _flower_cols[i]
			# Stem
			draw_line(fp, fp + Vector2(0, -8), Color(0.3, 0.5, 0.2, 0.6), 1.0)
			# Petals (tiny)
			draw_circle(fp + Vector2(0, -9), 2.5, fc)
			draw_circle(fp + Vector2(0, -9), 1.2, Color(1.0, 1.0, 0.6, 0.5))
