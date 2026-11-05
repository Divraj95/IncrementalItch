extends Node2D

const World = preload("res://scripts/world.gd")
const ORIGIN = Vector2(196, 100)
const CELL = 40
const MOVE_BUTTONS = [Rect2(268, 558, 58, 58), Rect2(208, 620, 58, 58), Rect2(328, 620, 58, 58), Rect2(268, 682, 58, 58)]
const MOVE_DIRECTIONS = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
const UNDO_BUTTON = Rect2(820, 604, 64, 64)
const RESTART_BUTTON = Rect2(900, 604, 64, 64)
const GOLD = Color("edce8a")
const WHITE = Color("e8eee0")
const MUTED = Color("93aca8")
var g = World.new()
var chapters: Array = []
var playing = false
var transition_time = -1.0
var chapter = 0
var unlocked = 0
var records: Dictionary = {}
var hint_count = 0
var muted = false
var clock = 0.0
var cooldown = 0.0
var queued_direction = Vector2i.ZERO
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
		muted = save.get_value("journey", "muted", false)
	for i in 4:
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -22
		add_child(voice); voices.append(voice)
	load_chapter(0)

func load_chapter(index: int):
	chapter = clampi(index, 0, chapters.size() - 1)
	g.setup(chapters[chapter])
	render_pos = Vector2(g.player) * CELL
	hint_count = 0; particles.clear(); cooldown = 0.2; queued_direction = Vector2i.ZERO
	queue_redraw()

func save_progress():
	var save = ConfigFile.new()
	save.set_value("journey", "unlocked", unlocked)
	save.set_value("journey", "records", records)
	save.set_value("journey", "muted", muted)
	save.save("user://forest_v2.cfg")

func start_chapter(index: int):
	playing = true
	transition_time = -1.0
	if index > unlocked: return
	load_chapter(index); chime("start")

func finish_chapter():
	if chapter < chapters.size() - 1: transition_time = 1.0
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
	else:
		records.clear(); unlocked = 0; start_chapter(0)

func _unhandled_input(event):
	if not playing:
		if (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Rect2(456, 350, 240, 64).has_point(get_global_mouse_position())):
			start_chapter(0)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			muted = not muted; save_progress(); return
		if event.keycode == KEY_Z:
			if g.undo(): render_pos = Vector2(g.player) * CELL; chime("undo")
			return
		if g.complete:
			if event.keycode in [KEY_ENTER, KEY_SPACE]: next_chapter()
			if event.keycode == KEY_R:
				if chapter == chapters.size() - 1: next_chapter()
				else: start_chapter(chapter)
			return
		match event.keycode:
			KEY_W, KEY_UP: queued_direction = Vector2i.UP
			KEY_S, KEY_DOWN: queued_direction = Vector2i.DOWN
			KEY_A, KEY_LEFT: queued_direction = Vector2i.LEFT
			KEY_D, KEY_RIGHT: queued_direction = Vector2i.RIGHT
			KEY_E, KEY_SPACE: respond(g.interact(g.player + g.facing))
			KEY_R: start_chapter(chapter)
			KEY_H: show_hint()
			KEY_1: g.selected = 0
			KEY_2: g.selected = 1
			KEY_3: g.selected = 2
			KEY_TAB: g.selected = (g.selected + 1) % maxi(1, g.bag.size())
	if event is InputEventMouseButton and event.pressed:
		var m = get_global_mouse_position()
		if g.complete:
			if Rect2(456, 418, 240, 54).has_point(m): next_chapter()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			for i in MOVE_BUTTONS.size():
				if MOVE_BUTTONS[i].has_point(m): take_step(MOVE_DIRECTIONS[i]); return
			if UNDO_BUTTON.has_point(m):
				if g.undo(): render_pos = Vector2(g.player) * CELL; chime("undo")
				return
			if RESTART_BUTTON.has_point(m): start_chapter(chapter); return
		for i in 3:
			if Rect2(450 + i * 88, 594, 76, 76).has_point(m): g.selected = i; return
		var p = Vector2i(((m - ORIGIN) / CELL).floor())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var d = p - g.player
			if d in g.DIRS: take_step(d)
		elif event.button_index == MOUSE_BUTTON_LEFT: respond(g.interact(p))

func _process(delta):
	clock += delta; cooldown -= delta
	if transition_time >= 0 and g.complete:
		transition_time -= delta
		if transition_time <= 0: next_chapter()
	if playing and not g.complete and cooldown <= 0:
		var d = queued_direction
		queued_direction = Vector2i.ZERO
		if d != Vector2i.ZERO: pass
		elif Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d = Vector2i.UP
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
		var bytes = PackedByteArray(); bytes.resize(int(22050 * length) * 2)
		for i in bytes.size() / 2:
			var t = float(i) / 22050.0
			var envelope = sin(minf(1, t / 0.008) * PI / 2) * pow(1 - t / length, 2)
			var wave = sin(t * frequencies[event] * TAU)
			if event in ["complete", "heart"]: wave = (wave + sin(t * frequencies[event] * 1.25 * TAU) + sin(t * frequencies[event] * 1.5 * TAU)) / 3
			var sample = int(wave * envelope * 24000)
			bytes[i * 2] = sample & 255
			bytes[i * 2 + 1] = (sample >> 8) & 255
		var sound = AudioStreamWAV.new(); sound.format = AudioStreamWAV.FORMAT_16_BITS; sound.mix_rate = 22050; sound.data = bytes
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
	return {"root": [Color("405b43"), Color("3b5953"), Color("595947"), Color("4b4e59"), Color("536445")][mini(chapter, 4)], "grass": Color("83a854"), "water": Color("466e91"), "stone": Color("a4a390")}.get(kind, Color("152930"))

func draw_seed(at: Vector2):
	draw_circle(at, 5, GOLD)
	draw_line(at + Vector2(0, 4), at + Vector2(0, 10), GOLD, 2)
	draw_line(at + Vector2(0, 6), at + Vector2(5, 2), GOLD, 2)

func _draw():
	if chapters.is_empty(): return
	if not playing:
		button(Rect2(456, 350, 240, 64), "Play", true)
		return
	draw_board()
	draw_sidebar()
	if g.complete and chapter == chapters.size() - 1: draw_completion()

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
	if g.complete:
		for p in g.rooted:
			if (p.x + p.y) % 3 == 0:
				var flower = ORIGIN + Vector2(p) * CELL + Vector2(11, 12)
				draw_circle(flower, 3, Color("e7c681"))
				draw_line(flower + Vector2(0, 3), flower + Vector2(0, 9), Color("a8c878"), 2)
	for p in g.trees:
		draw_texture_rect_region(props, Rect2(ORIGIN + Vector2(p) * CELL + Vector2(8, 5), Vector2(24, 30)), Rect2(4, 57, 8, 10))
	for p in g.water_sockets:
		var at = ORIGIN + Vector2(p) * CELL
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(34, 34)), Color("8bcada"), false, 2)
		if not g.tiles.has(p): centered(at + Vector2(20, 26), "~", 24, Color("8bcada"))
	for p in g.stone_sockets:
		var at = ORIGIN + Vector2(p) * CELL
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(34, 34)), GOLD, false, 2)
		if not g.tiles.has(p):
			var center = at + Vector2(20, 20)
			draw_polyline(PackedVector2Array([center + Vector2(0, -9), center + Vector2(9, 0), center + Vector2(0, 9), center + Vector2(-9, 0), center + Vector2(0, -9)]), GOLD, 2)
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
	if g.data.goal_kind == "heart_return": draw_goal(home_at)
	if g.exit_cell.x >= 0:
		draw_goal(ORIGIN + Vector2(g.exit_cell) * CELL + Vector2(20, 20))
	if g.heart.x >= 0 and not g.carrying:
		var at = ORIGIN + Vector2(g.heart) * CELL + Vector2(20, 17 + sin(clock * 3) * 2)
		draw_circle(at, 20, Color(0.9, 0.75, 0.35, 0.12))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, 0), at + Vector2(0, 12), at + Vector2(-8, 0)]), GOLD)
	for p in g.seeds:
		if p not in g.collected: draw_seed(ORIGIN + Vector2(p) * CELL + Vector2(20, 15 + sin(clock * 2 + p.x) * 2))
	var pos = ORIGIN + render_pos
	draw_set_transform(pos + Vector2(20, 27), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.3)); draw_set_transform(Vector2.ZERO)
	var moving = render_pos.distance_to(Vector2(g.player) * CELL) > 1
	# Keep the player visually facing the viewer in every movement direction.
	var row = 0
	var frame = int(clock * (10 if moving else 5)) % (4 if moving else 16)
	draw_texture_rect_region(walk_texture if moving else idle_texture, Rect2(pos + Vector2(-11, -11), Vector2(64, 64)), Rect2(frame * 32, row * 32, 32, 32))
	if g.carrying: draw_circle(pos + Vector2(30, 19), 5, GOLD)
	var hovered = Vector2i(((get_global_mouse_position() - ORIGIN) / CELL).floor())
	var d = hovered - g.player
	var target = hovered if d in g.DIRS else g.player + g.facing
	if not g.complete and g.inside(target): draw_rect(Rect2(ORIGIN + Vector2(target) * CELL + Vector2(1, 1), Vector2(38, 38)), GOLD, false, 2)
	for p in particles: draw_circle(p.pos, 2, Color(p.color, clampf(p.life * 2, 0, 1)))

func draw_goal(center: Vector2):
	var ready = g.all_seeds_collected() and g.powered()
	var color = GOLD if ready else MUTED
	draw_arc(center, 14, 0, TAU, 24, color, 2)
	if g.all_seeds_collected():
		draw_line(center + Vector2(-9, 0), center + Vector2(8, 0), color, 2)
		draw_polyline(PackedVector2Array([center + Vector2(1, -7), center + Vector2(8, 0), center + Vector2(1, 7)]), color, 2)
	else:
		draw_rect(Rect2(center + Vector2(-6, -1), Vector2(12, 9)), color, false, 2)
		draw_arc(center + Vector2(0, -2), 4, PI, TAU, 12, color, 2)
	for i in g.seeds.size():
		var dot = center + Vector2((i - (g.seeds.size() - 1) / 2.0) * 12, -24)
		draw_circle(dot, 3, GOLD if g.seeds[i] in g.collected else Color("42545a"))

func draw_sidebar():
	for i in MOVE_BUTTONS.size():
		var rect = MOVE_BUTTONS[i]
		box(rect, Color("243d40") if rect.has_point(get_global_mouse_position()) else Color("102329"))
		var center = rect.get_center()
		var direction = Vector2(MOVE_DIRECTIONS[i])
		var side = direction.orthogonal()
		draw_line(center - direction * 11, center + direction * 11, WHITE, 3)
		draw_polyline(PackedVector2Array([center + direction * 3 + side * 8, center + direction * 11, center + direction * 3 - side * 8]), WHITE, 3)
	box(UNDO_BUTTON, Color("102329"))
	var undo_center = UNDO_BUTTON.get_center()
	draw_arc(undo_center, 13, -PI * 0.8, PI * 0.65, 24, WHITE, 2)
	draw_polyline(PackedVector2Array([undo_center + Vector2(-12, -2), undo_center + Vector2(-12, -12), undo_center + Vector2(-2, -12)]), WHITE, 2)
	box(RESTART_BUTTON, Color("102329"))
	var restart_center = RESTART_BUTTON.get_center()
	draw_arc(restart_center, 13, -PI * 0.4, PI * 1.35, 28, WHITE, 2)
	draw_polyline(PackedVector2Array([restart_center + Vector2(3, -16), restart_center + Vector2(10, -10), restart_center + Vector2(16, -16)]), WHITE, 2)
	for i in 3:
		var rect = Rect2(450 + i * 88, 594, 76, 76)
		box(rect, Color("102329"), GOLD if g.selected == i else Color("354d50"))
		label(rect.position + Vector2(9, 19), str(i + 1), 13, MUTED)
		if i < g.bag.size():
			draw_rect(Rect2(rect.position + Vector2(23, 32), Vector2(30, 25)), tile_color(g.bag[i]))
		elif g.carrying and i == 2:
			draw_circle(rect.position + Vector2(38, 44), 10, GOLD)

func total_seeds() -> int:
	var count = 0
	for record in records.values(): count += int(record.get("seeds", 0))
	return count

func draw_completion():
	draw_rect(Rect2(0, 0, 1152, 768), Color(0.025, 0.06, 0.075, 0.94))
	centered(Vector2(576, 350), "The End", 48, WHITE)
	button(Rect2(456, 418, 240, 54), "Play again", true)
