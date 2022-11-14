class_name SymmetricShadowcasting extends RefCounted

# implementation of Symmetric Shadowcasting as presented by Albert Ford
# https://www.albertford.com/shadowcasting/
# this implementation sticks as close as possible to the original
# including creating a new custom class for "Fraction" due to the usage
# of the python fractions library which has no counterpart in Godot,
# rather than trying to be as clean or as "Godot" as possible


# for unknown reasons the original algorithm lacks a max distance
# to stop the algorithm at, but we need this so we don't search forever
var max_distance : int
var currentQuadrant : Quadrant

# the (external) functions that do the actual work of showing/hiding tiles
# as well as collision/occlusion checking.
var _mark_visible : Callable
var _is_blocking : Callable

func computeFov(origin : Vector2i, fov_distance : int, mark_visible : Callable, is_blocking : Callable):
	max_distance = fov_distance

	_mark_visible = mark_visible
	_is_blocking = is_blocking

	_mark_visible.call(origin.x, origin.y)
	
	for i in range(4):
		currentQuadrant = Quadrant.new(i, origin)
		var first_row = Row.new(1, Fraction.new(-1.0, 1.0), Fraction.new(1.0, 1.0))
		scan(first_row)

func scan(row : Row):
	if row.depth > max_distance:
		return
	var prev_tile = null
	for tile in row.tiles():
		if is_wall(tile) or is_symmetric(row, tile):
			reveal(tile)
		if is_wall(prev_tile) and is_floor(tile):
			row.start_slope = slope(tile)
		if is_floor(prev_tile) and is_wall(tile):
			var next_row = row.next()
			next_row.end_slope = slope(tile)
			scan(next_row)
		prev_tile = tile
	if is_floor(prev_tile):
		scan(row.next())

# included for completeness, not actually utilized here
func scan_iterative(_row : Row):
	var rows = []
	rows.append(_row)
	while not rows.is_empty():
		var row = rows.pop_front()
		if row.depth > max_distance:
			break
		var prev_tile = null
		for tile in row.tiles():
			if is_wall(tile) or is_symmetric(row, tile):
				reveal(tile)
			if is_wall(prev_tile) and is_floor(tile):
				row.start_slope = slope(tile)
			if is_floor(prev_tile) and is_wall(tile):
				var next_row = row.next()
				next_row.end_slope = slope(tile)
				rows.append(next_row)
			prev_tile = tile
		if is_floor(prev_tile):
			rows.append(row.next())

func slope(tile):
	var row_depth = tile.x
	var col = tile.y
	return Fraction.new((2 * col - 1), (2 * row_depth))

func is_symmetric(row : Row, tile) -> bool:
	# this variable isn't actually used
	var _row_depth = tile.x
	var col = tile.y
	return (col >= row.depth * row.start_slope.toFloat()
			and col <= row.depth * row.end_slope.toFloat())

func reveal(tile):
	var x = currentQuadrant.transform(tile).x
	var y = currentQuadrant.transform(tile).y
	_mark_visible.call(x,y)

func is_wall(tile) -> bool:
	if tile == null:
		return false
	var x = currentQuadrant.transform(tile).x
	var y = currentQuadrant.transform(tile).y
	return _is_blocking.call(x,y)

func is_floor(tile) -> bool:
	if tile == null:
		return false
	var x = currentQuadrant.transform(tile).x
	var y = currentQuadrant.transform(tile).y
	return not _is_blocking.call(x,y)

class Quadrant:
	var north = 0
	var east = 1
	var south = 2
	var west = 3
	
	var cardinal
	var ox
	var oy
	
	func _init(_cardinal : int, _origin : Vector2i):
		self.cardinal = _cardinal
		self.ox = _origin.x
		self.oy = _origin.y
	
	func transform(tile):
		var row = tile.x
		var col = tile.y
		if cardinal == north:
			return Vector2i(ox + col, oy - row)
		if cardinal == south:
			return Vector2i(ox + col, oy + row)
		if cardinal == east:
			return Vector2i(ox + row, oy + col)
		if cardinal == west:
			return Vector2i(ox - row, oy + col)
	
class Row:
	var depth
	var start_slope
	var end_slope
	
	func _init(_depth, _start_slope : Fraction, _end_slope : Fraction):
		self.depth = _depth
		self.start_slope = _start_slope
		self.end_slope = _end_slope
	
	func tiles():
		var tilesArr = []
		tilesArr.clear()
		var min_col = round_ties_up(depth * start_slope.toFloat())
		var max_col = round_ties_down(depth * end_slope.toFloat())
		# i have no idea why the original source has max_col+1 and works fine
		# but here in godot i need max_col+2 for it to function properly.
		for col in range(min_col, max_col+2):
			tilesArr.append(Vector2(depth, col))
		return tilesArr
	
	func next() -> Row:
		return Row.new(
			depth + 1,
			start_slope,
			end_slope
		)
	
	func round_ties_up(n : float) -> float:
		return floor(n + 0.5)
	func round_ties_down(n : float) -> float:
		return floor(n - 0.5)

class Fraction:
	var x : float
	var y : float
	
	func _init(_x : float, _y : float):
		x = _x
		y = _y
	
	func toFloat() -> float:
		return x / y
