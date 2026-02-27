extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Local dev: run `supabase start` from /projects/jeca-game/ to get these.
# For cloud: swap to your Supabase project URL + anon key.
# ─────────────────────────────────────────────────────────────────────────────
const SUPABASE_URL      = "http://127.0.0.1:54321"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
const SESSION_FILE     = "user://supabase_session.json"

var _access_token:  String = ""
var _refresh_token: String = ""
var _user_id:       String = ""
var _user_email:    String = ""

var is_logged_in: bool = false

signal auth_changed(logged_in: bool)

func _ready() -> void:
	_load_session()

# ── Auth ──────────────────────────────────────────────────────────────────────

func sign_in(email: String, password: String) -> Dictionary:
	var result = await _post(
		"/auth/v1/token?grant_type=password",
		{"email": email, "password": password},
		false
	)
	if not result.has("error") and result.has("access_token"):
		_apply_session(result)
	return result

func sign_up(email: String, password: String) -> Dictionary:
	var result = await _post(
		"/auth/v1/signup",
		{"email": email, "password": password},
		false
	)
	if not result.has("error") and result.has("access_token"):
		_apply_session(result)
	return result

func sign_out() -> void:
	if not _access_token.is_empty():
		_post("/auth/v1/logout", {})  # fire-and-forget
	_clear_session()

func refresh_session() -> bool:
	if _refresh_token.is_empty():
		return false
	var result = await _post(
		"/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": _refresh_token},
		false
	)
	if not result.has("error") and result.has("access_token"):
		_apply_session(result)
		return true
	return false

func get_user_email() -> String:
	return _user_email

# ── Database ──────────────────────────────────────────────────────────────────

# Push one save slot to Supabase (upsert). Fire-and-forget safe.
func push_slot(slot: int, data: Dictionary) -> bool:
	if not is_logged_in:
		return false
	var payload = {
		"user_id":              _user_id,
		"slot_number":          slot,
		"player_name":          data.get("player_name", "Friend"),
		"player_gender":        data.get("player_gender", "boy"),
		"coins":                data.get("coins", 10),
		"day":                  data.get("day", 1),
		"inventory":            data.get("inventory", {}),
		"farm_tiles":           data.get("farm_tiles", []),
		"animals":              data.get("animals", []),
		"math_problems_solved": data.get("math_problems_solved", 0),
		"words_read":           data.get("words_read", 0),
		"intro_seen":           data.get("intro_seen", false),
	}
	var result = await _post(
		"/rest/v1/save_slots",
		payload,
		true,
		{"Prefer": "resolution=merge-duplicates"}
	)
	return not result.has("error")

# Delete a save slot from Supabase.
func delete_slot_from_db(slot: int) -> bool:
	if not is_logged_in:
		return false
	var endpoint = "/rest/v1/save_slots?user_id=eq.%s&slot_number=eq.%d" % [_user_id, slot]
	var result = await _delete(endpoint)
	return not result.has("error")

# Download all 3 slots from Supabase and write them to local cache files.
# Returns true if we got data from the network.
func fetch_and_sync_slots() -> bool:
	if not is_logged_in:
		return false
	var endpoint = "/rest/v1/save_slots?user_id=eq.%s&order=slot_number.asc" % _user_id
	var result = await _http_get(endpoint)
	if not result.has("_array"):
		# Try once with a token refresh on 401
		if result.get("code", 0) == 401:
			var ok = await refresh_session()
			if ok:
				result = await _http_get(endpoint)
		if not result.has("_array"):
			return false
	for row in result["_array"]:
		var slot: int = row.get("slot_number", -1)
		if slot < 0 or slot > 2:
			continue
		var save_data = {
			"player_name":          row.get("player_name", "Friend"),
			"player_gender":        row.get("player_gender", "boy"),
			"coins":                row.get("coins", 10),
			"inventory":            row.get("inventory", {}),
			"farm_tiles":           row.get("farm_tiles", []),
			"animals":              row.get("animals", []),
			"day":                  row.get("day", 1),
			"math_problems_solved": row.get("math_problems_solved", 0),
			"words_read":           row.get("words_read", 0),
			"intro_seen":           row.get("intro_seen", false),
		}
		var file = FileAccess.open("user://cabrera_save_%d.json" % slot, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(save_data))
			file.close()
	return true

# ── Session persistence ───────────────────────────────────────────────────────

func _apply_session(data: Dictionary) -> void:
	_access_token  = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")
	var user       = data.get("user", {})
	_user_id       = user.get("id", "")
	_user_email    = user.get("email", "")
	is_logged_in   = not _access_token.is_empty() and not _user_id.is_empty()
	_save_session()
	emit_signal("auth_changed", is_logged_in)

func _clear_session() -> void:
	_access_token  = ""
	_refresh_token = ""
	_user_id       = ""
	_user_email    = ""
	is_logged_in   = false
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(SESSION_FILE)
	emit_signal("auth_changed", false)

func _save_session() -> void:
	var file = FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"access_token":  _access_token,
			"refresh_token": _refresh_token,
			"user_id":       _user_id,
			"user_email":    _user_email,
		}))
		file.close()

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var file = FileAccess.open(SESSION_FILE, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_access_token  = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")
	_user_id       = data.get("user_id", "")
	_user_email    = data.get("user_email", "")
	is_logged_in   = not _access_token.is_empty() and not _user_id.is_empty()

# ── HTTP helpers ──────────────────────────────────────────────────────────────

func _get_headers(auth: bool = true) -> PackedStringArray:
	var h = PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
	])
	if auth and not _access_token.is_empty():
		h.append("Authorization: Bearer " + _access_token)
	return h

func _post(endpoint: String, body: Dictionary, auth: bool = true, extra: Dictionary = {}) -> Dictionary:
	var req = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var headers = _get_headers(auth)
	for key in extra:
		headers.append(key + ": " + str(extra[key]))
	var err = req.request(
		SUPABASE_URL + endpoint,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		req.queue_free()
		return {"error": "request_failed"}
	var res = await req.request_completed
	req.queue_free()
	return _parse(res)

func _delete(endpoint: String) -> Dictionary:
	var req = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var err = req.request(
		SUPABASE_URL + endpoint,
		_get_headers(),
		HTTPClient.METHOD_DELETE
	)
	if err != OK:
		req.queue_free()
		return {"error": "request_failed"}
	var res = await req.request_completed
	req.queue_free()
	return _parse(res)

func _http_get(endpoint: String) -> Dictionary:
	var req = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var err = req.request(
		SUPABASE_URL + endpoint,
		_get_headers(),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		req.queue_free()
		return {"error": "request_failed"}
	var res = await req.request_completed
	req.queue_free()
	return _parse(res)

func _parse(res: Array) -> Dictionary:
	var code: int    = res[1]
	var text: String = res[3].get_string_from_utf8()
	if text.is_empty():
		if code < 400:
			return {"_status": code}
		return {"error": "http_%d" % code, "code": code}
	var data = JSON.parse_string(text)
	if data == null:
		return {"error": "parse_error", "code": code}
	if code >= 400:
		if data is Dictionary:
			var msg = data.get("error_description",
				data.get("msg", data.get("message", "Error %d" % code)))
			return {"error": msg, "code": code}
		return {"error": "http_%d" % code, "code": code}
	if data is Array:
		return {"_array": data, "_status": code}
	return data
