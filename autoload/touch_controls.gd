extends Node

## TouchControls — Autoload singleton for on-screen touch controls.
## Only visible on web builds. Renders via _draw() on a CanvasLayer (layer 99).
##
## On iPad Safari, Godot's _input() may never receive touch events because the
## browser intercepts them for scrolling/zooming. We bypass this entirely by
## attaching JavaScript touch listeners directly on the canvas element with
## preventDefault(), then polling the touch state from GDScript each frame.
##
## Usage from any scene:
##   var move = TouchControls.get_movement_vector()
##   if TouchControls.is_action_just_pressed(): ...
##   if TouchControls.is_pause_pressed(): ...
##   if TouchControls.is_inventory_pressed(): ...

# ── Constants ────────────────────────────────────────────────────────────────

const VIEWPORT_SIZE := Vector2(960, 540)

# D-pad
const DPAD_CENTER := Vector2(95, 445)   # bottom-left, 95px in from edges
const DPAD_RADIUS := 60.0               # outer radius of d-pad circle
const DPAD_DEAD_ZONE := 12.0            # inner dead zone radius
const DPAD_BG_RADIUS := 70.0            # background circle radius

# Action button (bottom-right)
const ACTION_CENTER := Vector2(890, 465)
const ACTION_RADIUS := 35.0

# Pause button (top-right)
const PAUSE_CENTER := Vector2(925, 35)
const PAUSE_RADIUS := 22.0

# Inventory button (top-right, left of pause)
const INV_CENTER := Vector2(865, 35)
const INV_RADIUS := 22.0

# Colors — farm-themed browns/greens
const COL_DPAD_BG := Color(0.25, 0.18, 0.08, 0.35)
const COL_DPAD_KNOB := Color(0.45, 0.35, 0.15, 0.5)
const COL_DPAD_KNOB_ACTIVE := Color(0.55, 0.42, 0.18, 0.65)
const COL_DPAD_ARROWS := Color(0.9, 0.85, 0.7, 0.4)
const COL_ACTION_BG := Color(0.15, 0.42, 0.15, 0.4)
const COL_ACTION_ACTIVE := Color(0.25, 0.55, 0.25, 0.6)
const COL_PAUSE_BG := Color(0.3, 0.22, 0.1, 0.4)
const COL_PAUSE_ACTIVE := Color(0.5, 0.38, 0.15, 0.6)
const COL_INV_BG := Color(0.3, 0.22, 0.1, 0.4)
const COL_INV_ACTIVE := Color(0.5, 0.38, 0.15, 0.6)
const COL_TEXT := Color(1.0, 0.95, 0.85, 0.6)
const COL_TEXT_ACTIVE := Color(1.0, 0.97, 0.9, 0.85)

# ── State ────────────────────────────────────────────────────────────────────

var _canvas_layer: CanvasLayer
var _draw_node: Control
var _enabled := false

# D-pad tracking
var _dpad_touch_id: int = -1
var _dpad_vector := Vector2.ZERO
var _dpad_knob_pos := Vector2.ZERO  # visual knob offset from center

# Action button
var _action_touch_id: int = -1
var _action_pressed := false
var _action_just_pressed := false

# Pause button
var _pause_touch_id: int = -1
var _pause_pressed := false
var _pause_just_pressed := false

# Inventory button
var _inv_touch_id: int = -1
var _inv_pressed := false
var _inv_just_pressed := false

# Previous frame's touch IDs for detecting "just pressed"
var _prev_action_ids: Array = []
var _prev_pause_ids: Array = []
var _prev_inv_ids: Array = []

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Only enable on web builds
	if not OS.has_feature("web"):
		set_process(false)
		set_process_input(false)
		return

	_enabled = true

	# Create CanvasLayer on top of everything
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 99
	_canvas_layer.name = "TouchControlsLayer"
	add_child(_canvas_layer)

	# Create a Control that handles drawing
	_draw_node = Control.new()
	_draw_node.name = "TouchDraw"
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.size = VIEWPORT_SIZE
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.connect("draw", _on_draw)
	_canvas_layer.add_child(_draw_node)

	# Set up JavaScript touch listeners on the canvas
	_setup_js_touch_listeners()

func _process(_delta: float) -> void:
	if not _enabled:
		return
	# Poll JavaScript for current touch state
	_poll_js_touches()
	_draw_node.queue_redraw()

# ── Public API ───────────────────────────────────────────────────────────────

## Returns a normalized movement vector based on d-pad input.
func get_movement_vector() -> Vector2:
	if not _enabled:
		return Vector2.ZERO
	return _dpad_vector

## Returns true for exactly one frame when the action button is tapped.
func is_action_just_pressed() -> bool:
	if not _enabled:
		return false
	return _action_just_pressed

## Returns true while the action button is held.
func is_action_pressed() -> bool:
	if not _enabled:
		return false
	return _action_pressed

## Returns true for exactly one frame when pause is tapped.
func is_pause_pressed() -> bool:
	if not _enabled:
		return false
	return _pause_just_pressed

## Returns true for exactly one frame when inventory is tapped.
func is_inventory_pressed() -> bool:
	if not _enabled:
		return false
	return _inv_just_pressed

## Show on-screen controls.
func show_controls() -> void:
	if _draw_node:
		_draw_node.visible = true

## Hide on-screen controls.
func hide_controls() -> void:
	if _draw_node:
		_draw_node.visible = false

# ── JavaScript touch capture ────────────────────────────────────────────────
# iPad Safari intercepts touch events for scrolling/zooming before Godot can
# see them. We attach our own listeners with {passive:false} + preventDefault()
# directly on the canvas, then poll the state each frame from GDScript.

func _setup_js_touch_listeners() -> void:
	JavaScriptBridge.eval("""
	(function() {
		var canvas = document.querySelector('canvas');
		if (!canvas) return;

		// Prevent browser default touch behaviors (scroll, zoom, etc.)
		canvas.style.touchAction = 'none';
		canvas.style.webkitTouchCallout = 'none';
		canvas.style.webkitUserSelect = 'none';

		// State: array of {id, x, y} in viewport coords (960x540)
		window._godotTouches = [];

		function toViewport(clientX, clientY) {
			var cr = canvas.getBoundingClientRect();
			var gameAspect = 960 / 540;
			var canvasAspect = cr.width / cr.height;
			var ox = 0, oy = 0, s = 1;
			if (canvasAspect > gameAspect) {
				s = cr.height / 540;
				ox = (cr.width - 960 * s) / 2;
			} else {
				s = cr.width / 960;
				oy = (cr.height - 540 * s) / 2;
			}
			return {
				x: (clientX - cr.left - ox) / s,
				y: (clientY - cr.top - oy) / s
			};
		}

		function updateTouches(e) {
			e.preventDefault();
			var arr = [];
			for (var i = 0; i < e.touches.length; i++) {
				var t = e.touches[i];
				var vp = toViewport(t.clientX, t.clientY);
				arr.push(t.identifier + ':' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1));
			}
			window._godotTouches = arr.join(';');
		}

		canvas.addEventListener('touchstart', updateTouches, {passive: false});
		canvas.addEventListener('touchmove', updateTouches, {passive: false});
		canvas.addEventListener('touchend', updateTouches, {passive: false});
		canvas.addEventListener('touchcancel', updateTouches, {passive: false});

		// Also handle mouse events (for desktop testing)
		var mouseDown = false;
		canvas.addEventListener('mousedown', function(e) {
			mouseDown = true;
			var vp = toViewport(e.clientX, e.clientY);
			window._godotTouches = '-1:' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1);
		});
		canvas.addEventListener('mousemove', function(e) {
			if (!mouseDown) return;
			var vp = toViewport(e.clientX, e.clientY);
			window._godotTouches = '-1:' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1);
		});
		canvas.addEventListener('mouseup', function(e) {
			mouseDown = false;
			window._godotTouches = '';
		});
	})();
	""")

func _poll_js_touches() -> void:
	var raw = JavaScriptBridge.eval("window._godotTouches || ''")
	if raw == null:
		raw = ""
	var state_str: String = str(raw)

	# Parse touches: "id:x,y;id:x,y;..."
	var touches: Array = []  # Array of {id: int, pos: Vector2}
	if state_str.length() > 0:
		var parts = state_str.split(";")
		for part in parts:
			if part.length() == 0:
				continue
			var id_and_pos = part.split(":")
			if id_and_pos.size() != 2:
				continue
			var tid = int(id_and_pos[0])
			var coords = id_and_pos[1].split(",")
			if coords.size() != 2:
				continue
			var pos = Vector2(float(coords[0]), float(coords[1]))
			touches.append({"id": tid, "pos": pos})

	# Track which touch IDs are active this frame
	var active_ids: Array = []
	for t in touches:
		active_ids.append(t["id"])

	# ── D-pad processing ──
	if _dpad_touch_id != -1:
		# Check if our tracked touch is still active
		var found := false
		for t in touches:
			if t["id"] == _dpad_touch_id:
				_update_dpad(t["pos"])
				found = true
				break
		if not found:
			# Touch released
			_dpad_touch_id = -1
			_dpad_vector = Vector2.ZERO
			_dpad_knob_pos = Vector2.ZERO

	# ── Action button processing ──
	var cur_action_ids: Array = []
	for t in touches:
		if _is_in_circle(t["pos"], ACTION_CENTER, ACTION_RADIUS + 15.0):
			cur_action_ids.append(t["id"])

	_action_pressed = cur_action_ids.size() > 0
	# "Just pressed" = new touch ID appeared in action area this frame
	_action_just_pressed = false
	for tid in cur_action_ids:
		if tid not in _prev_action_ids:
			_action_just_pressed = true
			break
	_prev_action_ids = cur_action_ids

	# ── Pause button processing ──
	var cur_pause_ids: Array = []
	for t in touches:
		if _is_in_circle(t["pos"], PAUSE_CENTER, PAUSE_RADIUS + 10.0):
			cur_pause_ids.append(t["id"])

	_pause_pressed = cur_pause_ids.size() > 0
	_pause_just_pressed = false
	for tid in cur_pause_ids:
		if tid not in _prev_pause_ids:
			_pause_just_pressed = true
			break
	_prev_pause_ids = cur_pause_ids

	# ── Inventory button processing ──
	var cur_inv_ids: Array = []
	for t in touches:
		if _is_in_circle(t["pos"], INV_CENTER, INV_RADIUS + 10.0):
			cur_inv_ids.append(t["id"])

	_inv_pressed = cur_inv_ids.size() > 0
	_inv_just_pressed = false
	for tid in cur_inv_ids:
		if tid not in _prev_inv_ids:
			_inv_just_pressed = true
			break
	_prev_inv_ids = cur_inv_ids

	# ── Assign new d-pad touches ──
	if _dpad_touch_id == -1:
		for t in touches:
			var tid = t["id"]
			# Don't steal touches already claimed by buttons
			if tid in cur_action_ids or tid in cur_pause_ids or tid in cur_inv_ids:
				continue
			if _is_in_dpad(t["pos"]):
				_dpad_touch_id = tid
				_update_dpad(t["pos"])
				break

# ── Geometry helpers ────────────────────────────────────────────────────────

func _update_dpad(pos: Vector2) -> void:
	var offset := pos - DPAD_CENTER
	var dist := offset.length()

	if dist < DPAD_DEAD_ZONE:
		_dpad_vector = Vector2.ZERO
		_dpad_knob_pos = offset
		return

	# Clamp knob visual to the d-pad radius
	if dist > DPAD_RADIUS:
		_dpad_knob_pos = offset.normalized() * DPAD_RADIUS
	else:
		_dpad_knob_pos = offset

	# Normalize the movement vector (full magnitude once past dead zone)
	_dpad_vector = offset.normalized()

func _is_in_dpad(pos: Vector2) -> bool:
	return pos.distance_to(DPAD_CENTER) <= DPAD_BG_RADIUS + 20.0

func _is_in_circle(pos: Vector2, center: Vector2, radius: float) -> bool:
	return pos.distance_to(center) <= radius

# ── Drawing ──────────────────────────────────────────────────────────────────

func _on_draw() -> void:
	_draw_dpad()
	_draw_action_button()
	_draw_pause_button()
	_draw_inventory_button()

func _draw_dpad() -> void:
	var dpad_active := _dpad_touch_id != -1

	# Background circle
	_draw_node.draw_circle(DPAD_CENTER, DPAD_BG_RADIUS, COL_DPAD_BG)

	# Directional arrows (small triangles)
	var arrow_dist := 48.0
	var arrow_size := 10.0
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(0, -arrow_dist), Vector2.UP, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(0, arrow_dist), Vector2.DOWN, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(-arrow_dist, 0), Vector2.LEFT, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(arrow_dist, 0), Vector2.RIGHT, arrow_size)

	# Knob (thumb indicator)
	var knob_center := DPAD_CENTER + _dpad_knob_pos
	var knob_color := COL_DPAD_KNOB_ACTIVE if dpad_active else COL_DPAD_KNOB
	_draw_node.draw_circle(knob_center, 22.0, knob_color)

	# Knob border
	_draw_circle_outline(_draw_node, knob_center, 22.0, Color(0.6, 0.5, 0.3, 0.3), 2.0)

func _draw_arrow(node: Control, tip: Vector2, direction: Vector2, size: float) -> void:
	var perp := Vector2(-direction.y, direction.x)
	var base := tip - direction * size
	var points := PackedVector2Array([
		tip,
		base + perp * size * 0.6,
		base - perp * size * 0.6,
	])
	node.draw_colored_polygon(points, COL_DPAD_ARROWS)

func _draw_action_button() -> void:
	var active := _action_pressed
	var bg_col := COL_ACTION_ACTIVE if active else COL_ACTION_BG
	var txt_col := COL_TEXT_ACTIVE if active else COL_TEXT

	# Button circle
	_draw_node.draw_circle(ACTION_CENTER, ACTION_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, ACTION_CENTER, ACTION_RADIUS, Color(0.3, 0.55, 0.3, 0.35), 2.0)

	# "E" label
	_draw_letter_e(_draw_node, ACTION_CENTER, 16.0, txt_col)

func _draw_pause_button() -> void:
	var active := _pause_pressed
	var bg_col := COL_PAUSE_ACTIVE if active else COL_PAUSE_BG
	var icon_col := COL_TEXT_ACTIVE if active else COL_TEXT

	_draw_node.draw_circle(PAUSE_CENTER, PAUSE_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, PAUSE_CENTER, PAUSE_RADIUS, Color(0.5, 0.4, 0.2, 0.3), 1.5)

	# Pause icon (two vertical bars)
	var bar_w := 4.0
	var bar_h := 14.0
	var gap := 4.0
	_draw_node.draw_rect(Rect2(PAUSE_CENTER.x - gap - bar_w, PAUSE_CENTER.y - bar_h / 2, bar_w, bar_h), icon_col)
	_draw_node.draw_rect(Rect2(PAUSE_CENTER.x + gap, PAUSE_CENTER.y - bar_h / 2, bar_w, bar_h), icon_col)

func _draw_inventory_button() -> void:
	var active := _inv_pressed
	var bg_col := COL_INV_ACTIVE if active else COL_INV_BG
	var icon_col := COL_TEXT_ACTIVE if active else COL_TEXT

	_draw_node.draw_circle(INV_CENTER, INV_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, INV_CENTER, INV_RADIUS, Color(0.5, 0.4, 0.2, 0.3), 1.5)

	# Backpack / bag icon — simple rectangle with handle
	var bag_w := 14.0
	var bag_h := 16.0
	var bag_tl := INV_CENTER - Vector2(bag_w / 2, bag_h / 2 - 1)
	_draw_node.draw_rect(Rect2(bag_tl, Vector2(bag_w, bag_h)), icon_col, false, 2.0)
	# Handle arc (simplified as a small rect on top)
	var handle_w := 8.0
	var handle_h := 5.0
	_draw_node.draw_rect(
		Rect2(INV_CENTER.x - handle_w / 2, bag_tl.y - handle_h, handle_w, handle_h),
		icon_col, false, 2.0
	)

func _draw_circle_outline(node: Control, center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count := 32
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var angle := (float(i) / point_count) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(point_count):
		node.draw_line(points[i], points[i + 1], color, width)

func _draw_letter_e(node: Control, center: Vector2, size: float, color: Color) -> void:
	var half := size / 2.0
	var left := center.x - half * 0.4
	var right := center.x + half * 0.5
	var top := center.y - half
	var mid := center.y
	var bottom := center.y + half
	var w := 2.5
	node.draw_line(Vector2(left, top), Vector2(left, bottom), color, w)
	node.draw_line(Vector2(left, top), Vector2(right, top), color, w)
	node.draw_line(Vector2(left, mid), Vector2(right - 2, mid), color, w)
	node.draw_line(Vector2(left, bottom), Vector2(right, bottom), color, w)
