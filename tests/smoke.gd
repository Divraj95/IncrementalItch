extends SceneTree

const World = preload("res://scripts/world.gd")
const DIRECTIONS = {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}
var failures: Array[String] = []
var checks = 0

func _initialize():
	call_deferred("run")

func verify(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
	return condition

func point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

func valid_level(level: Dictionary, label: String) -> bool:
	var valid = verify(level.get("map", []).size() == 11, label + ": 11 map rows")
	var starts = 0
	var exits = 0
	var hearts = 0
	for row in level.get("map", []):
		valid = verify(row.length() == 19, label + ": 19 map columns") and valid
		for symbol in row:
			valid = verify(symbol in ". #gswT@EH", label + ": supported map symbol " + symbol) and valid
			starts += int(symbol == "@")
			exits += int(symbol == "E")
			hearts += int(symbol == "H")
	valid = verify(starts == 1, label + ": exactly one start") and valid
	valid = verify((exits == 1 if level.get("goal_kind", "exit") == "exit" else hearts == 1), label + ": objective exists") and valid
	var occupied: Array = []
	for group in ["water_sockets", "stone_sockets", "gates"]:
		for item in level.get(group, []):
			var cell = point(item)
			var inside = cell.x >= 0 and cell.x < 19 and cell.y >= 0 and cell.y < 11
			valid = verify(inside, label + ": " + group + " inside board") and valid
			if inside:
				valid = verify(level.map[cell.y][cell.x] in ". ", label + ": " + group + " has no conflicting terrain at " + str(cell)) and valid
			valid = verify(cell not in occupied, label + ": special cells do not overlap") and valid
			occupied.append(cell)
	return valid

func replay(level: Dictionary, label: String, all_seeds: bool = false):
	var world = World.new()
	world.setup(level)
	verify(not world.complete, label + ": starts incomplete")
	verify(world.walkable(world.player), label + ": starts on safe ground")
	verify(not level.get("solution", []).is_empty(), label + ": has executable solution")
	var action_index = 0
	for action in level.get("solution", []):
		action_index += 1
		var prefix = "%s action %d at %s: " % [label, action_index, world.player]
		if action.has("move"):
			if not verify(DIRECTIONS.has(action.move), prefix + "valid direction"): return
			for repetition in int(action.get("repeat", 1)):
				if not verify(world.move_player(DIRECTIONS[action.move]), prefix + "move " + action.move + " / " + world.notice): return
		elif action.has("take"):
			var target = point(action.take)
			if not verify(world.tiles.get(target, "void") in ["grass", "stone", "water"], prefix + "take movable terrain"): return
			if not verify(world.interact(target), prefix + "take " + str(target) + " / " + world.notice): return
		elif action.has("place"):
			world.selected = world.bag.find(action.material)
			if not verify(world.selected >= 0, prefix + "carrying " + action.material): return
			var target = point(action.place)
			if not verify(not world.tiles.has(target), prefix + "place into empty terrain"): return
			if not verify(world.interact(target), prefix + "place " + str(target) + " / " + world.notice): return
		else:
			verify(false, prefix + "unknown action")
			return
		verify(world.bag.size() <= (2 if world.carrying else 3), prefix + "inventory limit")
		verify(world.walkable(world.player), prefix + "player remains supported")
	verify(world.complete, label + ": reaches victory")
	verify(world.powered(), label + ": all required mechanisms powered")
	if all_seeds: verify(world.collected.size() == world.seeds.size(), label + ": all optional seeds collected")
	if level.get("require_heart", false) or level.get("goal_kind", "exit") == "heart_return":
		verify(world.carrying, label + ": heart recovered")
	var solved_moves = world.moves
	verify(world.undo() and not world.complete, label + ": undo reverses victory")
	while not world.history.is_empty(): world.undo()
	var pristine = World.new()
	pristine.setup(level)
	verify(world.tiles == pristine.tiles and world.player == pristine.player and world.bag == pristine.bag and world.carrying == pristine.carrying and world.collected.is_empty() and world.moves == 0, label + ": undo entire solution restores initial puzzle")
	world.setup(level)
	verify(world.tiles == pristine.tiles and world.player == pristine.player and world.history.is_empty(), label + ": restart deterministic")
	print("PASS %s: solution completed in %d actions; undo and restart checked" % [label, solved_moves])

func fixture(cells: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	for y in 11:
		var row = ""
		for x in 19: row += cells.get(Vector2i(x, y), ".")
		rows.append(row)
	var level = {"map": rows, "goal_kind": "exit", "water_sockets": [], "stone_sockets": [], "gates": [], "seeds": []}
	level.merge(extra, true)
	return level

func regressions():
	var w = World.new()
	var data = fixture({Vector2i(2,5): "@", Vector2i(1,5): "g", Vector2i(2,4): "s", Vector2i(2,6): "w", Vector2i(3,5): "g", Vector2i(3,6): "#", Vector2i(4,6): "T", Vector2i(18,10): "E"})
	w.setup(data)
	verify(w.interact(Vector2i(1,5)) and w.interact(Vector2i(2,4)) and w.interact(Vector2i(2,6)), "Inventory: accepts three terrain tiles")
	var before = w.tiles.duplicate()
	verify(not w.interact(Vector2i(3,5)) and w.tiles == before and w.bag.size() == 3, "Inventory: fourth pickup preserves terrain")
	verify(not w.interact(Vector2i(8,8)) and w.tiles == before, "Reach: distant interaction rejected")
	verify(not w.move_player(Vector2i.UP) and w.player == Vector2i(2,5), "Collision: void blocks movement")
	verify(w.move_player(Vector2i.RIGHT), "Movement: adjacent grass walkable")
	verify(not w.interact(Vector2i(3,6)), "Rooted paths cannot be collected")
	verify(w.move_player(Vector2i.DOWN) and not w.move_player(Vector2i.RIGHT), "Collision: trees block movement")
	verify(not w.move_player(Vector2i(2,0)), "Movement: multi-cell jumps rejected")

	data = fixture({Vector2i(2,5): "@", Vector2i(1,5): "g", Vector2i(2,4): "w", Vector2i(2,6): "s", Vector2i(18,10): "E"}, {"water_sockets": [[3,5]], "stone_sockets": [[4,5]], "gates": [[5,5]]})
	w.setup(data)
	w.interact(Vector2i(1,5))
	verify(not w.interact(Vector2i(3,5)) and w.bag == ["grass"], "Socket: water channel rejects grass without consuming it")
	w.interact(Vector2i(2,4)); w.selected = 1
	verify(w.interact(Vector2i(3,5)) and not w.walkable(Vector2i(3,5)), "Socket: water accepted but cannot be walked on")
	verify(not w.powered() and not w.walkable(Vector2i(5,5)), "Gate: partial power keeps gate shut")

	data = fixture({Vector2i(2,5): "@", Vector2i(1,5): "g", Vector2i(2,4): "s", Vector2i(2,6): "w", Vector2i(3,5): "H", Vector2i(3,4): "g", Vector2i(18,10): "E"}, {"require_heart": true, "collapse": [[2,5]]})
	w.setup(data)
	w.interact(Vector2i(1,5)); w.interact(Vector2i(2,4)); w.interact(Vector2i(2,6))
	w.move_player(Vector2i.RIGHT)
	verify(not w.carrying and not w.collapsed, "Heart: full pockets prevent pickup and collapse")
	w.selected = w.bag.find("grass")
	verify(w.interact(Vector2i(4,5)) and w.carrying and w.collapsed and w.bag.size() == 2 and not w.tiles.has(Vector2i(2,5)), "Heart: making room while on heart triggers pickup")
	verify(not w.interact(Vector2i(3,4)), "Heart: third terrain tile rejected while carrying heart")
	verify(w.undo() and not w.carrying and not w.collapsed and w.bag.size() == 3 and w.tiles.has(Vector2i(2,5)), "Undo: heart pickup and collapse reverse together")

	data = fixture({Vector2i(2,5): "@", Vector2i(3,5): "#", Vector2i(18,10): "E"}, {"seeds": [[3,5]]})
	w.setup(data)
	w.move_player(Vector2i.RIGHT)
	verify(w.collected.size() == 1, "Seeds: walking onto seed collects it")
	w.move_player(Vector2i.LEFT); w.move_player(Vector2i.RIGHT)
	verify(w.collected.size() == 1, "Seeds: revisiting does not duplicate collection")
	while not w.history.is_empty(): w.undo()
	verify(w.collected.is_empty(), "Undo: seed collection reversed")
	data = fixture({Vector2i(2,5): "@", Vector2i(1,5): "s", Vector2i(3,5): "#", Vector2i(18,10): "E"}, {"stone_sockets": [[2,4]], "gates": [[3,4]]})
	w.setup(data)
	w.interact(Vector2i(1,5)); w.interact(Vector2i(2,4))
	verify(w.powered() and w.walkable(Vector2i(3,4)), "Gate: correct stone support opens crossing")
	w.move_player(Vector2i.UP); w.move_player(Vector2i.RIGHT)
	verify(not w.interact(Vector2i(2,4)) and w.powered(), "Gate: cannot remove support beneath occupied gate")
	w.move_player(Vector2i.DOWN); w.move_player(Vector2i.LEFT)
	verify(w.interact(Vector2i(2,4)) and not w.powered(), "Gate: support can be reclaimed after stepping off")

	data = fixture({Vector2i(2,5): "@", Vector2i(3,5): "E"}, {"water_sockets": [[4,4]]})
	w.setup(data)
	verify(w.move_player(Vector2i.RIGHT) and not w.complete, "Objectives: bypassing gate cannot skip required power")
	print("PASS model regressions: pockets, reach, collision, sockets, heart, seeds, gate support")

func boot_scene():
	var scene = load("res://main.tscn")
	if not verify(scene is PackedScene, "Scene: main scene loads"): return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	if verify(game.get_script() != null, "Scene: gameplay script attached"):
		verify(game.chapters.size() == 5, "Scene: all five chapters available")
		# Browser playtests cover audio; keep headless teardown silent.
		game.muted = true
		game.start_chapter(0)
		verify(not game.map_open and game.chapter == 0, "Scene: campaign begins from chapter map")
		for i in 5: game.show_hint()
		verify(game.hint_count == 3, "Scene: progressive hints stop after three")
		game.g.interact(game.g.player + Vector2i.UP)
		game.load_chapter(0)
		verify(game.g.moves == 0 and game.hint_count == 0, "Scene: chapter restart clears puzzle and hints")
	for voice in game.voices:
		voice.stop()
		voice.stream = null
	game.tones.clear()
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	print("PASS scene boot, campaign loading, restart and hints")

func run():
	regressions()
	for index in range(1, 6):
		var path = "res://levels/%02d.json" % index
		if not verify(FileAccess.file_exists(path), "Campaign level exists: " + path): continue
		var level = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not verify(level is Dictionary, "Valid level JSON: " + path): continue
		var label = "Level %02d — %s" % [index, level.get("title", "untitled")]
		if valid_level(level, label):
			replay(level, label)
			if verify(level.has("all_seeds_solution"), label + ": executable all-seeds route exists"):
				var bonus = level.duplicate(true)
				bonus.solution = bonus.all_seeds_solution
				replay(bonus, label + " (all seeds)", true)
	await boot_scene()
	if failures.is_empty():
		print("PASS: all five levels and model regressions (%d checks)" % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)
