extends Control
## Pocket Chat : chat + fichiers sur le réseau local (Wi-Fi/LAN), sans serveur ni internet. PC Linux + Android.
## Découverte : beacon UDP (broadcast) ; liaison : TCP pair-à-pair. Trame : [type u8][longueur u16 LE][données]

const APP_VERSION: String = preload("res://version.gd").VERSION
const KTok := preload("res://kit/tokens.gd")
const KIcon := preload("res://kit/icon.gd")
const KPx := preload("res://kit/ui/px.gd")
const KPixelize := preload("res://kit/pixelize.gd")
const KNav := preload("res://kit/ui/k_navbar.gd")
const PORT := 5205
const BEACON_PORT := 5206
const T_HELLO := 1  # json {id, name, mascot}
const T_MSG := 2  # json {mid, room, text}
const T_FOFFER := 3  # json {fid, name, size, room}
const T_FANS := 4  # json {fid, ok}
const T_FDATA := 5  # u32 fid + octets
const T_FEND := 6  # json {fid, sha}
const T_FACK := 7  # json {fid, ok}
const T_PING := 8
const CHUNK := 32000
const OUT_MAX := 524288
const ONLINE_MS := 9000
const MAX_HIST := 400
const MAX_TEXT := 8000

const C_BG := Color("0e1116")
const C_CARD := Color("171b22")
const C_CARD2 := Color("232a34")
const C_TEXT := Color("e8ecf1")
const C_DIM := Color("8892a0")
const C_OK := Color("4de1b4")
const C_WARN := Color("ffb454")
const C_BAD := Color("ff6b6b")


# ------------------------------------------------------------------ Widgets dessinés (même langage que Pocket Speaker / Launcher)

class Orb extends Control:
	const SHEET := preload("res://mascot/goody.png")
	const ANIMS := {"idle": [0, 4], "happy": [1, 4], "wait": [2, 4], "off": [3, 4], "sad": [4, 4]}
	const FPS := {"idle": 3.0, "happy": 6.0, "wait": 3.0, "off": 1.5, "sad": 2.0}
	var color := Color("5b6573")
	var variant := 0
	var level := 0.0
	var pulse := 0.0
	var t := 0.0
	var anim := "off":
		set(v):
			if v != anim:
				anim = v
				t = 0.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(d: float) -> void:
		pulse = fposmod(pulse + d, TAU)
		t += d * FPS[anim] * (1.0 + level * 1.5)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.26
		for i in 4:
			var rr := r + 8.0 * (i + 1) + level * 14.0 + sin(pulse + i) * 2.0
			draw_circle(c, rr, Color(color, 0.11 - i * 0.025))
		draw_circle(c, r, Color(color, 0.16))
		var row: int = ANIMS[anim][0] + variant * 5
		var n: int = ANIMS[anim][1]
		var sc := maxi(1, int(size.y * 0.72 / 32.0))
		var px := 32 * sc
		var pos := (c - Vector2(px, px) / 2.0).round()
		draw_texture_rect_region(SHEET, Rect2(pos, Vector2(px, px)), Rect2((int(t) % n) * 32, row * 32, 32, 32))


class Ico:
	static func box(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
		KPx.panel(ci, r, col, Color(0, 0, 0, 0), false)

	static func draw_kind(ci: CanvasItem, kind: String, c: Vector2, k: float, col: Color) -> void:
		var w := 3.2 * k
		match kind:
			"refresh":
				var a1 := PI * 1.45
				ci.draw_arc(c, 14.0 * k, -PI * 0.15, a1, 28, col, w, true)
				var p := c + Vector2(cos(a1), sin(a1)) * 14.0 * k
				var tn := Vector2(-sin(a1), cos(a1))
				var nm := Vector2(cos(a1), sin(a1))
				ci.draw_colored_polygon(PackedVector2Array([p + tn * 9.0 * k, p + nm * 7.0 * k, p - nm * 7.0 * k]), col)
			"download":
				ci.draw_line(c + Vector2(0, -16) * k, c + Vector2(0, 6) * k, col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-9, -2) * k, c + Vector2(0, 8) * k,
						c + Vector2(9, -2) * k]), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-14, 12) * k, c + Vector2(-14, 18) * k,
						c + Vector2(14, 18) * k, c + Vector2(14, 12) * k]), col, w, true)
			"check":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-12, 0) * k, c + Vector2(-4, 9) * k,
						c + Vector2(13, -9) * k]), col, 4.0 * k, true)
			"chevron":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-5, -10) * k, c + Vector2(5, 0) * k,
						c + Vector2(-5, 10) * k]), col, 3.6 * k, true)
			"back":
				ci.draw_polyline(PackedVector2Array([c + Vector2(5, -11) * k, c + Vector2(-6, 0) * k,
						c + Vector2(5, 11) * k]), col, 3.8 * k, true)
			"close":
				ci.draw_line(c + Vector2(-10, -10) * k, c + Vector2(10, 10) * k, col, 3.8 * k, true)
				ci.draw_line(c + Vector2(10, -10) * k, c + Vector2(-10, 10) * k, col, 3.8 * k, true)
			"send":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -14) * k, c + Vector2(17, 0) * k,
						c + Vector2(-16, 14) * k, c + Vector2(-10, 0) * k]), col)
			"clip":
				ci.draw_polyline(PackedVector2Array([c + Vector2(8, -6) * k, c + Vector2(8, 8) * k,
						c + Vector2(2, 16) * k, c + Vector2(-6, 16) * k, c + Vector2(-12, 8) * k,
						c + Vector2(-12, -10) * k, c + Vector2(-5, -17) * k, c + Vector2(2, -17) * k,
						c + Vector2(8, -10) * k]), col, 3.0 * k, true)
			"wifi":
				ci.draw_circle(c + Vector2(0, 16) * k, 3.5 * k, col)
				for r in [12.0, 22.0, 32.0]:
					ci.draw_arc(c + Vector2(0, 16) * k, r * k, -2.36, -0.78, 20, col, w, true)
			"people":
				ci.draw_circle(c + Vector2(-7, -8) * k, 6.0 * k, col)
				ci.draw_arc(c + Vector2(-7, 16) * k, 13.0 * k, PI, TAU, 16, col, w, true)
				ci.draw_circle(c + Vector2(10, -6) * k, 5.0 * k, Color(col, 0.7))
				ci.draw_arc(c + Vector2(11, 14) * k, 10.0 * k, PI * 1.1, PI * 1.9, 12, Color(col, 0.7), w, true)
			"file":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-10, 16) * k, c + Vector2(-10, -16) * k,
						c + Vector2(4, -16) * k, c + Vector2(12, -8) * k, c + Vector2(12, 16) * k,
						c + Vector2(-10, 16) * k]), col, 3.0 * k, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(4, -16) * k, c + Vector2(4, -8) * k,
						c + Vector2(12, -8) * k]), col, 2.6 * k, true)
			"clock":
				ci.draw_arc(c, 15.0 * k, 0.0, TAU, 28, col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(0, -8) * k, c, c + Vector2(7, 4) * k]), col, w, true)
			"folder":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-16, 12) * k, c + Vector2(-16, -10) * k,
						c + Vector2(-6, -10) * k, c + Vector2(-2, -5) * k, c + Vector2(16, -5) * k,
						c + Vector2(16, 12) * k, c + Vector2(-16, 12) * k]), col, 3.0 * k, true)
			"gear":
				for i in 8:
					var a := i * TAU / 8.0
					ci.draw_line(c + Vector2(cos(a), sin(a)) * 11.0 * k, c + Vector2(cos(a), sin(a)) * 17.0 * k, col, 5.0 * k, true)
				ci.draw_arc(c, 11.0 * k, 0.0, TAU, 24, col, w, true)
				ci.draw_circle(c, 4.0 * k, col)


class IconBtn extends Control:
	const ICONMAP := {"clip": "paperclip", "back": "chevron-left", "gear": "settings", "people": "user", "refresh": "refresh-cw",
			"download": "download", "close": "x", "check": "check", "chevron": "chevron-right", "folder": "folder-open", "file": "file-text", "clock": "clock"}
	signal pressed
	var kind := "refresh"
	var col := Color("e8ecf1"):
		set(v):
			col = v
			queue_redraw()
	var fill := Color(0, 0, 0, 0):
		set(v):
			fill = v
			queue_redraw()
	var badge := false:
		set(v):
			badge = v
			queue_redraw()
	var spin := false:
		set(v):
			spin = v
			angle = 0.0
			queue_redraw()
	var hot := false
	var angle := 0.0

	func _init(k := "refresh", px := 44) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hot = true
			queue_redraw())
		mouse_exited.connect(func():
			hot = false
			queue_redraw())

	func _process(d: float) -> void:
		if spin:
			angle += d * 6.0
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2.0
		var rad := minf(size.x, size.y) / 2.0
		var base := fill if fill.a > 0.0 else Color("232a34")
		KPx.panel(self, Rect2(Vector2.ZERO, size).grow(-2), base.lightened(0.12) if hot else base, Color(0, 0, 0, 0), true)
		if kind == "send":  # flèche pixel art vers le haut
			var u := maxf(2.0, floorf(size.y / 14.0))
			var sz := KPx.sprite_size(KPx.ARROW_UP, u)
			KPx.sprite(self, KPx.ARROW_UP, (c - sz * 0.5).round(), u, {"#": col})
			return
		var ico: String = ICONMAP.get(kind, "")
		if ico != "":
			var px := 24 if size.y < 56 else 32
			draw_set_transform(c, angle if spin else 0.0)
			draw_texture_rect(KIcon.texture(ico, px), Rect2(-px * 0.5, -px * 0.5, px, px), false, col)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_set_transform(c, angle if spin else 0.0)
			Ico.draw_kind(self, kind, Vector2.ZERO, minf(size.x, size.y) / 46.0 * 0.78, col)
			draw_set_transform(Vector2.ZERO)
		if badge:
			draw_rect(Rect2(c + Vector2(rad * 0.5, -rad * 0.9), Vector2(10, 10)), Color.BLACK)
			draw_rect(Rect2(c + Vector2(rad * 0.5 + 2, -rad * 0.9 + 2), Vector2(6, 6)), Color("ff6b6b"))


class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(58, 34)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_on(v: bool) -> void:  # sans émettre de signal
		on = v

	func _process(d: float) -> void:
		t = move_toward(t, 1.0 if on else 0.0, d * 9.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on = not on
			toggled.emit(on)
			accept_event()

	func _draw() -> void:
		var h := size.y
		var bg := Color("2a313c").lerp(Color("4de1b4"), t)
		KPx.panel(self, Rect2(Vector2.ZERO, size).grow(-2), bg, Color(0, 0, 0, 0), false)
		var kx := lerpf(6.0, size.x - h + 2.0, t)
		KPx.panel(self, Rect2(kx, 6, h - 8, h - 12), Color.WHITE, Color(0, 0, 0, 0), false)


## Mascotte Goody animée dans un rond (variante 0-7). anim : idle / happy / wait / off / sad.
class Avatar extends Control:
	const SHEET := preload("res://mascot/goody.png")
	const BODIES := [Color("4de1b4"), Color("ff8fb1"), Color("6aa8ff"), Color("ffa24d"), Color("b58bff"),
			Color("ffd84d"), Color("ff6b6b"), Color("c9d1da")]
	const ROWS := {"idle": 0, "happy": 1, "wait": 2, "off": 3, "sad": 4}
	const FPS := {"idle": 3.0, "happy": 6.0, "wait": 3.0, "off": 1.5, "sad": 2.0}
	var variant := 0:
		set(v):
			variant = clampi(v, 0, 7)
			queue_redraw()
	var anim := "idle"
	var selected := false:
		set(v):
			selected = v
			queue_redraw()
	var badge := false:
		set(v):
			badge = v
			queue_redraw()
	var online := false:
		set(v):
			online = v
			queue_redraw()
	var show_online := false
	var t := 0.0

	func _init(px := 48) -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(px, px)

	func _process(d: float) -> void:
		t += d * FPS[anim]
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		KPx.panel(self, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).grow(-1), (BODIES[variant] as Color).darkened(0.62), Color("0b0e12") if not selected else Color("4de1b4"), false, 1)
		var s := maxi(32, int(r * 2.0 * 0.86 / 32.0) * 32)
		var row: int = int(ROWS[anim]) + variant * 5
		draw_texture_rect_region(SHEET, Rect2((c - Vector2(s, s) / 2.0).round(), Vector2(s, s)),
				Rect2((int(t) % 4) * 32, row * 32, 32, 32))
		if show_online:
			var d := maxf(10.0, r * 0.5)
			var p := (c + Vector2(r * 0.55, r * 0.55)).round()
			draw_rect(Rect2(p, Vector2(d, d)), Color.BLACK)
			draw_rect(Rect2(p + Vector2(2, 2), Vector2(d - 4, d - 4)), Color("4de1b4") if online else Color("5b6573"))
		if badge:
			var d2 := maxf(10.0, r * 0.5)
			var p2 := (c + Vector2(r * 0.55, -r * 1.05)).round()
			draw_rect(Rect2(p2, Vector2(d2, d2)), Color.BLACK)
			draw_rect(Rect2(p2 + Vector2(2, 2), Vector2(d2 - 4, d2 - 4)), Color("ff6b6b"))


## Carte tapable (distingue le toucher du défilement).
class Card extends PanelContainer:
	signal tapped
	var down := Vector2.ZERO
	var pressing := false

	func _init(col := Color("171b22"), rad := 18, pad := 12) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(rad)
		sb.set_content_margin_all(pad)
		add_theme_stylebox_override("panel", sb)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				down = e.position
				pressing = true
			elif pressing:
				pressing = false
				if e.position.distance_to(down) < 14.0:
					tapped.emit()


# ------------------------------------------------------------------ État

var is_android := OS.has_feature("android")
var test_role := OS.get_environment("CHAT_TEST")
var data_dir := OS.get_environment("CHAT_DATA")
var tcp_port := int(OS.get_environment("CHAT_TCP")) if OS.get_environment("CHAT_TCP") != "" else PORT
var udp_port := int(OS.get_environment("CHAT_UDP")) if OS.get_environment("CHAT_UDP") != "" else BEACON_PORT
var extra_peers: PackedStringArray = OS.get_environment("CHAT_PEERS").split(",", false)

var me_id := ""
var my_name := "Moi"
var my_mascot := 0
var pref_name := ""
var auto_accept := false
var hud_on := true
var hud: Window = null
var profile_t := 0.0
var beacon_t := 0.0

var peers := {}  # id -> {id,name,mascot,ip,port,seen,first,conn,buf,out,up,last_rx,ping_t,xin,xout}
var history := {}  # conv -> Array[Dictionary]
var unread := {}  # conv -> int
var incoming: Array = []  # connexions entrantes pas encore identifiées
var server := TCPServer.new()
var lan := PacketPeerUDP.new()
var beacon := PacketPeerUDP.new()
var sweep_n := 0
var mlock = null
var dl_dir_cache := ""
var save_t := -1.0
var thumbs := {}

var page := "home"
var cur := ""  # conversation ouverte ("all" ou id)
var open_convs: Array = []  # conversations privées ouvertes (mini-fenêtres) ; « Général » est toujours là
var dock: HBoxContainer
var list_dirty := true
var chat_dirty := false
var stick := 0
var file_ui := {}  # mid -> {bar, msg}
var test_t := 0.0
var test_state := 0
var test_src_sha := ""
var test_quit_t := -1.0

# UI
var safe: MarginContainer
var p_home: VBoxContainer
var p_chat: VBoxContainer
var p_set: VBoxContainer
var home_avatar: Avatar
var home_name: Label
var home_gear: IconBtn
var list_box: VBoxContainer
var empty_orb: Orb
var chat_avatar: Avatar
var chat_icon: IconBtn
var chat_name: Label
var chat_back: IconBtn
var chat_dot: Control
var msg_scroll: ScrollContainer
var msg_box: VBoxContainer
var input: LineEdit
var set_name_edit: LineEdit
var set_pickers: Array = []
var set_dir_lbl: Label
var fd: FileDialog
var nav: KNav


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	if data_dir != "":
		DirAccess.make_dir_recursive_absolute(data_dir)
	_load_all()
	if is_android:
		_android_init()
	_read_profile()
	_ensure_self()
	KTok.set_pixel(true)
	_build_ui()
	KPixelize.install(self)
	if server.listen(tcp_port) != OK:
		push_warning("TCP %d occupé" % tcp_port)
	if lan.bind(udp_port) != OK:
		push_warning("UDP %d occupé (découverte en émission seule)" % udp_port)
	beacon.set_broadcast_enabled(true)
	if test_role != "":
		auto_accept = true
		print("CHAT[%s] %s tcp=%d udp=%d" % [test_role, me_id, tcp_port, udp_port])
	if test_role == "":
		_open("all")  # on démarre sur le Général
	else:
		_show("home")
	_start_updates()
	_apply_hud()


## HUD overlay (PC seulement, pas en test headless).
func _apply_hud() -> void:
	var want := hud_on and not is_android and test_role == "" and DisplayServer.get_name() != "headless"
	if want and hud == null:
		hud = preload("res://hud.gd").new()
		hud.visible = false
		add_child(hud)
		hud.setup(self)
	elif not want and hud != null:
		hud.queue_free()
		hud = null


## Ouvre une conversation (ou l'accueil si conv == "") et ramène la fenêtre au premier plan.
func hud_open(conv: String) -> void:
	var w := get_window()
	if w.mode == Window.MODE_MINIMIZED:
		w.mode = Window.MODE_WINDOWED
	w.move_to_foreground()
	w.grab_focus()
	if conv == "":
		_show("home")
	else:
		_open(conv)

## Mise à jour automatique commune aux apps Goodview (kit/update) : carte pixel art, bouton vert « METTRE À JOUR ».
func _start_updates() -> void:
	if test_role != "":
		return
	var ui = preload("res://kit/update/update_ui.gd").new()
	add_child(ui)
	ui.setup("goodview-software/pocket-chat", APP_VERSION)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if page != "home":
			_show("home")
		else:
			_quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		beacon_t = 0.0


func _quit() -> void:
	_save_all()
	if mlock != null:
		mlock.release()
	get_tree().quit()


# ------------------------------------------------------------------ Persistance / profil

func _p(n: String) -> String:
	return (data_dir + "/" + n) if data_dir != "" else "user://" + n


func _load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(_p("pref.cfg")) == OK:
		me_id = str(cf.get_value("me", "id", ""))
		pref_name = str(cf.get_value("me", "name", ""))
		my_mascot = int(cf.get_value("me", "mascot", randi() % 8))
		auto_accept = bool(cf.get_value("me", "auto", false))
		hud_on = bool(cf.get_value("me", "hud", true))
	if me_id == "":
		me_id = "%08x" % (randi() & 0x7fffffff)
		my_mascot = randi() % 8
	if FileAccess.file_exists(_p("history.json")):
		var d = JSON.parse_string(FileAccess.get_file_as_string(_p("history.json")))
		if d is Dictionary:
			history = d.get("history", {})
			unread = d.get("unread", {})
			open_convs = d.get("open", [])
			for id in d.get("peers", {}):
				var pd: Dictionary = d["peers"][id]
				var pr := _new_peer(str(id))
				pr.name = str(pd.get("name", "?"))
				pr.mascot = int(pd.get("mascot", 0))
				pr.ip = str(pd.get("ip", ""))
				pr.port = int(pd.get("port", PORT))
	for conv in history:  # un transfert interrompu par la fermeture ne reprend pas
		for m in history[conv]:
			if m.get("k", "") == "f" and m.get("st", "") in ["offer", "send", "recv"]:
				m["st"] = "fail"
	if cf.get_sections().is_empty():
		_save_all()


func _save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("me", "id", me_id)
	cf.set_value("me", "name", pref_name)
	cf.set_value("me", "mascot", my_mascot)
	cf.set_value("me", "auto", auto_accept)
	cf.set_value("me", "hud", hud_on)
	cf.save(_p("pref.cfg"))
	var pd := {}
	for id in peers:
		if not peers[id].get("self", false):
			pd[id] = {"name": peers[id].name, "mascot": peers[id].mascot, "ip": peers[id].ip, "port": peers[id].port}
	var h := {}
	for conv in history:
		var a: Array = history[conv]
		h[conv] = a.slice(maxi(0, a.size() - MAX_HIST))
	var f := FileAccess.open(_p("history.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"history": h, "unread": unread, "peers": pd, "open": open_convs}))
	save_t = -1.0


func _save_soon() -> void:
	if save_t < 0.0:
		save_t = 1.5


## PC : ~/.config/goodview/profile.json {"pseudo","mascot"} (relu toutes les 2 s). Android : nom de l'appareil.
func _read_profile() -> void:
	var nm := my_name
	var ma := my_mascot
	if OS.get_environment("CHAT_NAME") != "":
		nm = OS.get_environment("CHAT_NAME")
		ma = int(OS.get_environment("CHAT_MASCOT"))
	elif is_android:
		nm = pref_name if pref_name != "" else _device_name()
	else:
		var p := OS.get_environment("HOME") + "/.config/goodview/profile.json"
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				nm = str(d.get("pseudo", "")).strip_edges()
				ma = clampi(int(d.get("mascot", 0)), 0, 7)
		if nm == "":
			nm = OS.get_environment("USER") if OS.get_environment("USER") != "" else "Moi"
	nm = nm.left(24)
	if nm != my_name or ma != my_mascot:
		var first := my_name == "Moi" and home_name == null
		my_name = nm
		my_mascot = ma
		_ensure_self()
		if not first:
			_ui_me()
			for id in peers:
				if peers[id].up:
					_send(peers[id], T_HELLO, _hello())


func _device_name() -> String:
	var n := ""
	var rt = Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
	if rt != null:
		var ctx = rt.getApplicationContext()
		var st = JavaClassWrapper.wrap("android.provider.Settings$Global")
		if ctx != null and st != null:
			var v = st.getString(ctx.getContentResolver(), "device_name")
			if v != null:
				n = str(v)
	if n.strip_edges() == "":
		n = OS.get_model_name()
	if n == "" or n == "GenericDevice":
		n = "Android"
	return n


func _android_init() -> void:
	OS.request_permissions()
	var rt = Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
	if rt == null:
		return
	var ctx = rt.getApplicationContext()
	if ctx == null:
		return
	var wm = ctx.getSystemService("wifi")
	if wm != null:
		mlock = wm.createMulticastLock("pocketchat")
		mlock.setReferenceCounted(false)
		mlock.acquire()


# ------------------------------------------------------------------ Réseau

func _new_peer(id: String) -> Dictionary:
	var pr := {"id": id, "name": "?", "mascot": 0, "ip": "", "port": PORT, "seen": -100000, "first": 0, "conn": null,
			"buf": PackedByteArray(), "out": PackedByteArray(), "up": false, "last_rx": 0, "ping_t": 0, "xin": {}, "xout": {}}
	peers[id] = pr
	return pr


## Contact « Moi » : toujours visible et en ligne ; les trames envoyées vers lui reviennent par le même chemin
## (messages, offres de fichiers, blocs, sha256) que celles d'un vrai pair -> permet de tout tester sans autre appareil.
func _ensure_self() -> void:
	var pr: Dictionary = peers[me_id] if peers.has(me_id) else _new_peer(me_id)
	pr["self"] = true
	pr.up = true
	pr.seen = Time.get_ticks_msec()
	pr.ip = "127.0.0.1"
	var nm := "%s (moi)" % my_name
	if pr.name != nm or pr.mascot != my_mascot:
		pr.name = nm
		pr.mascot = my_mascot
		list_dirty = true
		chat_dirty = true


func _hello() -> PackedByteArray:
	return JSON.stringify({"id": me_id, "name": my_name, "mascot": my_mascot}).to_utf8_buffer()


func _frame(type: int, data: PackedByteArray) -> PackedByteArray:
	var b := PackedByteArray([type, data.size() & 255, (data.size() >> 8) & 255])
	b.append_array(data)
	return b


func _send(pr: Dictionary, type: int, data: PackedByteArray) -> void:
	if pr.conn != null:
		var o: PackedByteArray = pr.out
		o.append_array(_frame(type, data))
		pr.out = o
	elif pr.get("self", false) and type != T_HELLO and type != T_PING:
		_on_frame.call_deferred(pr, type, data)  # bouclage : on « reçoit » ce qu'on s'envoie


func _send_json(pr: Dictionary, type: int, d: Dictionary) -> void:
	_send(pr, type, JSON.stringify(d).to_utf8_buffer())


func _is_online(pr: Dictionary) -> bool:
	return pr.up or Time.get_ticks_msec() - int(pr.seen) < ONLINE_MS


func _targets(conv: String) -> Array:
	var a: Array = []
	if conv == "all":
		for id in peers:
			if peers[id].up and not peers[id].get("self", false):
				a.append(peers[id])
	elif peers.has(conv):
		a.append(peers[conv])
	return a


func _net_tick(delta: float) -> void:
	var now := Time.get_ticks_msec()
	# beacons
	beacon_t -= delta
	if beacon_t <= 0.0:
		beacon_t = 1.5
		_send_beacon()
	while lan.get_available_packet_count() > 0:
		var s := lan.get_packet().get_string_from_utf8()
		var ip := lan.get_packet_ip()
		if s.begins_with("PCHAT|"):
			var d = JSON.parse_string(s.substr(6))
			if d is Dictionary and str(d.get("id", "")) != me_id and str(d.get("id", "")) != "":
				_seen(str(d["id"]), str(d.get("name", "?")), int(d.get("mascot", 0)), ip, int(d.get("port", PORT)))
	# connexions entrantes
	while server.is_connection_available():
		incoming.append({"c": server.take_connection(), "buf": PackedByteArray(), "t": now})
	for inc in incoming.duplicate():
		var c: StreamPeerTCP = inc.c
		c.poll()
		var dead := c.get_status() != StreamPeerTCP.STATUS_CONNECTED or now - int(inc.t) > 8000
		if not dead:
			var n := c.get_available_bytes()
			if n > 0:
				var r := c.get_data(n)
				if r[0] == OK:
					var ib: PackedByteArray = inc.buf
					ib.append_array(r[1])
					inc.buf = ib
			var fr := _parse(inc)
			if not fr.is_empty() and fr[0][0] == T_HELLO:
				_adopt(c, fr[0][1])
				incoming.erase(inc)
				continue
		if dead:
			c.disconnect_from_host()
			incoming.erase(inc)
	# pairs
	for id in peers:
		var pr: Dictionary = peers[id]
		_peer_tick(pr, now, delta)


func _send_beacon() -> void:
	var pkt := ("PCHAT|" + JSON.stringify({"id": me_id, "name": my_name, "mascot": my_mascot, "port": tcp_port})).to_utf8_buffer()
	var dests: Array = [["255.255.255.255", udp_port]]
	for a in IP.get_local_addresses():
		var p := str(a).split(".")
		if p.size() == 4 and not str(a).begins_with("127.") and not str(a).begins_with("169.254."):
			dests.append(["%s.%s.%s.255" % [p[0], p[1], p[2]], udp_port])
	sweep_n += 1
	if sweep_n % 4 == 1:  # diffusion bloquée (point d'accès, partage de connexion) : balayage unicast du /24
		for a in IP.get_local_addresses():
			var p2 := str(a).split(".")
			if p2.size() == 4 and not str(a).begins_with("127.") and not str(a).begins_with("169.254."):
				for h in range(1, 255):
					if str(h) != p2[3]:
						dests.append(["%s.%s.%s.%d" % [p2[0], p2[1], p2[2], h], udp_port])
	for e in extra_peers:
		var hp := e.split(":")
		if hp.size() == 2:
			dests.append([hp[0], int(hp[1])])
	for d in dests:
		beacon.set_dest_address(d[0], d[1])
		beacon.put_packet(pkt)


func _seen(id: String, nm: String, ma: int, ip: String, port: int) -> void:
	var pr: Dictionary = peers[id] if peers.has(id) else _new_peer(id)
	var was := _is_online(pr)
	if pr.name != nm or pr.mascot != ma:
		pr.name = nm
		pr.mascot = ma
		_save_soon()
		list_dirty = true
		chat_dirty = true
	pr.ip = ip
	pr.port = port
	if not was:
		pr.first = Time.get_ticks_msec()
		list_dirty = true
	pr.seen = Time.get_ticks_msec()


func _adopt(c: StreamPeerTCP, data: PackedByteArray) -> void:
	var d = JSON.parse_string(data.get_string_from_utf8())
	if not (d is Dictionary) or not d.has("id"):
		c.disconnect_from_host()
		return
	var id := str(d.id)
	var pr: Dictionary = peers[id] if peers.has(id) else _new_peer(id)
	if pr.conn != null:
		(pr.conn as StreamPeerTCP).poll()
		var alive: bool = (pr.conn as StreamPeerTCP).get_status() == StreamPeerTCP.STATUS_CONNECTED
		if alive and pr.up and not (id < me_id):  # doublon : on garde la liaison initiée par le plus petit id
			c.disconnect_from_host()
			return
		_drop(pr)
	pr.conn = c
	pr.buf = PackedByteArray()
	pr.out = PackedByteArray()
	pr.ip = c.get_connected_host()
	pr.last_rx = Time.get_ticks_msec()
	_send(pr, T_HELLO, _hello())
	_got_hello(pr, data)


func _peer_tick(pr: Dictionary, now: int, delta: float) -> void:
	if pr.get("self", false):
		pr.up = true
		pr.seen = now
		_pump_files(pr)
		return
	var c: StreamPeerTCP = pr.conn
	if c == null:
		var online := now - int(pr.seen) < ONLINE_MS
		# Pair vu par beacon : on se connecte. Pair seulement connu (broadcast bloqué par le réseau) : on retente son dernier IP.
		var known: bool = (not online) and pr.ip != "" and pr.ip != "127.0.0.1"
		if (online or known) and pr.ip != "" and (me_id < str(pr.id) or now - int(pr.first) > 3000 or known):
			if now - int(pr.get("try", 0)) > (2500 if online else 7000):
				pr["try"] = now
				c = StreamPeerTCP.new()
				var ce := c.connect_to_host(pr.ip, pr.port)
				if ce == OK:
					pr.conn = c
					pr.up = false
					pr.buf = PackedByteArray()
					pr.out = PackedByteArray()
					pr.last_rx = now
					pr["hello_sent"] = false
		return
	c.poll()
	var st := c.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		if now - int(pr.last_rx) > 6000:
			_drop(pr)
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_drop(pr)
		return
	if not pr.get("hello_sent", true):
		pr["hello_sent"] = true
		_send(pr, T_HELLO, _hello())
	# lecture
	var n := mini(c.get_available_bytes(), 1048576)
	if n > 0:
		var r := c.get_data(n)
		if r[0] != OK:
			_drop(pr)
			return
		var pb: PackedByteArray = pr.buf
		pb.append_array(r[1])
		pr.buf = pb
		pr.last_rx = now
		for f in _parse(pr):
			_on_frame(pr, f[0], f[1])
			if pr.conn == null:
				return
	# keep-alive
	if pr.up:
		pr.ping_t = int(pr.ping_t) - int(delta * 1000.0)
		if pr.ping_t <= 0:
			pr.ping_t = 4000
			_send(pr, T_PING, PackedByteArray())
		if now - int(pr.last_rx) > 14000:
			_drop(pr)
			return
	# envoi des blocs de fichier (flux contrôlé par la taille du tampon)
	if pr.up:
		_pump_files(pr)
	_flush(pr)


func _flush(pr: Dictionary) -> void:
	var out: PackedByteArray = pr.out
	if out.is_empty():
		return
	var r: Array = (pr.conn as StreamPeerTCP).put_partial_data(out)
	if r[0] != OK:
		_drop(pr)
		return
	pr.out = out.slice(r[1]) if r[1] > 0 else out


## Découpe les trames reçues : retourne [[type, data], ...] et retire les octets consommés du tampon.
func _parse(holder: Dictionary) -> Array:
	var buf: PackedByteArray = holder.buf
	var res: Array = []
	var i := 0
	while buf.size() - i >= 3:
		var ln := buf[i + 1] | (buf[i + 2] << 8)
		if buf.size() - i < 3 + ln:
			break
		res.append([buf[i], buf.slice(i + 3, i + 3 + ln)])
		i += 3 + ln
	if i > 0:
		holder.buf = buf.slice(i)
	return res


func _drop(pr: Dictionary) -> void:
	if pr.conn != null:
		(pr.conn as StreamPeerTCP).disconnect_from_host()
	pr.conn = null
	var was: bool = pr.up
	pr.up = false
	pr.out = PackedByteArray()
	for fid in pr.xin.keys():
		var x: Dictionary = pr.xin[fid]
		if x.f != null:
			(x.f as FileAccess).close()
		_set_st(x.msg, "fail")
	for fid in pr.xout.keys():
		var x2: Dictionary = pr.xout[fid]
		if x2.f != null:
			(x2.f as FileAccess).close()
		_set_st(x2.msg, "fail")
	pr.xin = {}
	pr.xout = {}
	if was:
		list_dirty = true
		chat_dirty = true


func _got_hello(pr: Dictionary, data: PackedByteArray) -> void:
	var d = JSON.parse_string(data.get_string_from_utf8())
	if d is Dictionary:
		pr.name = str(d.get("name", pr.name))
		pr.mascot = clampi(int(d.get("mascot", 0)), 0, 7)
	pr.seen = Time.get_ticks_msec()
	var first: bool = not pr.up
	pr.up = true
	pr.ping_t = 4000
	_save_soon()
	list_dirty = true
	chat_dirty = true
	if first:
		for m in history.get(pr.id, []):  # messages en attente
			if m.get("k", "") == "t" and m.get("me", false) and m.get("st", "") == "q":
				_send_json(pr, T_MSG, {"mid": m.id, "room": false, "text": m.text})
				m["st"] = "ok"


func _on_frame(pr: Dictionary, type: int, data: PackedByteArray) -> void:
	match type:
		T_HELLO:
			_got_hello(pr, data)
		T_PING:
			pass
		T_MSG:
			var d = JSON.parse_string(data.get_string_from_utf8())
			if d is Dictionary:
				var conv: String = "all" if d.get("room", false) else str(pr.id)
				_add_msg(conv, {"id": str(d.get("mid", "")), "k": "t", "me": false, "from": pr.id, "ts": Time.get_unix_time_from_system(),
						"text": str(d.get("text", "")).left(MAX_TEXT)})
				_test_hook("text", str(d.get("text", "")))
		T_FOFFER:
			_on_offer(pr, data)
		T_FANS:
			var d = JSON.parse_string(data.get_string_from_utf8())
			if d is Dictionary and pr.xout.has(int(d.get("fid", -1))):
				var x: Dictionary = pr.xout[int(d.fid)]
				if d.get("ok", false):
					x.state = "send"
					_set_st(x.msg, "send")
				else:
					if x.f != null:
						(x.f as FileAccess).close()
					pr.xout.erase(int(d.fid))
					_set_st(x.msg, "refused")
		T_FDATA:
			if data.size() >= 4:
				var fid := data.decode_u32(0)
				if pr.xin.has(fid):
					var x: Dictionary = pr.xin[fid]
					var body := data.slice(4)
					(x.f as FileAccess).store_buffer(body)
					(x.hash as HashingContext).update(body)
					x.got += body.size()
					x.msg["prog"] = float(x.got) / maxf(1.0, float(x.msg.size))
		T_FEND:
			var d = JSON.parse_string(data.get_string_from_utf8())
			if d is Dictionary and pr.xin.has(int(d.get("fid", -1))):
				var fid := int(d.fid)
				var x: Dictionary = pr.xin[fid]
				(x.f as FileAccess).close()
				var sha: String = (x.hash as HashingContext).finish().hex_encode()
				var ok: bool = sha == str(d.get("sha", "")) and x.got == int(x.msg.size)
				pr.xin.erase(fid)
				x.msg["prog"] = 1.0
				_set_st(x.msg, "done" if ok else "bad")
				_send_json(pr, T_FACK, {"fid": fid, "ok": ok})
				_test_hook("file", x.msg)
		T_FACK:
			var d = JSON.parse_string(data.get_string_from_utf8())
			if d is Dictionary and pr.xout.has(int(d.get("fid", -1))):
				var x: Dictionary = pr.xout[int(d.fid)]
				pr.xout.erase(int(d.fid))
				_set_st(x.msg, "done" if d.get("ok", false) else "bad")
				_test_hook("ack", x.msg)


func _set_st(msg: Dictionary, st: String) -> void:
	msg["st"] = st
	chat_dirty = true
	_save_soon()


func _add_msg(conv: String, m: Dictionary) -> void:
	if not history.has(conv):
		history[conv] = []
	(history[conv] as Array).append(m)
	if conv != "all" and not m.get("me", false) and conv not in open_convs:
		open_convs.append(conv)
	if not m.get("me", false):
		if not (page == "chat" and cur == conv):
			unread[conv] = int(unread.get(conv, 0)) + 1
			if not get_window().has_focus():
				DisplayServer.window_request_attention()
				if hud != null:
					var who := str(peers[m.from].name) if peers.has(str(m.get("from", ""))) else "?"
					var mo := int(peers[m.from].mascot) if peers.has(str(m.get("from", ""))) else 0
					var body := str(m.get("text", "")) if m.get("k", "") == "t" else "Fichier : " + str(m.get("name", ""))
					hud.notify(conv, who + (" · Général" if conv == "all" else ""), body.replace("\n", " "), mo)
		if page == "chat" and cur == conv:
			stick = 3
	elif conv == cur:
		stick = 3
	list_dirty = true
	chat_dirty = true
	_save_soon()


# ------------------------------------------------------------------ Messages et fichiers

func _send_text(conv: String, text: String) -> void:
	text = text.strip_edges().left(MAX_TEXT)
	if text == "":
		return
	var mid := "%d%04x" % [Time.get_ticks_msec(), randi() & 0xffff]
	var m := {"id": mid, "k": "t", "me": true, "ts": Time.get_unix_time_from_system(), "text": text, "st": "ok"}
	if conv == "all":
		for pr in _targets("all"):
			_send_json(pr, T_MSG, {"mid": mid, "room": true, "text": text})
	elif peers.has(conv) and peers[conv].up:
		_send_json(peers[conv], T_MSG, {"mid": mid, "room": false, "text": text})
	else:
		m["st"] = "q"
	_add_msg(conv, m)


func _send_file(conv: String, path: String) -> void:
	for pr in _targets(conv):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var size := f.get_length()
		var fid := randi() & 0x7fffffff
		var name := path.get_file()
		if name == "":
			name = "fichier"
		var m := {"id": "f%d" % fid, "k": "f", "me": true, "ts": Time.get_unix_time_from_system(), "name": name, "size": size,
				"st": "offer", "prog": 0.0, "path": path, "to": pr.name}
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA256)
		pr.xout[fid] = {"f": f, "size": size, "sent": 0, "hash": hc, "state": "offer", "msg": m, "end": false}
		_send_json(pr, T_FOFFER, {"fid": fid, "name": name, "size": size, "room": conv == "all"})
		_add_msg(conv, m)


func _on_offer(pr: Dictionary, data: PackedByteArray) -> void:
	var d = JSON.parse_string(data.get_string_from_utf8())
	if not (d is Dictionary):
		return
	var fid := int(d.get("fid", 0))
	var conv: String = "all" if d.get("room", false) else str(pr.id)
	var m := {"id": "r%d_%s" % [fid, pr.id], "k": "f", "me": false, "from": pr.id, "ts": Time.get_unix_time_from_system(),
			"name": _clean_name(str(d.get("name", "fichier"))), "size": int(d.get("size", 0)), "st": "offer", "prog": 0.0, "fid": fid}
	_add_msg(conv, m)
	if auto_accept:
		_answer(pr, m, true)
	else:
		m["pid"] = pr.id


func _clean_name(n: String) -> String:
	n = n.get_file()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		n = n.replace(ch, "_")
	n = n.strip_edges().lstrip(".")
	return n if n != "" else "fichier"


func _dl_dir() -> String:
	if dl_dir_cache != "":
		return dl_dir_cache
	var cands: Array = []
	if OS.get_environment("CHAT_DL") != "":
		cands.append(OS.get_environment("CHAT_DL"))
	else:
		var sd := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if sd != "":
			cands.append(sd.path_join("PocketChat"))
	cands.append(ProjectSettings.globalize_path("user://").path_join("received") if data_dir == "" else data_dir.path_join("received"))
	for c in cands:
		if DirAccess.make_dir_recursive_absolute(c) == OK or DirAccess.dir_exists_absolute(c):
			var t := FileAccess.open(str(c).path_join(".w"), FileAccess.WRITE)
			if t != null:
				t.close()
				DirAccess.remove_absolute(str(c).path_join(".w"))
				dl_dir_cache = c
				return c
	dl_dir_cache = "user://"
	return dl_dir_cache


func _answer(pr: Dictionary, m: Dictionary, ok: bool) -> void:
	if not pr.up or m.get("st", "") != "offer":
		return
	var fid: int = int(m.fid)
	if not ok:
		_send_json(pr, T_FANS, {"fid": fid, "ok": false})
		_set_st(m, "refused")
		return
	var dir := _dl_dir()
	var base := str(m.name)
	var path := dir.path_join(base)
	var i := 1
	while FileAccess.file_exists(path):
		path = dir.path_join("%s (%d).%s" % [base.get_basename(), i, base.get_extension()] if base.get_extension() != "" else "%s (%d)" % [base, i])
		i += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_send_json(pr, T_FANS, {"fid": fid, "ok": false})
		_set_st(m, "fail")
		return
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	m["path"] = path
	pr.xin[fid] = {"f": f, "got": 0, "hash": hc, "msg": m}
	_send_json(pr, T_FANS, {"fid": fid, "ok": true})
	_set_st(m, "recv")


func _pump_files(pr: Dictionary) -> void:
	var budget := 16
	for fid in pr.xout.keys():
		var x: Dictionary = pr.xout[fid]
		if x.state != "send" or x.end:
			continue
		while budget > 0 and (pr.out as PackedByteArray).size() < OUT_MAX and x.sent < x.size:
			var b: PackedByteArray = (x.f as FileAccess).get_buffer(mini(CHUNK, x.size - x.sent))
			if b.is_empty():
				break
			(x.hash as HashingContext).update(b)
			var head := PackedByteArray()
			head.resize(4)
			head.encode_u32(0, fid)
			head.append_array(b)
			_send(pr, T_FDATA, head)
			x.sent += b.size()
			budget -= 1
		x.msg["prog"] = float(x.sent) / maxf(1.0, float(x.size))
		if x.sent >= x.size:
			x.end = true
			(x.f as FileAccess).close()
			_send_json(pr, T_FEND, {"fid": fid, "sha": (x.hash as HashingContext).finish().hex_encode()})


func _pick_file() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Fichier", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
				PackedStringArray(), func(ok: bool, paths: PackedStringArray, _i: int):
					if ok and paths.size() > 0:
						_send_file(cur, paths[0]))
	else:
		fd.popup_centered_ratio(0.85)


# ------------------------------------------------------------------ Interface

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_color", "LineEdit", C_TEXT)
	th.set_color("caret_color", "LineEdit", C_OK)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0, 0, 0, 0.85)  # champ « Minecraft » : noir, cadre gris 2 px, blanc au focus
	le.border_color = Color("5a5a5a")
	le.set_border_width_all(2)
	le.set_corner_radius_all(0)
	le.content_margin_left = 18
	le.content_margin_right = 18
	le.content_margin_top = 10
	le.content_margin_bottom = 10
	th.set_stylebox("normal", "LineEdit", le)
	var lf: StyleBoxFlat = le.duplicate()
	lf.border_color = Color("a0a0a0")
	th.set_stylebox("focus", "LineEdit", lf)
	th.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	var track := StyleBoxFlat.new()
	track.bg_color = Color("2a313c")
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_OK
	fill.set_corner_radius_all(4)
	th.set_stylebox("background", "ProgressBar", track)
	th.set_stylebox("fill", "ProgressBar", fill)
	var sc := StyleBoxEmpty.new()
	th.set_stylebox("scroll", "VScrollBar", sc)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color(1, 1, 1, 0.12)
	gr.set_corner_radius_all(3)
	for n in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(n, "VScrollBar", gr)
	var pop := StyleBoxFlat.new()
	pop.bg_color = C_CARD
	th.set_stylebox("panel", "Window", pop)
	th.set_stylebox("embedded_border", "Window", pop)
	return KPixelize.theme(th)


func _lbl(t: String, sz := 17, col := C_TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Les ENFANTS ignorent la souris pour que la carte (le parent) reçoive le clic ; la carte elle-même reste cliquable.
func _ign(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ign(c)


func _build_ui() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var host := Control.new()
	safe.add_child(host)
	p_home = VBoxContainer.new()
	p_chat = VBoxContainer.new()
	p_set = VBoxContainer.new()
	for p in [p_home, p_chat, p_set]:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.add_theme_constant_override("separation", 12)
		host.add_child(p)
	_build_home()
	_build_chat()
	_build_settings()
	nav = KNav.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -KNav.HEIGHT
	nav.setup([{"id": "home", "label": "Contacts", "icon": "message-circle"}, {"id": "set", "label": "Réglages", "icon": "settings"}], "home")
	nav.selected.connect(func(id: String): _show(id))
	add_child(nav)
	fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = false
	fd.file_selected.connect(func(p: String): _send_file(cur, p))
	add_child(fd)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var side := maxf(14.0, (w - 640.0) / 2.0)
	var top := 12.0
	var bot := 12.0
	if is_android:
		var sc := get_viewport().get_final_transform().get_scale().x
		var sa := DisplayServer.get_display_safe_area()
		var scr := DisplayServer.screen_get_size()
		top += maxf(0.0, sa.position.y / sc)
		bot += maxf(0.0, (scr.y - sa.end.y) / sc)
		bot += DisplayServer.virtual_keyboard_get_height() / sc
		side += maxf(0.0, sa.position.x / sc)
	if nav != null:
		nav.offset_bottom = -(bot - 12.0)
		nav.offset_top = nav.offset_bottom - KNav.HEIGHT
		if nav.visible:
			bot += KNav.HEIGHT
	safe.add_theme_constant_override("margin_left", int(side))
	safe.add_theme_constant_override("margin_right", int(side))
	safe.add_theme_constant_override("margin_top", int(top))
	safe.add_theme_constant_override("margin_bottom", int(bot))


func _build_home() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	home_avatar = Avatar.new(52)
	home_avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	home_avatar.gui_input.connect(func(e: InputEvent):
		if is_android and e is InputEventMouseButton and e.pressed:
			my_mascot = (my_mascot + 1) % 8
			_ui_me()
			_save_soon())
	head.add_child(home_avatar)
	home_name = _lbl("", 20)
	home_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(home_name)
	head.add_child(_spacer())
	var wifi := IconBtn.new("wifi", 44)
	wifi.col = C_OK
	wifi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(wifi)
	home_gear = IconBtn.new("gear", 44)
	home_gear.pressed.connect(func(): _show("set"))
	head.add_child(home_gear)
	p_home.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	sc.add_child(list_box)
	p_home.add_child(sc)
	empty_orb = Orb.new()
	empty_orb.color = C_OK
	empty_orb.anim = "wait"
	empty_orb.custom_minimum_size = Vector2(0, 240)
	empty_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_me()


func _ui_me() -> void:
	if home_name == null:
		return
	home_name.text = my_name
	home_avatar.variant = my_mascot
	empty_orb.variant = my_mascot
	if set_name_edit != null:
		for i in set_pickers.size():
			(set_pickers[i] as Avatar).selected = i == my_mascot


func _refresh_home() -> void:
	for c in list_box.get_children():
		if c != empty_orb:
			c.queue_free()
	if empty_orb.get_parent() == list_box:
		list_box.remove_child(empty_orb)
	# salon commun
	var tot := 0
	for id in peers:
		if peers[id].up:
			tot += 1
	var all := Card.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var ic := IconBtn.new("people", 48)
	ic.fill = Color(C_OK, 0.18)
	ic.col = C_OK
	hb.add_child(ic)
	var t := _lbl("Général", 19)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	hb.add_child(_spacer())
	hb.add_child(_chip(str(tot), "wifi", C_OK if tot > 0 else C_DIM))
	if int(unread.get("all", 0)) > 0:
		hb.add_child(_count(int(unread["all"])))
	all.add_child(hb)
	_ign(all)
	all.tapped.connect(_open.bind("all"))
	list_box.add_child(all)
	# pairs : en ligne d'abord
	var ids: Array = peers.keys()
	ids.sort_custom(func(a, b):
		var oa := _is_online(peers[a])
		var ob := _is_online(peers[b])
		if oa != ob:
			return oa
		return str(peers[a].name).naturalnocasecmp_to(str(peers[b].name)) < 0)
	var any_online := false
	for id in ids:
		var pr: Dictionary = peers[id]
		var on := _is_online(pr)
		any_online = any_online or on
		var card := Card.new()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var av := Avatar.new(48)
		av.variant = pr.mascot
		av.anim = "idle" if on else "off"
		av.show_online = true
		av.online = on
		h.add_child(av)
		var nl := _lbl(str(pr.name), 19, C_TEXT if on else C_DIM)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		h.add_child(nl)
		if int(unread.get(id, 0)) > 0:
			h.add_child(_count(int(unread[id])))
		else:
			var ch := IconBtn.new("chevron", 32)
			ch.col = C_DIM
			ch.fill = Color(0, 0, 0, 0)
			h.add_child(ch)
		card.add_child(h)
		_ign(card)
		card.tapped.connect(_open.bind(id))
		list_box.add_child(card)
	if not any_online:
		list_box.add_child(empty_orb)
	var n := 0
	for k in unread:
		n += int(unread[k])
	DisplayServer.window_set_title("Pocket Chat" + (" (%d)" % n if n > 0 else ""))
	home_gear.badge = false
	list_dirty = false


func _chip(txt: String, ico: String, col: Color) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.14)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(_lbl(txt, 16, col))
	pc.add_child(h)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc


func _count(n: int) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BAD
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(_lbl(str(n) if n < 100 else "99+", 15, Color.WHITE))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc


func _build_chat() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	chat_back = IconBtn.new("back", 44)
	chat_back.pressed.connect(func(): _show("home"))
	head.add_child(chat_back)
	chat_avatar = Avatar.new(44)
	chat_avatar.show_online = true
	head.add_child(chat_avatar)
	chat_icon = IconBtn.new("people", 44)
	chat_icon.fill = Color(C_OK, 0.18)
	chat_icon.col = C_OK
	chat_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(chat_icon)
	chat_name = _lbl("", 20)
	chat_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_name.clip_text = true
	head.add_child(chat_name)
	p_chat.add_child(head)
	var dock_scroll := ScrollContainer.new()
	dock_scroll.custom_minimum_size = Vector2(0, 52)
	dock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock = HBoxContainer.new()
	dock.add_theme_constant_override("separation", 8)
	dock_scroll.add_child(dock)
	p_chat.add_child(dock_scroll)
	msg_scroll = ScrollContainer.new()
	msg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msg_box = VBoxContainer.new()
	msg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_box.add_theme_constant_override("separation", 8)
	msg_scroll.add_child(msg_box)
	p_chat.add_child(msg_scroll)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var clip := IconBtn.new("clip", 48)
	clip.pressed.connect(_pick_file)
	bar.add_child(clip)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 2000
	input.text_submitted.connect(func(_t: String): _submit())
	bar.add_child(input)
	var snd := IconBtn.new("send", 48)
	snd.fill = C_OK
	snd.col = C_BG
	snd.pressed.connect(_submit)
	bar.add_child(snd)
	p_chat.add_child(bar)


func _submit() -> void:
	if input.text.strip_edges() == "":
		return
	_send_text(cur, input.text)
	input.text = ""
	if not is_android:
		input.grab_focus()


func _build_settings() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var b := IconBtn.new("back", 44)
	b.pressed.connect(func(): _show("home"))
	head.add_child(b)
	var gi := IconBtn.new("gear", 44)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gi)
	p_set.add_child(head)
	var c1 := Card.new()
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 12)
	var di := IconBtn.new("download", 44)
	di.col = C_OK
	di.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h1.add_child(di)
	h1.add_child(_spacer())
	var tg := Toggle.new()
	tg.set_on(auto_accept)
	tg.toggled.connect(func(on: bool):
		auto_accept = on
		_save_soon())
	h1.add_child(tg)
	c1.add_child(h1)
	p_set.add_child(c1)
	if not is_android:
		var ch := Card.new()
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 12)
		var hi := IconBtn.new("people", 44)
		hi.col = C_OK
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hh.add_child(hi)
		hh.add_child(_spacer())
		var ht := Toggle.new()
		ht.set_on(hud_on)
		ht.toggled.connect(func(on: bool):
			hud_on = on
			_apply_hud()
			_save_soon())
		hh.add_child(ht)
		ch.add_child(hh)
		p_set.add_child(ch)
	var c2 := Card.new()
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	var fi := HBoxContainer.new()
	fi.add_theme_constant_override("separation", 12)
	var fic := IconBtn.new("folder", 44)
	fic.col = C_OK
	fic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fi.add_child(fic)
	set_dir_lbl = _lbl("", 14, C_DIM)
	set_dir_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	set_dir_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fi.add_child(set_dir_lbl)
	v2.add_child(fi)
	c2.add_child(v2)
	p_set.add_child(c2)
	if is_android:
		var c3 := Card.new()
		var v3 := VBoxContainer.new()
		v3.add_theme_constant_override("separation", 12)
		set_name_edit = LineEdit.new()
		set_name_edit.text = my_name
		set_name_edit.max_length = 24
		set_name_edit.text_changed.connect(func(t: String):
			pref_name = t.strip_edges()
			_read_profile()
			_save_soon())
		v3.add_child(set_name_edit)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for i in 8:
			var av := Avatar.new(36)
			av.variant = i
			av.selected = i == my_mascot
			av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			av.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed:
					my_mascot = i
					_ui_me()
					_save_soon())
			set_pickers.append(av)
			row.add_child(av)
		v3.add_child(row)
		c3.add_child(v3)
		p_set.add_child(c3)
	p_set.add_child(_spacer())
	var ver := _lbl("v" + APP_VERSION, 13, C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_set.add_child(ver)


func _show(pg: String) -> void:
	page = pg
	p_home.visible = pg == "home"
	p_chat.visible = pg == "chat"
	p_set.visible = pg == "set"
	if nav != null:
		nav.visible = pg != "chat"
		nav.current = pg
		_layout()
	if pg == "home":
		cur = ""
		list_dirty = true
	elif pg == "set":
		set_dir_lbl.text = _dl_dir()


func _open(conv: String) -> void:
	cur = conv
	if conv != "all" and conv not in open_convs:
		open_convs.append(conv)
		_save_soon()
	unread.erase(conv)
	_show("chat")
	_ui_chat_head()
	chat_dirty = true
	stick = 3
	if not is_android:
		input.grab_focus()


func _ui_chat_head() -> void:
	if cur == "all":
		chat_name.text = "Général"
		chat_avatar.visible = false
		chat_icon.visible = true
	elif peers.has(cur):
		chat_name.text = str(peers[cur].name)
		chat_avatar.visible = true
		chat_icon.visible = false
		chat_avatar.variant = peers[cur].mascot
		chat_avatar.online = _is_online(peers[cur])
		chat_avatar.anim = "idle" if chat_avatar.online else "off"
	var other := false
	for k in unread:
		if k != cur and int(unread[k]) > 0:
			other = true
	chat_back.badge = other
	_render_dock()


## Mini-fenêtres : « Général » (coché, toujours présent) puis une pastille par conversation privée, avec croix rouge.
func _render_dock() -> void:
	if dock == null:
		return
	for c in dock.get_children():
		c.queue_free()
	_dock_chip("all", "Général", null, cur == "all")
	for id in open_convs.duplicate():
		if peers.has(id):
			_dock_chip(id, str(peers[id].name), peers[id], cur == id)
		else:
			open_convs.erase(id)
	var contacts := IconBtn.new("people", 44)
	contacts.tooltip_text = "Contacts"
	contacts.pressed.connect(func(): _show("home"))
	dock.add_child(contacts)


func _dock_chip(id: String, title: String, pr, active: bool) -> void:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_OK, 0.22) if active else C_CARD
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(h)
	if pr == null:
		var ok := IconBtn.new("check", 28)  # Général : validé par défaut
		ok.fill = C_OK
		ok.col = C_BG
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ok)
	else:
		var av := Avatar.new(30)
		av.variant = pr.mascot
		av.show_online = true
		av.online = _is_online(pr)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(av)
	var l := _lbl(title, 16)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if int(unread.get(id, 0)) > 0 and not active:
		h.add_child(_count(int(unread[id])))
	if pr != null:
		var x := IconBtn.new("close", 28)  # croix rouge : retire la mini-fenêtre
		x.fill = Color("ff6b6b")
		x.col = Color.WHITE
		x.tooltip_text = "Fermer"
		x.pressed.connect(func(): _close_conv(id))
		h.add_child(x)
	chip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and cur != id:
			_open(id))
	dock.add_child(chip)


func _close_conv(id: String) -> void:
	open_convs.erase(id)
	_save_soon()
	if cur == id:
		_open("all")
	else:
		_render_dock()


## Envoie dans le Général un message (ou un fichier) reçu/écrit en privé.
func _forward_to_general(m: Dictionary) -> void:
	if m.get("k", "") == "t":
		_send_text("all", str(m.text))
	elif m.get("k", "") == "f" and FileAccess.file_exists(str(m.get("path", ""))):
		_send_file("all", str(m.path))


func _hm(ts: float) -> String:
	var bias := int(Time.get_time_zone_from_system().bias) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(ts) + bias)
	var n := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias)
	var s := "%02d:%02d" % [d.hour, d.minute]
	if d.day != n.day or d.month != n.month:
		s = "%02d/%02d %s" % [d.day, d.month, s]
	return s


func _fsize(n: int) -> String:
	if n >= 1048576:
		return "%.1f Mo" % (n / 1048576.0)
	if n >= 1024:
		return "%d Ko" % (n / 1024)
	return "%d o" % n


func _render_chat() -> void:
	chat_dirty = false
	_ui_chat_head()
	for c in msg_box.get_children():
		c.queue_free()
	file_ui.clear()
	var arr: Array = history.get(cur, [])
	var maxw := maxf(180.0, msg_scroll.size.x * 0.78)
	var font := ThemeDB.fallback_font
	for m in arr.slice(maxi(0, arr.size() - 150)):
		var me: bool = m.get("me", false)
		var row := HBoxContainer.new()
		var bub := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(C_OK, 0.2) if me else C_CARD
		sb.set_corner_radius_all(18)
		sb.set_content_margin_all(11)
		bub.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		if not me and cur == "all" and peers.has(m.get("from", "")):
			v.add_child(_lbl(str(peers[m.from].name), 13, C_OK))
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 6)
		if m.get("k", "") == "t":
			var text := str(m.text)
			var w := 40.0
			for ln in text.split("\n"):
				w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
			var l := Label.new()
			l.text = text
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = minf(w + 4.0, maxw - 24.0)
			v.add_child(l)
			if m.get("st", "") == "q":
				var q := IconBtn.new("clock", 18)
				q.col = C_DIM
				q.mouse_filter = Control.MOUSE_FILTER_IGNORE
				foot.add_child(q)
		else:
			_file_body(v, foot, m, me, maxw)
		foot.add_child(_spacer())
		if cur != "all" and (m.get("k", "") == "t" or (m.get("k", "") == "f" and m.get("st", "") == "done")):
			var fw := IconBtn.new("send", 22)
			fw.col = C_DIM
			fw.tooltip_text = "Envoyer dans le Général"
			fw.pressed.connect(func():
				fw.col = C_OK
				_forward_to_general(m))
			foot.add_child(fw)
		foot.add_child(_lbl(_hm(float(m.ts)), 12, C_DIM))
		v.add_child(foot)
		bub.add_child(v)
		if me:
			row.add_child(_spacer())
		row.add_child(bub)
		if not me:
			row.add_child(_spacer())
		msg_box.add_child(row)


func _file_body(v: VBoxContainer, foot: HBoxContainer, m: Dictionary, me: bool, maxw: float) -> void:
	var st := str(m.get("st", ""))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var fi := IconBtn.new("file", 40)
	fi.col = C_OK
	fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fi)
	var col := VBoxContainer.new()
	var nl := _lbl(str(m.name), 16)
	nl.custom_minimum_size.x = minf(maxw - 150.0, 200.0)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nl)
	col.add_child(_lbl(_fsize(int(m.size)) + ((" · " + str(m.to)) if me and cur == "all" else ""), 13, C_DIM))
	top.add_child(col)
	v.add_child(top)
	var path := str(m.get("path", ""))
	var ext := str(m.name).get_extension().to_lower()
	if st == "done" and ext in ["png", "jpg", "jpeg", "webp", "bmp"] and path != "" and int(m.size) < 12000000:
		var tex := _thumb(path)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sz := tex.get_size()
			tr.custom_minimum_size = sz
			v.add_child(tr)
	if st == "send" or st == "recv":
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = float(m.get("prog", 0.0))
		bar.custom_minimum_size = Vector2(0, 8)
		v.add_child(bar)
		file_ui[m.id] = {"bar": bar, "msg": m}
	var ic: IconBtn = null
	match st:
		"offer":
			if me:
				ic = IconBtn.new("clock", 22)
				ic.col = C_DIM
			else:
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 10)
				var ok := IconBtn.new("check", 44)
				ok.fill = C_OK
				ok.col = C_BG
				ok.pressed.connect(func():
					if peers.has(m.get("pid", "")):
						_answer(peers[m.pid], m, true))
				var no := IconBtn.new("close", 44)
				no.col = C_BAD
				no.pressed.connect(func():
					if peers.has(m.get("pid", "")):
						_answer(peers[m.pid], m, false))
				hb.add_child(ok)
				hb.add_child(no)
				v.add_child(hb)
		"done":
			ic = IconBtn.new("check", 22)
			ic.col = C_OK
			if not me and not is_android and path != "" and not path.begins_with("user://"):
				var fo := IconBtn.new("folder", 32)
				fo.col = C_OK
				fo.pressed.connect(func(): OS.shell_show_in_file_manager(path))
				foot.add_child(fo)
		"bad", "fail", "refused":
			ic = IconBtn.new("close", 22)
			ic.col = C_BAD
	if ic != null:
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(ic)


func _thumb(path: String) -> Texture2D:
	if thumbs.has(path):
		return thumbs[path]
	var img := Image.load_from_file(path)
	var tex: Texture2D = null
	if img != null and not img.is_empty():
		var k := minf(1.0, 240.0 / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		tex = ImageTexture.create_from_image(img)
	thumbs[path] = tex
	return tex


func _process(delta: float) -> void:
	_net_tick(delta)
	profile_t -= delta
	if profile_t <= 0.0:
		profile_t = 2.0
		_read_profile()
		if is_android:
			_layout()
		list_dirty = true  # rafraîchit les états en ligne/hors ligne
	if save_t >= 0.0:
		save_t -= delta
		if save_t < 0.0:
			_save_all()
	if page == "home" and list_dirty and not _any_press():
		_refresh_home()
	elif page == "chat":
		if chat_dirty:
			_render_chat()
		for k in file_ui:
			(file_ui[k].bar as ProgressBar).value = float(file_ui[k].msg.get("prog", 0.0))
		if stick > 0:
			stick -= 1
			msg_scroll.scroll_vertical = int(msg_scroll.get_v_scroll_bar().max_value)
	if is_android and DisplayServer.virtual_keyboard_get_height() > 0:
		_layout()
	if test_role != "":
		_test_tick(delta)


func _any_press() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


# ------------------------------------------------------------------ Auto-test headless (CHAT_TEST=a|b)

func _test_fail(msg: String) -> void:
	print("TEST %s FAIL: %s" % [test_role.to_upper(), msg])
	get_tree().quit(1)


func _test_tick(delta: float) -> void:  # (contient un await : le test « c » est asynchrone)
	test_t += delta
	if test_t > 45.0:
		_test_fail("délai dépassé (état %d)" % test_state)
		return
	if test_quit_t >= 0.0:
		test_quit_t -= delta
		if test_quit_t < 0.0:
			print("TEST %s OK" % test_role.to_upper())
			get_tree().quit(0)
		return
	if test_role == "c":  # clic réel sur une carte de contact
		if test_state == 0 and test_t > 1.5:
			var cards: Array = []
			for cc in list_box.get_children():
				if cc is Card and cc.size.x > 10:
					cards.append(cc)
			for c in cards.slice(maxi(0, cards.size() - 1)):  # la DERNIÈRE carte = une personne (la première est le Général)
				if true:
					var pos: Vector2 = c.global_position + c.size / 2.0
					get_window().notification(Window.NOTIFICATION_WM_MOUSE_ENTER)  # en headless la souris n'est « dans la fenêtre » qu'ainsi
					var mv := InputEventMouseMotion.new()
					mv.position = pos
					mv.global_position = pos
					get_viewport().push_input(mv)
					await get_tree().process_frame
					var hov := get_viewport().gui_get_hovered_control()
					print("C: survol = ", hov.get_class() if hov != null else "null", " ", hov.name if hov != null else "", " card=", c.name, " vis=", c.is_visible_in_tree())
					for pressed in [true, false]:
						var ev := InputEventMouseButton.new()
						ev.button_index = MOUSE_BUTTON_LEFT
						ev.pressed = pressed
						ev.position = pos
						ev.global_position = pos
						get_viewport().push_input(ev)
					print("C: clic envoyé en ", pos)
					test_state = 1
					break
		elif test_state == 1 and test_t > 2.2:
			print("C: page=%s conv=%s" % [page, cur])
			if page == "chat" and cur != "" and cur != "all":
				test_quit_t = 0.2
			else:
				_test_fail("le clic sur un contact n'ouvre pas la conversation")
		return
	if test_role == "s" and test_state == 0 and test_t > 1.5:  # auto-test du contact « Moi » (bouclage local)
		test_state = 1
		_send_text(me_id, "self-hello")
		var ssrc := data_dir.path_join("src.bin")
		var sf := FileAccess.open(ssrc, FileAccess.WRITE)
		sf.store_buffer(Crypto.new().generate_random_bytes(3 * 1024 * 1024))
		sf.close()
		test_src_sha = FileAccess.get_sha256(ssrc)
		print("S: envoi à soi-même : texte + fichier 3 Mo sha=", test_src_sha)
		_send_file(me_id, ssrc)
	if test_role == "a" and test_state == 0:
		for id in peers:
			if peers[id].up and not peers[id].get("self", false):
				print("A: pair découvert et lié : ", peers[id].name)
				_send_text(id, "hello-from-A")
				var src := data_dir.path_join("src.bin")
				var f := FileAccess.open(src, FileAccess.WRITE)
				f.store_buffer(Crypto.new().generate_random_bytes(5 * 1024 * 1024))
				f.close()
				test_src_sha = FileAccess.get_sha256(src)
				print("A: envoi fichier 5 Mo sha=", test_src_sha)
				_send_file(id, src)
				test_state = 1
				_open(id)


func _test_hook(ev: String, data) -> void:
	if test_role == "":
		return
	if test_role == "s":
		if ev == "text" and str(data) == "self-hello":
			print("S: message bouclé reçu")
			test_state |= 2
		elif ev == "file":
			var sm: Dictionary = data
			var ssha := FileAccess.get_sha256(str(sm.path))
			print("S: fichier bouclé st=%s taille=%d sha=%s" % [sm.st, int(sm.size), ssha])
			if sm.st != "done" or ssha != test_src_sha:
				_test_fail("fichier bouclé corrompu")
				return
			test_state |= 4
		if (test_state & 6) == 6:
			test_quit_t = 1.0
		return
	if test_role == "b":
		if ev == "text" and data == "hello-from-A":
			print("B: message reçu")
			_show("set")
			_show("home")
			for id in peers:
				if not peers[id].get("self", false):
					_open(id)
			for id in peers:
				if not peers[id].get("self", false):
					_send_text(id, "hello-from-B")
		elif ev == "file":
			var m: Dictionary = data
			var sha := FileAccess.get_sha256(str(m.path))
			print("B: fichier reçu st=%s taille=%d sha=%s" % [m.st, int(m.size), sha])
			if m.st != "done":
				_test_fail("fichier corrompu")
				return
			for id in peers:
				if not peers[id].get("self", false):
					_send_text(id, "file-ok:" + sha)
			test_quit_t = 2.0
	elif test_role == "a":
		if ev == "text" and str(data) == "hello-from-B":
			print("A: réponse reçue")
			test_state |= 2
		elif ev == "text" and str(data).begins_with("file-ok:"):
			if str(data).substr(8) != test_src_sha:
				_test_fail("sha différent côté B")
				return
			print("A: sha identique côté B")
			test_state |= 4
		elif ev == "ack" and data.st != "done":
			_test_fail("accusé fichier négatif")
			return
		if (test_state & 6) == 6:
			test_quit_t = 1.0
