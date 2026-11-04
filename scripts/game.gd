extends Node2D

const ORIGIN = Vector2(48, 190)
const CELL = 40
const SIZE = Vector2i(19, 11)
const HOME = Vector2i(2, 5)
const HEART = Vector2i(16, 5)
const GOLD = Color("e7c681")
const INK = Color("111e28")
var tiles: Dictionary = {}
var player = HOME
var facing = Vector2i.RIGHT
var bag: Array = []
var selected = 0
var history: Array = []
var carrying = false
var won = false
var moves = 0
var notice = "Borrow the earth. Leave a way home."
var clock = 0.0
var stride = 0.0
var walk_texture = preload("res://assets/creatures_ElfWalk.png")
var idle_texture = preload("res://assets/creatures_ElfIdle.png")
var props = preload("res://assets/overworld_Minifantasy_TinyOverworldForgottenPlainsProps.png")
var terrain = preload("res://assets/overworld_Minifantasy_TinyOverworldForgottenPlainsTileset.png")
var font = ThemeDB.fallback_font
var decorations = [Vector2i(1, 1), Vector2i(4, 2), Vector2i(1, 8), Vector2i(5, 9), Vector2i(11, 2), Vector2i(15, 1), Vector2i(17, 8), Vector2i(12, 9)]

func _ready():
	reset_game()

func reset_game():
	tiles.clear()
	for y in SIZE.y:
		for x in SIZE.x:
			var p = Vector2i(x, y)
			if ((x >= 1 and x <= 6) or (x >= 10 and x <= 17)) and y >= 1 and y <= 9:
				tiles[p] = "grass"
	for p in [Vector2i(5, 3), Vector2i(5, 4), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6)]:
		tiles[p] = "water"
	for p in [Vector2i(3, 7), Vector2i(4, 7), Vector2i(14, 3)]:
		tiles[p] = "stone"
	player = HOME
	bag = []
	history = []
	selected = 0
	carrying = false
	won = false
	moves = 0
	notice = "Borrow the earth. Leave a way home."
	queue_redraw()

func checkpoint():
	history.append({"tiles": tiles.duplicate(), "player": player, "bag": bag.duplicate(), "carrying": carrying, "moves": moves, "won": won})

func undo():
	if history.is_empty():
		return
	var s = history.pop_back()
	tiles = s.tiles
	player = s.player
	bag = s.bag
	carrying = s.carrying
	moves = s.moves
	won = s.won
	selected = mini(selected, maxi(0, bag.size() - 1))
	notice = "One step back. Every choice is reversible."
	queue_redraw()

func move_player(direction: Vector2i):
	if won:
		return
	facing = direction
	var target = player + direction
	if tiles.get(target, "void") not in ["grass", "stone"] or target in decorations:
		notice = "A gap ahead. Place ground beside you to cross."
		return
	checkpoint()
	player = target
	moves += 1
	stride = 0.22
	if player == HEART and not carrying:
		carrying = true
		notice = "The forest heart is yours. Bring it home; it needs one backpack slot."
		# Leave room for the heart without destroying a carried tile.
		if bag.size() == 3:
			carrying = false
			notice = "Make one backpack slot available, then step onto the heart again."
	elif player == HOME and carrying:
		won = true
		notice = "You brought the forest home."

func interact(target: Vector2i):
	if won:
		return
	if absi(target.x - player.x) + absi(target.y - player.y) != 1:
		notice = "Reach one tile beside you. Click an adjacent tile."
		return
	facing = target - player
	if target == HOME or target == HEART or target in decorations:
		notice = "These roots stay. Borrow an open patch of ground."
		return
	if target.x < 0 or target.y < 0 or target.x >= SIZE.x or target.y >= SIZE.y:
		return
	if tiles.has(target):
		if bag.size() >= (2 if carrying else 3):
			notice = "Backpack full. Place a tile into a gap first."
			return
		checkpoint()
		bag.append(tiles[target])
		tiles.erase(target)
		notice = "Ground pocketed. Click an adjacent gap to place it."
	else:
		if bag.is_empty():
			notice = "Empty pockets. Pick up a nearby grass or stone tile."
			return
		checkpoint()
		selected = clampi(selected, 0, bag.size() - 1)
		tiles[target] = bag.pop_at(selected)
		selected = mini(selected, maxi(0, bag.size() - 1))
		notice = "A little more world, right where you need it."
	moves += 1
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP: move_player(Vector2i.UP)
			KEY_S, KEY_DOWN: move_player(Vector2i.DOWN)
			KEY_A, KEY_LEFT: move_player(Vector2i.LEFT)
			KEY_D, KEY_RIGHT: move_player(Vector2i.RIGHT)
			KEY_E, KEY_SPACE: interact(player + facing)
			KEY_Z: undo()
			KEY_R: reset_game()
			KEY_1: selected = 0
			KEY_2: selected = 1
			KEY_3: selected = 2
			KEY_TAB: selected = (selected + 1) % maxi(1, bag.size())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m = get_global_mouse_position()
		if Rect2(840, 565, 260, 42).has_point(m):
			undo()
		elif Rect2(840, 615, 260, 42).has_point(m):
			reset_game()
		else:
			var picked_slot = false
			for i in 3:
				if Rect2(840 + i * 88, 342, 76, 76).has_point(m):
					selected = i
					picked_slot = true
			if not picked_slot:
				var relative = (m - ORIGIN) / CELL
				interact(Vector2i(floori(relative.x), floori(relative.y)))
	queue_redraw()

func _process(delta):
	clock += delta
	stride = maxf(0, stride - delta)
	queue_redraw()

func text_at(pos: Vector2, value: String, size: int = 16, color: Color = Color("d3dfd8")):
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, border: Color = Color("2c4049")):
	draw_style_box(make_box(color, border), rect)

func make_box(color: Color, border: Color) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(8)
	return b

func tile_color(kind: String) -> Color:
	return {"grass": Color("658b43"), "water": Color("466f9e"), "stone": Color("8c9185")}.get(kind, Color("172630"))

func _draw():
	text_at(Vector2(48, 42), "A SMALL ACT OF REBELLION", 13, GOLD)
	text_at(Vector2(46, 88), "Steal the Ground", 42, Color("eef0db"))
	text_at(Vector2(48, 121), "Take the forest heart. Bring it home. Borrow the world along the way.", 17)
	panel(Rect2(48, 148, 760, 30), Color("14242d"))
	text_at(Vector2(62, 168), "01  /  THE BROKEN GLADE", 12, GOLD)
	text_at(Vector2(618, 168), "%03d choices made" % moves, 12)
	panel(Rect2(44, 186, 768, 448), Color("0d1923"))
	for y in SIZE.y:
		for x in SIZE.x:
			var p = Vector2i(x, y)
			var at = ORIGIN + Vector2(p) * CELL
			var kind = tiles.get(p, "void")
			if kind == "void":
				if (x + y) % 3 == 0:
					draw_circle(at + Vector2(20, 22 + sin(clock + x) * 2), 1, Color("31424c"))
				continue
			draw_rect(Rect2(at + Vector2(0, 5), Vector2(CELL, CELL)), Color("293d32"))
			draw_rect(Rect2(at, Vector2(CELL, CELL - 2)), tile_color(kind))
			draw_line(at, at + Vector2(CELL, 0), Color(1, 1, 1, 0.09))
			if kind == "grass":
				# Decorative atlas detail from the original overworld tileset.
				draw_texture_rect_region(terrain, Rect2(at + Vector2(8, 7), Vector2(24, 24)), Rect2(148, 20, 8, 8), Color(1, 1, 1, 0.55))
				for j in 3:
					var dot = Vector2(7 + (x * 7 + j * 11) % 29, 7 + (y * 13 + j * 7) % 23)
					draw_rect(Rect2(at + dot, Vector2(2, 3)), Color("85a755"))
			elif kind == "water":
				for j in 3:
					draw_line(at + Vector2(5 + sin(clock * 2 + j) * 3, 8 + j * 10), at + Vector2(22 + sin(clock * 2 + j) * 3, 8 + j * 10), Color("7fadc3"), 2)
			else:
				draw_rect(Rect2(at + Vector2(6, 7), Vector2(27, 23)), Color("a6aa99"), false, 2)
	for p in decorations:
		var at = ORIGIN + Vector2(p) * CELL
		draw_texture_rect_region(props, Rect2(at + Vector2(2, -10), Vector2(36, 48)), Rect2(0, 56, 12, 16))
	var home_at = ORIGIN + Vector2(HOME) * CELL + Vector2(20, 20)
	draw_circle(home_at, 15 + sin(clock * 2), Color("b9ce88"), false, 2)
	text_at(home_at + Vector2(-15, 5), "H", 19, Color("f4e8ba"))
	if not carrying and not won:
		var h = ORIGIN + Vector2(HEART) * CELL + Vector2(20, 18 + sin(clock * 3) * 3)
		draw_circle(h, 21, Color(0.9, 0.75, 0.35, 0.12))
		draw_colored_polygon(PackedVector2Array([h + Vector2(0, -13), h + Vector2(9, 0), h + Vector2(0, 13), h + Vector2(-9, 0)]), GOLD)
	var player_at = ORIGIN + Vector2(player) * CELL
	draw_ellipse_shadow(player_at + Vector2(20, 30))
	var row = 0
	if facing == Vector2i.LEFT: row = 1
	elif facing == Vector2i.RIGHT: row = 2
	elif facing == Vector2i.UP: row = 3
	var tex = walk_texture if stride > 0 else idle_texture
	var frame = int(clock * (8 if stride > 0 else 5)) % (4 if stride > 0 else 16)
	draw_texture_rect_region(tex, Rect2(player_at + Vector2(-12, -22), Vector2(64, 64)), Rect2(frame * 32, row * 32, 32, 32))
	if carrying:
		draw_circle(player_at + Vector2(30, 5), 5, GOLD)
	var hovered = Vector2i(((get_global_mouse_position() - ORIGIN) / CELL).floor())
	var target = hovered if absi(hovered.x - player.x) + absi(hovered.y - player.y) == 1 else player + facing
	draw_rect(Rect2(ORIGIN + Vector2(target) * CELL + Vector2(1, 1), Vector2(38, 38)), GOLD, false, 2)
	panel(Rect2(828, 148, 284, 510), Color("13232b"))
	text_at(Vector2(848, 181), "YOUR JOURNEY", 13, GOLD)
	text_at(Vector2(848, 215), "The forest remembers.", 20)
	text_at(Vector2(848, 249), "2. Return to the home ring" if carrying else "1. Reach the golden heart", 16)
	text_at(Vector2(848, 277), "Heart recovered" if carrying else "Across the broken glade", 14, Color("93b48a"))
	text_at(Vector2(848, 324), "POCKET TERRAIN   /   1 · 2 · 3", 12, GOLD)
	for i in 3:
		var r = Rect2(840 + i * 88, 342, 76, 76)
		panel(r, INK, GOLD if selected == i else Color("35494e"))
		if i < bag.size():
			draw_rect(Rect2(r.position + Vector2(20, 15), Vector2(36, 30)), tile_color(bag[i]))
			text_at(r.position + Vector2(9, 62), bag[i].capitalize(), 13)
		elif carrying and i == 2:
			draw_circle(r.position + Vector2(38, 28), 11, GOLD)
			text_at(r.position + Vector2(19, 62), "Heart", 13)
		else:
			text_at(r.position + Vector2(18, 45), "empty", 13, Color("62787e"))
	text_at(Vector2(848, 454), "WASD / Arrows     Walk", 15)
	text_at(Vector2(848, 481), "Click beside you    Take / place", 15)
	text_at(Vector2(848, 508), "E / Space               Use facing tile", 15)
	text_at(Vector2(848, 539), "Water cannot be walked on.", 13, Color("91a5ae"))
	panel(Rect2(840, 565, 260, 42), Color("22363c"))
	text_at(Vector2(859, 592), "Z    Undo last choice", 16)
	panel(Rect2(840, 615, 260, 42), Color("22363c"))
	text_at(Vector2(859, 642), "R    Begin again", 16)
	text_at(Vector2(48, 677), notice, 16, GOLD)
	text_at(Vector2(48, 713), "TIP   Take three grass tiles near the shore. Build a bridge into the dark gap.", 14, Color("91a5ae"))
	text_at(Vector2(48, 749), "PROTOTYPE 01", 11, Color("62787e"))
	text_at(Vector2(790, 749), "Minifantasy art © Krishna Palacio", 12, Color("91a5ae"))
	if won:
		panel(Rect2(180, 280, 520, 200), Color("142a29"), GOLD)
		text_at(Vector2(220, 330), "A little world, made whole.", 28, GOLD)
		text_at(Vector2(220, 375), "You stole the ground to give something back.", 18)
		text_at(Vector2(220, 412), "%d choices. One forest heart returned." % moves, 18)
		text_at(Vector2(220, 451), "Press R to find another way home.", 16)

func draw_ellipse_shadow(at: Vector2):
	draw_set_transform(at, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
