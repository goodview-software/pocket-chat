extends Window
## HUD overlay pixel art (PC) : bandeau en haut à droite de l'écran avec les personnages, dépliable pour ouvrir un chat.
## Fenêtre sans bordure, transparente, toujours au-dessus, sans prise de focus. Bulle de notification à l'arrivée d'un message.
const KPx := preload("res://kit/ui/px.gd")
const SHEET := preload("res://mascot/goody.png")
const BODIES := [Color("4de1b4"), Color("ff8fb1"), Color("6aa8ff"), Color("ffa24d"), Color("b58bff"),
		Color("ffd84d"), Color("ff6b6b"), Color("c9d1da")]
const MARGIN := 12
const BOX := 44        # case d'un personnage dans le bandeau
const ROW_H := 46
const PANEL_W := 280
const MAX_STRIP := 4
const TOAST_SECS := 6.0

var main: Control
var cv: Control
var expanded := false
var toast := {}        # {conv, title, text, mascot, t}
var hits: Array = []   # [Rect2, String] : "toggle", "open" ou id de conversation
var hover := -1
var t := 0.0
var entries: Array = []
var font: Font
var _sig := ""


func setup(m: Control) -> void:
	main = m
	font = m.get_theme_default_font()
	title = "Pocket Chat HUD"
	borderless = true
	always_on_top = true
	transparent = true
	transparent_bg = true
	unfocusable = true
	transient = false
	force_native = true
	exclusive = false
	wrap_controls = false
	cv = Control.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cv.draw.connect(_draw_ui)
	cv.gui_input.connect(_input_ui)
	cv.mouse_exited.connect(func(): hover = -1)
	add_child(cv)
	_collect()
	_relayout()
	visible = true


## Appelé par l'app à chaque message entrant.
func notify(conv: String, who: String, text: String, mascot: int) -> void:
	toast = {"conv": conv, "title": who, "text": text, "mascot": mascot, "t": TOAST_SECS}
	_relayout()


func _process(d: float) -> void:
	t += d
	if not toast.is_empty():
		toast.t = float(toast.t) - d
		if float(toast.t) <= 0.0:
			toast = {}
			_relayout()
	_collect()
	cv.queue_redraw()


## Liste des entrées affichées : Général puis contacts en ligne ou avec des messages non lus.
func _collect() -> void:
	var l: Array = [{"id": "all", "name": "Général", "mascot": -1, "unread": int(main.unread.get("all", 0))}]
	var ids: Array = []
	for id in main.peers:
		var pr: Dictionary = main.peers[id]
		if pr.get("self", false):
			continue
		var u := int(main.unread.get(id, 0))
		if main._is_online(pr) or u > 0:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(main.unread.get(a, 0)) > int(main.unread.get(b, 0)))
	for id in ids:
		l.append({"id": id, "name": str(main.peers[id].name), "mascot": int(main.peers[id].mascot), "unread": int(main.unread.get(id, 0))})
	entries = l
	var sig := str(l.map(func(e): return "%s%d" % [e.id, e.unread])) + str(expanded)
	if sig != _sig:
		_sig = sig
		_relayout()


func _strip_w() -> int:
	var n := mini(entries.size(), MAX_STRIP + 1)
	var extra := 1 if entries.size() > MAX_STRIP + 1 else 0
	return 16 + n * (BOX + 6) + extra * 30 + 34


func _relayout() -> void:
	if main == null:
		return
	var w := PANEL_W if (expanded or not toast.is_empty()) else _strip_w()
	w = maxi(w, _strip_w())
	var h := 60
	if expanded:
		h += 8 + 14 + entries.size() * ROW_H + ROW_H
	if not toast.is_empty():
		h += 8 + 64
	var scr := DisplayServer.window_get_current_screen(0)
	var r := DisplayServer.screen_get_usable_rect(scr)
	size = Vector2i(w, h)
	position = Vector2i(r.end.x - w - MARGIN, r.position.y + MARGIN)
	if cv != null:
		cv.queue_redraw()


# ------------------------------------------------------------------ Dessin

func _txt(p: Vector2, s: String, sz: int, col: Color, w := -1.0) -> void:
	font.draw_string(cv, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, sz, col)


func _avatar(r: Rect2, mascot: int, anim_row := 0) -> void:
	if mascot < 0:  # salon commun : bulle de dialogue
		KPx.panel(cv, r, Color("232a34"), Color("0b0e12"), false, 1)
		var c := r.get_center()
		cv.draw_rect(Rect2(c + Vector2(-10, -9), Vector2(20, 14)), Color("4de1b4"))
		cv.draw_rect(Rect2(c + Vector2(-6, 5), Vector2(6, 5)), Color("4de1b4"))
		for i in 3:
			cv.draw_rect(Rect2(c + Vector2(-7 + i * 6, -4), Vector2(3, 3)), Color("0b0e12"))
		return
	var v := clampi(mascot, 0, 7)
	KPx.panel(cv, r, (BODIES[v] as Color).darkened(0.62), Color("0b0e12"), false, 1)
	var c2 := r.get_center()
	cv.draw_texture_rect_region(SHEET, Rect2((c2 - Vector2(16, 16)).round(), Vector2(32, 32)),
			Rect2((int(t * 3.0) % 4) * 32, (anim_row + v * 5) * 32, 32, 32))


func _badge(r: Rect2, n: int) -> void:
	if n <= 0:
		return
	var s := str(mini(n, 99))
	var bw := 8.0 + 8.0 * s.length()
	var b := Rect2(r.end.x - bw + 4, r.position.y - 4, bw, 16)
	cv.draw_rect(b.grow(2), Color.BLACK)
	cv.draw_rect(b, Color("ff6b6b"))
	_txt(Vector2(b.position.x + 4, b.position.y + 13), s, 12, Color.WHITE)


func _draw_ui() -> void:
	hits.clear()
	var W := float(size.x)
	# --- bandeau
	var strip := Rect2(0, 0, W, 56)
	KPx.panel(cv, strip, Color("171b22"), Color("0b0e12"), true, 2)
	var x := 12.0
	var shown := mini(entries.size(), MAX_STRIP + 1)
	for i in shown:
		var e: Dictionary = entries[i]
		var r := Rect2(x, 6, BOX - 4, BOX - 4)
		_avatar(r, int(e.mascot), 0)
		_badge(r, int(e.unread))
		hits.append([Rect2(x, 4, BOX, 48), str(e.id)])
		x += BOX + 6
	if entries.size() > shown:
		_txt(Vector2(x + 2, 34), "+%d" % (entries.size() - shown), 16, Color("8892a0"))
		x += 30
	var tg := Rect2(W - 34, 8, 26, 40)
	cv.draw_rect(tg, Color("232a34") if hover != hits.size() else Color("2f3947"))
	var cc := tg.get_center()
	var dir := -1.0 if expanded else 1.0  # flèche vers le bas / le haut
	for k in 4:
		cv.draw_rect(Rect2(cc.x - 8 + k * 2, cc.y - 4 * dir + k * 2 * dir - 1, 16 - k * 4, 3), Color("4de1b4"))
	hits.append([Rect2(W - 38, 0, 38, 56), "toggle"])
	var y := 64.0
	# --- liste dépliée
	if expanded:
		var ph := 14.0 + entries.size() * ROW_H + ROW_H
		KPx.panel(cv, Rect2(0, y, W, ph), Color("171b22"), Color("0b0e12"), true, 2)
		var ry := y + 10.0
		for e in entries:
			var rr := Rect2(8, ry, W - 16, ROW_H - 2)
			if hover == hits.size():
				cv.draw_rect(rr, Color("232a34"))
			_avatar(Rect2(14, ry + 3, 38, 38), int(e.mascot), 0)
			_txt(Vector2(62, ry + 28), str(e.name), 17, Color("e8ecf1"), W - 62 - 40)
			_badge(Rect2(W - 40, ry + 12, 20, 20), int(e.unread))
			hits.append([rr, str(e.id)])
			ry += ROW_H
		var orr := Rect2(8, ry + 2, W - 16, ROW_H - 6)
		cv.draw_rect(orr, Color("4de1b4") if hover == hits.size() else Color("2d8c70"))
		_txt(Vector2(orr.position.x + 14, orr.position.y + 26), "OUVRIR POCKET CHAT", 15, Color("0b0e12"))
		hits.append([orr, "open"])
		y += ph + 8.0
	# --- bulle de notification
	if not toast.is_empty():
		var tr := Rect2(0, y, W, 64)
		KPx.panel(cv, tr, Color("232a34"), Color("4de1b4"), true, 2)
		_avatar(Rect2(8, y + 10, 44, 44), int(toast.mascot), 1)
		_txt(Vector2(62, y + 26), str(toast.title), 15, Color("4de1b4"), W - 72)
		_txt(Vector2(62, y + 48), str(toast.text), 15, Color("e8ecf1"), W - 72)
		hits.append([tr, "toast"])


# ------------------------------------------------------------------ Entrées souris

func _input_ui(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := -1
		for i in hits.size():
			if (hits[i][0] as Rect2).has_point(e.position):
				h = i
				break
		if h != hover:
			hover = h
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for hh in hits:
			if (hh[0] as Rect2).has_point(e.position):
				_act(str(hh[1]))
				return


func _act(id: String) -> void:
	match id:
		"toggle":
			expanded = not expanded
			_relayout()
		"open":
			main.hud_open("")
		"toast":
			var c := str(toast.get("conv", ""))
			toast = {}
			_relayout()
			main.hud_open(c)
		_:
			main.hud_open(id)
