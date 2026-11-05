extends RefCounted

const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIMENSIONS = Vector2i(19, 11)
var data: Dictionary
var tiles: Dictionary = {}
var rooted: Dictionary = {}
var trees: Array = []
var gates: Array = []
var water_sockets: Array = []
var stone_sockets: Array = []
var seeds: Array = []
var collected: Array = []
var home = Vector2i.ZERO
var exit_cell = Vector2i(-1, -1)
var heart = Vector2i(-1, -1)
var player = Vector2i.ZERO
var facing = Vector2i.RIGHT
var bag: Array = []
var selected = 0
var carrying = false
var complete = false
var collapsed = false
var moves = 0
var history: Array = []
var notice = ""
var last_event = ""

func cells(items: Array) -> Array:
	var result: Array = []
	for item in items: result.append(Vector2i(int(item[0]), int(item[1])))
	return result

func setup(level: Dictionary):
	data = level
	tiles.clear(); rooted.clear(); trees.clear(); collected.clear(); history.clear(); bag.clear()
	gates = cells(data.get("gates", []))
	water_sockets = cells(data.get("water_sockets", []))
	stone_sockets = cells(data.get("stone_sockets", []))
	seeds = cells(data.get("seeds", []))
	heart = Vector2i(-1, -1); exit_cell = Vector2i(-1, -1)
	for y in data.map.size():
		for x in data.map[y].length():
			var p = Vector2i(x, y)
			var symbol = data.map[y][x]
			match symbol:
				"g": tiles[p] = "grass"
				"s": tiles[p] = "stone"
				"w": tiles[p] = "water"
				"#", "@", "E", "H":
					tiles[p] = "root"
					rooted[p] = true
					if symbol == "@": home = p
					if symbol == "E": exit_cell = p
					if symbol == "H": heart = p
				"T": trees.append(p)
	player = home; facing = Vector2i.RIGHT; selected = 0
	carrying = data.get("carrying", false)
	complete = false; collapsed = false; moves = 0
	notice = data.get("intro", "")
	last_event = ""

func powered() -> bool:
	for p in water_sockets:
		if tiles.get(p, "void") != "water": return false
	for p in stone_sockets:
		if tiles.get(p, "void") != "stone": return false
	return true

func all_seeds_collected() -> bool:
	for seed in seeds:
		if seed not in collected: return false
	return true

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < DIMENSIONS.x and p.y >= 0 and p.y < DIMENSIONS.y

func walkable(p: Vector2i) -> bool:
	if not inside(p) or p in trees: return false
	if p in gates: return powered()
	return tiles.get(p, "void") in ["grass", "stone", "root"]

func checkpoint():
	history.append({"tiles": tiles.duplicate(), "player": player, "bag": bag.duplicate(), "carrying": carrying, "moves": moves, "complete": complete, "collapsed": collapsed, "collected": collected.duplicate(), "selected": selected})

func undo() -> bool:
	if history.is_empty(): return false
	var s = history.pop_back()
	tiles = s.tiles; player = s.player; bag = s.bag; carrying = s.carrying; moves = s.moves
	complete = s.complete; collapsed = s.collapsed; collected = s.collected; selected = s.selected
	notice = "Rewound. There is always another way."
	last_event = "undo"
	return true

func move_player(direction: Vector2i) -> bool:
	if complete or direction not in DIRS: return false
	facing = direction
	var target = player + direction
	if not walkable(target):
		notice = "The gate needs every marked socket filled." if target in gates else "No footing there. Borrow a tile, then place it in the gap."
		last_event = "blocked"
		return false
	checkpoint()
	player = target; moves += 1; last_event = "step"
	check_progress()
	return true

func interact(target: Vector2i) -> bool:
	if complete: return false
	if abs(target.x - player.x) + abs(target.y - player.y) != 1:
		notice = "You can reach the four tiles beside you."
		return false
	facing = target - player
	if not inside(target): return false
	if rooted.has(target) or target in trees or target in gates:
		notice = "Rooted ground stays put. Tiles with dotted edges can be borrowed."
		return false
	if tiles.has(target):
		if bag.size() >= (2 if carrying else 3):
			notice = "Pockets full. Place a tile in a gap before taking another."
			return false
		# Prevent removing support while standing on its gate.
		if player in gates and (target in water_sockets or target in stone_sockets):
			notice = "Step off the gate before removing its power."
			return false
		checkpoint()
		bag.append(tiles[target]); tiles.erase(target)
		notice = "Borrowed. Select a pocket with 1–3; place it beside you."
		last_event = "take"
	else:
		if bag.is_empty():
			notice = "Your pockets are empty. Look for a tile with a dotted edge."
			return false
		selected = clampi(selected, 0, bag.size() - 1)
		var kind = bag[selected]
		if target in water_sockets and kind != "water":
			notice = "The blue channel needs water. Select a water tile first."
			return false
		if target in stone_sockets and kind != "stone":
			notice = "This heavy foundation needs stone. Grass will not hold it."
			return false
		checkpoint()
		tiles[target] = bag.pop_at(selected)
		selected = mini(selected, maxi(0, bag.size() - 1))
		notice = "Placed. You can borrow it again from the other side."
		last_event = "place"
	moves += 1
	check_progress()
	return true

func check_progress():
	if player in seeds and player not in collected:
		collected.append(player); notice = "A wild seed rescued. An extra patch of forest will bloom."; last_event = "seed"
	if player == heart and not carrying:
		if bag.size() >= 3:
			notice = "The heart needs one free pocket. Place a tile beside you."
		else:
			carrying = true; last_event = "heart"
			notice = "The heart wakes! Your pockets now hold two terrain tiles."
			if not collapsed:
				for p in cells(data.get("collapse", [])): tiles.erase(p)
				collapsed = true
				if not data.get("collapse", []).is_empty(): notice = "The old path fell away. Carry the heart along the lower route."
	if data.get("goal_kind", "exit") == "heart_return":
		complete = carrying and player == home and (heart != home) and moves > 0 and powered() and (not data.get("require_exit", false) or collapsed)
	elif player == exit_cell:
		complete = powered() and (not data.get("require_heart", false) or carrying)
	complete = complete and all_seeds_collected()
	if not complete and (player == exit_cell or (player == home and carrying)) and not all_seeds_collected():
		notice = "Collect every yellow seed before leaving."
	if complete: last_event = "complete"; notice = "Another piece of the forest, made whole."
