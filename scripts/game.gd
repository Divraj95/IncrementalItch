extends Node2D

const World = preload("res://scripts/world.gd")
const ORIGIN = Vector2(48, 176)
const CELL = 40
const GOLD = Color("edce8a")
const WHITE = Color("e8eee0")
const MUTED = Color("93aca8")
var g = World.new()
var chapters: Array = []
var chapter = 0
var unlocked = 0
var records: Dictionary = {}
var map_open = true
var hint_count = 0
var muted = false
var clock = 0.0
var cooldown = 0.0
var render_pos = Vector2.ZERO
var particles: Array = []
var font = ThemeDB.fallback_font
var walk_texture = preload("res://assets/creatures_ElfWalk.png")
var idle_texture = preload("res://assets/creatures_ElfIdle.png")
var props = preload("res://assets/overworld_Minifantasy_TinyOverworldForgottenPlainsProps.png")
var voices: Array = []
var voice_index = 0
var tones: Dictionary = {}

func _ready():
	for i in range(1, 6):
		var path = "res://levels/%02d.json" % i
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary: chapters.append(parsed)
	if chapters.is_empty():
		push_error("No chapters found"); return
	var save = ConfigFile.new()
	if save.load("user://forest_v2.cfg") == OK:
		unlocked = clampi(int(save.get_value("journey", "unlocked", 0)), 0, chapters.size() - 1)
		records = save.get_value("journey", "records", {})
		muted = save.get_value("journey", "muted", false)
	for i in 4:
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -22
		add_child(voice); voices.append(voice)
	load_chapter(unlocked)

func load_chapter(index: int):
	chapter = clampi(index, 0, chapters.size() - 1)
	g.setup(chapters[chapter])
	render_pos = Vector2(g.player) * CELL
	hint_count = 0; particles.clear(); cooldown = 0.2
	queue_redraw()

func save_progress():
	var save = ConfigFile.new()
	save.set_value("journey", "unlocked", unlocked)
	save.set_value("journey", "records", records)
	save.set_value("journey", "muted", muted)
	save.save("user://forest_v2.cfg")

func start_chapter(index: int):
	if index > unlocked: return
	load_chapter(index); map_open = false; chime("start")

func finish_chapter():
	var key = str(chapter)
	var old = records.get(key, {})
	records[key] = {"moves": mini(g.moves, int(old.get("moves", 99999))), "seeds": maxi(g.collected.size(), int(old.get("seeds", 0)))}
	unlocked = mini(chapters.size() - 1, maxi(unlocked, chapter + 1))
	save_progress()
	burst(ORIGIN + Vector2(g.player) * CELL + Vector2(20, 20), GOLD, 34)

func respond(success: bool):
	if not success:
		if g.last_event == "blocked": chime("blocked")
		return
	chime(g.last_event)
	if g.last_event in ["take", "place", "seed", "heart"]:
		burst(ORIGIN + Vector2(g.player + g.facing) * CELL + Vector2(20, 20), GOLD if g.last_event in ["seed", "heart"] else Color("99c383"), 8)
	if g.complete: finish_chapter()

func take_step(direction: Vector2i):
	respond(g.move_player(direction)); cooldown = 0.14

func show_hint():
	hint_count = mini(hint_count + 1, g.data.get("hints", []).size())
	chime("hint")

func next_chapter():
	if chapter < chapters.size() - 1: start_chapter(chapter + 1)
	else: map_open = true

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			muted = not muted; save_progress(); return
		if event.keycode == KEY_ESCAPE:
			map_open = not map_open; cooldown = 0.2; return
		if map_open:
			if event.keycode in [KEY_ENTER, KEY_SPACE]: start_chapter(unlocked)
			return
		if event.keycode == KEY_Z:
			if g.undo(): render_pos = Vector2(g.player) * CELL; chime("undo")
			return
		if g.complete:
			if event.keycode in [KEY_ENTER, KEY_SPACE]: next_chapter()
			if event.keycode == KEY_R: start_chapter(chapter)
			return
		match event.keycode:
			KEY_E, KEY_SPACE: respond(g.interact(g.player + g.facing))
			KEY_R: start_chapter(chapter)
			KEY_H: show_hint()
			KEY_1: g.selected = 0
			KEY_2: g.selected = 1
			KEY_3: g.selected = 2
			KEY_TAB: g.selected = (g.selected + 1) % maxi(1, g.bag.size())
	if event is InputEventMouseButton and event.pressed:
		var m = get_global_mouse_position()
		if map_open:
			for i in chapters.size():
				if Rect2(70 + i * 204, 306, 192, 210).has_point(m): start_chapter(i)
			if Rect2(426, 570, 300, 48).has_point(m): start_chapter(unlocked)
			return
		if g.complete:
			if Rect2(405, 445, 340, 48).has_point(m): next_chapter()
			return
		for i in 3:
			if Rect2(840 + i * 88, 318, 76, 70).has_point(m): g.selected = i; return
		if Rect2(840, 464, 260, 34).has_point(m):
			if g.undo(): render_pos = Vector2(g.player) * CELL; chime("undo")
			return
		if Rect2(840, 504, 260, 34).has_point(m): show_hint(); return
		if Rect2(840, 544, 260, 34).has_point(m): start_chapter(chapter); return
		if Rect2(840, 584, 260, 34).has_point(m): map_open = true; return
		var p = Vector2i(((m - ORIGIN) / CELL).floor())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var d = p - g.player
			if d in g.DIRS: take_step(d)
		elif event.button_index == MOUSE_BUTTON_LEFT: respond(g.interact(p))

func _process(delta):
	clock += delta; cooldown -= delta
	if not map_open and not g.complete and cooldown <= 0:
		var d = Vector2i.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d = Vector2i.UP
		elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): d = Vector2i.DOWN
		elif Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): d = Vector2i.LEFT
		elif Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): d = Vector2i.RIGHT
		if d != Vector2i.ZERO: take_step(d)
	render_pos = render_pos.move_toward(Vector2(g.player) * CELL, delta * 390)
	for p in particles:
		p.life -= delta; p.pos += p.velocity * delta; p.velocity.y += delta * 75
	particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func burst(at: Vector2, color: Color, count: int):
	for i in count:
		particles.append({"pos": at, "velocity": Vector2.from_angle(randf() * TAU) * randf_range(20, 90), "life": randf_range(0.3, 0.8), "color": color})

func chime(event: String):
	if muted or event == "step" or voices.is_empty(): return
	var frequencies = {"take": 440.0, "place": 330.0, "seed": 880.0, "heart": 660.0, "complete": 523.25, "undo": 260.0, "start": 392.0, "hint": 587.0, "blocked": 130.0}
	if not frequencies.has(event): return
	if not tones.has(event):
		var length = 0.45 if event in ["complete", "heart"] else 0.1
		var bytes = PackedByteArray(); bytes.resize(int(22050 * length))
		for i in bytes.size():
			var t = float(i) / 22050.0
			var envelope = sin(minf(1, t / 0.008) * PI / 2) * pow(1 - t / length, 2)
			var wave = sin(t * frequencies[event] * TAU)
			if event in ["complete", "heart"]: wave = (wave + sin(t * frequencies[event] * 1.25 * TAU) + sin(t * frequencies[event] * 1.5 * TAU)) / 3
			bytes[i] = int(128 + wave * envelope * 90)
		var sound = AudioStreamWAV.new(); sound.format = AudioStreamWAV.FORMAT_8_BITS; sound.mix_rate = 22050; sound.data = bytes
		tones[event] = sound
	voices[voice_index].stream = tones[event]; voices[voice_index].play(); voice_index = (voice_index + 1) % voices.size()

func label(at: Vector2, value: String, size: int = 16, color: Color = WHITE):
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(at: Vector2, value: String, size: int, color: Color):
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	label(at - Vector2(width / 2, 0), value, size, color)

func wrapped(at: Vector2, value: String, width: float, size: int, color: Color = WHITE):
	var line = ""; var y = at.y
	for word in value.split(" "):
		var next = (line + " " + word).strip_edges()
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			label(Vector2(at.x, y), line, size, color); y += size + 7; line = word
		else: line = next
	label(Vector2(at.x, y), line, size, color)

func box(rect: Rect2, color: Color, border: Color = Color("30464a"), radius: int = 7):
	var style = StyleBoxFlat.new(); style.bg_color = color; style.border_color = border
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func button(rect: Rect2, value: String, primary: bool = false):
	var hover = rect.has_point(get_global_mouse_position())
	box(rect, Color("465940") if primary and hover else Color("324736") if primary else Color("2d4447") if hover else Color("1b3036"), GOLD if primary else Color("3a5458"))
	label(rect.position + Vector2(14, rect.size.y / 2 + 5), value, 15, GOLD if primary else WHITE)

func tile_color(kind: String) -> Color:
	return {"root": Color("405b43"), "grass": Color("83a854"), "water": Color("466e91"), "stone": Color("a4a390")}.get(kind, Color("152930"))

func draw_seed(at: Vector2):
	draw_circle(at, 5, GOLD)
	draw_line(at + Vector2(0, 4), at + Vector2(0, 10), GOLD, 2)
	draw_line(at + Vector2(0, 6), at + Vector2(5, 2), GOLD, 2)

func _draw():
	if chapters.is_empty(): return
	label(Vector2(48, 35), "A SMALL ACT OF REBELLION", 12, GOLD)
	label(Vector2(46, 80), "Steal the Ground", 40)
	label(Vector2(48, 111), g.data.get("subtitle", ""), 17, MUTED)
	label(Vector2(888, 37), "FIVE CHAPTERS · ONE FOREST", 11, MUTED)
	label(Vector2(940, 78), "M  " + ("Sound off" if muted else "Sound on"), 13, MUTED)
	for i in chapters.size():
		var at = Vector2(54 + i * 151, 144)
		draw_circle(at, 4, GOLD if i <= unlocked else Color("30464a"))
		label(at + Vector2(12, 4), "%02d" % (i + 1) + ("  /  HERE" if i == chapter else "  /  RESTORED" if records.has(str(i)) else ""), 11, GOLD if i == chapter else MUTED)
	box(Rect2(44, 172, 768, 448), Color("0d1d25"))
	draw_board(); draw_sidebar()
	wrapped(Vector2(48, 650), g.notice, 1055, 17, GOLD)
	if hint_count > 0: wrapped(Vector2(48, 705), "HINT %d  /  " % hint_count + g.data.hints[hint_count - 1], 1055, 14, MUTED)
	else: label(Vector2(48, 705), "Bright dotted tiles can move. Rooted paths stay. Need a nudge? Press H.", 14, MUTED)
	label(Vector2(48, 750), "ADVENTURE 02  ·  progress saves in this browser", 11, Color("728d8d"))
	label(Vector2(780, 750), "Minifantasy art © Krishna Palacio", 12, MUTED)
	if map_open: draw_map()
	elif g.complete: draw_completion()

func draw_board():
	for y in 11:
		for x in 19:
			var p = Vector2i(x, y); var at = ORIGIN + Vector2(p) * CELL
			var kind = g.tiles.get(p, "void")
			if kind != "void":
				draw_rect(Rect2(at + Vector2(0, 4), Vector2(40, 40)), Color("263e32"))
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(38, 37)), tile_color(kind))
				if kind in ["root", "grass"]:
					for j in 4:
						var dot = Vector2(6 + (x * 7 + j * 11) % 29, 6 + (y * 13 + j * 7) % 26)
						draw_rect(Rect2(at + dot, Vector2(2, 3)), Color("78965a") if kind == "root" else Color("a9c577"))
				elif kind == "water":
					for j in 3:
						var wave = sin(clock * 2 + j + x) * 3
						draw_line(at + Vector2(6 + wave, 9 + j * 10), at + Vector2(24 + wave, 9 + j * 10), Color("97c9d0"), 2)
				elif kind == "stone":
					draw_rect(Rect2(at + Vector2(7, 8), Vector2(26, 23)), Color("d0ccb5"), false, 2)
					draw_line(at + Vector2(12, 12), at + Vector2(27, 26), Color("7e887d"), 1)
				if not g.rooted.has(p):
					for j in range(6, 35, 9): draw_rect(Rect2(at + Vector2(j, 3), Vector2(3, 1)), Color("e0e5ad"))
				else: draw_line(at + Vector2(4, 36), at + Vector2(36, 36), Color("2d4537"), 2)
			elif p in g.trees: draw_rect(Rect2(at, Vector2(40, 40)), Color("304535"))
			elif (x + y) % 3 == 0: draw_circle(at + Vector2(20, 22 + sin(clock + x) * 2), 1, Color("30424c"))
	for p in g.trees:
		draw_texture_rect_region(props, Rect2(ORIGIN + Vector2(p) * CELL + Vector2(2, -10), Vector2(36, 48)), Rect2(0, 56, 12, 16))
	for p in g.water_sockets:
		var at = ORIGIN + Vector2(p) * CELL
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(34, 34)), Color("8bcada"), false, 2)
		if not g.tiles.has(p): centered(at + Vector2(20, 26), "~", 24, Color("8bcada"))
	for p in g.stone_sockets:
		var at = ORIGIN + Vector2(p) * CELL
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(34, 34)), GOLD, false, 2)
		if not g.tiles.has(p): centered(at + Vector2(20, 27), "◆", 20, GOLD)
	for p in g.gates:
		var at = ORIGIN + Vector2(p) * CELL
		if g.powered():
			draw_rect(Rect2(at + Vector2(0, 4), Vector2(40, 32)), Color("b2a477"))
			for j in 4: draw_line(at + Vector2(2, 6 + j * 8), at + Vector2(38, 6 + j * 8), Color("766c4b"), 2)
		else:
			draw_rect(Rect2(at + Vector2(2, 6), Vector2(36, 28)), Color("3b4342"))
			for j in 3: draw_line(at + Vector2(8 + j * 12, 5), at + Vector2(8 + j * 12, 33), Color("b59464"), 3)
		var wheel = at + Vector2(20, -7)
		draw_circle(wheel, 9, Color("bda676"), false, 2)
		for j in 4:
			var ray = Vector2.from_angle(j * PI / 2 + (clock if g.powered() else 0)) * 8
			draw_line(wheel, wheel + ray, Color("bda676"), 2)
	var home_at = ORIGIN + Vector2(g.home) * CELL + Vector2(20, 20)
	draw_circle(home_at, 15, Color("b9ce88"), false, 2)
	centered(home_at + Vector2(0, (font.get_ascent(19) - font.get_descent(19)) / 2), "H", 19, Color("f4e8ba"))
	if g.exit_cell.x >= 0:
		var at = ORIGIN + Vector2(g.exit_cell) * CELL
		draw_arc(at + Vector2(20, 19), 14, 0, TAU, 24, GOLD if g.powered() else MUTED, 2)
		centered(at + Vector2(20, 25), "→", 22, GOLD)
	if g.heart.x >= 0 and not g.carrying:
		var at = ORIGIN + Vector2(g.heart) * CELL + Vector2(20, 17 + sin(clock * 3) * 2)
		draw_circle(at, 20, Color(0.9, 0.75, 0.35, 0.12))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, 0), at + Vector2(0, 12), at + Vector2(-8, 0)]), GOLD)
	for p in g.seeds:
		if p not in g.collected: draw_seed(ORIGIN + Vector2(p) * CELL + Vector2(20, 15 + sin(clock * 2 + p.x) * 2))
	var pos = ORIGIN + render_pos
	draw_set_transform(pos + Vector2(20, 30), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.3)); draw_set_transform(Vector2.ZERO)
	var moving = render_pos.distance_to(Vector2(g.player) * CELL) > 1
	var row = 0
	if g.facing == Vector2i.LEFT: row = 1
	elif g.facing == Vector2i.RIGHT: row = 2
	elif g.facing == Vector2i.UP: row = 3
	var frame = int(clock * (10 if moving else 5)) % (4 if moving else 16)
	draw_texture_rect_region(walk_texture if moving else idle_texture, Rect2(pos + Vector2(-12, -8), Vector2(64, 64)), Rect2(frame * 32, row * 32, 32, 32))
	if g.carrying: draw_circle(pos + Vector2(30, 19), 5, GOLD)
	var hovered = Vector2i(((get_global_mouse_position() - ORIGIN) / CELL).floor())
	var d = hovered - g.player
	var target = hovered if d in g.DIRS else g.player + g.facing
	if not g.complete and not map_open and g.inside(target): draw_rect(Rect2(ORIGIN + Vector2(target) * CELL + Vector2(1, 1), Vector2(38, 38)), GOLD, false, 2)
	for p in particles: draw_circle(p.pos, 2, Color(p.color, clampf(p.life * 2, 0, 1)))

func draw_sidebar():
	box(Rect2(828, 172, 284, 448), Color("13272c"))
	label(Vector2(846, 200), "CHAPTER %02d / %02d" % [chapter + 1, chapters.size()], 12, GOLD)
	wrapped(Vector2(846, 232), g.data.title, 246, 21)
	wrapped(Vector2(846, 272), g.data.objective if not g.carrying else "Carry the heart home." if g.data.goal_kind == "heart_return" else "Keep the heart safe. Reach the trail.", 245, 14, MUTED)
	for i in 3:
		var r = Rect2(840 + i * 88, 318, 76, 70)
		box(r, Color("0d2027"), GOLD if g.selected == i else Color("354d50"))
		label(r.position + Vector2(7, 15), str(i + 1), 11, MUTED)
		if i < g.bag.size():
			draw_rect(Rect2(r.position + Vector2(23, 17), Vector2(30, 25)), tile_color(g.bag[i]))
			centered(r.position + Vector2(38, 59), g.bag[i].capitalize(), 12, WHITE)
		elif g.carrying and i == 2:
			draw_circle(r.position + Vector2(38, 29), 9, GOLD)
			centered(r.position + Vector2(38, 59), "Heart", 12, GOLD)
		else: centered(r.position + Vector2(38, 46), "empty", 12, MUTED)
	label(Vector2(846, 412), "WASD / Arrows   Walk", 14)
	label(Vector2(846, 433), "Click / E   Take or place beside you", 13)
	label(Vector2(846, 453), "1–3 / Tab   Select terrain", 13, MUTED)
	button(Rect2(840, 464, 260, 34), "Z   Undo last choice")
	button(Rect2(840, 504, 260, 34), "H   A little hint  (%d/3)" % hint_count)
	button(Rect2(840, 544, 260, 34), "R   Restart this chapter")
	button(Rect2(840, 584, 260, 34), "Esc   Journey map")
	var total = g.water_sockets.size() + g.stone_sockets.size()
	var filled = 0
	for p in g.water_sockets:
		if g.tiles.get(p) == "water": filled += 1
	for p in g.stone_sockets:
		if g.tiles.get(p) == "stone": filled += 1
	label(Vector2(48, 676), "%d choices  ·  %d/%d wild seeds" % [g.moves, g.collected.size(), g.seeds.size()] + ("  ·  %d/%d sockets filled" % [filled, total] if total > 0 else ""), 13, MUTED)

func draw_map():
	draw_rect(Rect2(0, 0, 1152, 768), Color(0.025, 0.06, 0.075, 0.96))
	centered(Vector2(576, 100), "Steal the Ground", 46, WHITE)
	centered(Vector2(576, 135), "A five-chapter journey about borrowing, returning, and finding a way.", 17, MUTED)
	wrapped(Vector2(180, 190), "The machines took the forest heart and broke the paths behind them. You are small. Your pockets are smaller. Carry the earth itself to bring the forest back.", 795, 19, WHITE)
	for i in chapters.size():
		var rect = Rect2(70 + i * 204, 306, 192, 210)
		var locked = i > unlocked
		box(rect, Color("243d34") if records.has(str(i)) else Color("142b32"), GOLD if i == unlocked else Color("30464a"))
		label(rect.position + Vector2(16, 32), "CHAPTER %02d" % (i + 1), 12, MUTED if locked else GOLD)
		wrapped(rect.position + Vector2(16, 69), chapters[i].title, 160, 21, MUTED if locked else WHITE)
		wrapped(rect.position + Vector2(16, 130), chapters[i].subtitle, 157, 13, MUTED)
		label(rect.position + Vector2(16, 192), "LOCKED" if locked else "%d/2 SEEDS · REPLAY" % int(records[str(i)].seeds) if records.has(str(i)) else "ENTER THE FOREST →", 11, MUTED if locked else GOLD)
	button(Rect2(426, 570, 300, 48), "Enter   Continue your journey", true)
	centered(Vector2(576, 658), "No timer. No lives. Undo freely. Optional wild seeds reward the curious.", 15, MUTED)
	centered(Vector2(576, 704), "Minifantasy artwork by Krishna Palacio · ADVENTURE 02", 12, MUTED)

func draw_completion():
	draw_rect(Rect2(0, 0, 1152, 768), Color(0.025, 0.06, 0.075, 0.75))
	box(Rect2(262, 234, 628, 310), Color("17312f"), GOLD)
	var ending = chapter == chapters.size() - 1
	centered(Vector2(576, 282), "THE FOREST REMEMBERS" if ending else "CHAPTER RESTORED", 13, GOLD)
	centered(Vector2(576, 330), "A little world, made whole." if ending else "A way forward.", 30, WHITE)
	centered(Vector2(576, 373), "The heart is home. The paths you borrowed bloom again." if ending else g.data.title + " is behind you.", 17, WHITE)
	centered(Vector2(576, 412), "%d choices · %d of %d wild seeds rescued" % [g.moves, g.collected.size(), g.seeds.size()], 15, MUTED)
	button(Rect2(405, 445, 340, 48), "Enter   Return to the journey map" if ending else "Enter   Follow the next trail", true)
	centered(Vector2(576, 523), "Z to undo · R to replay · Esc for chapters", 13, MUTED)
