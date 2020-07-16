# open-tabletop
# Copyright (c) 2020 drwhut
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends StackablePiece

class_name Stack

enum {
	STACK_AUTO,
	STACK_BOTTOM,
	STACK_TOP
}

enum {
	FLIP_AUTO,
	FLIP_NO,
	FLIP_YES
}

# Usually, these would be onready variables, but since this object is always
# made in code, we set these variables before we need them.
onready var _collision_shape = $CollisionShape
onready var _pieces = $Pieces

var _collision_unit_height = 0

func add_piece(piece: StackPieceInstance, shape: Shape, on: int = STACK_AUTO,
	flip: int = FLIP_AUTO) -> void:
	
	var on_top = false
	
	if on == STACK_AUTO:
		if transform.origin.y < piece.transform.origin.y:
			on_top = transform.basis.y.dot(Vector3.UP) > 0
		else:
			on_top = transform.basis.y.dot(Vector3.UP) < 0
	elif on == STACK_BOTTOM:
		on_top = false
	elif on == STACK_TOP:
		on_top = true
	else:
		push_error("Invalid stack option " + str(on) + "!")
		return
	
	var pos = 0
	if on_top:
		pos = _pieces.get_child_count()
	
	_add_piece_at_pos(piece, shape, pos, flip)

# NOTE: If you plan to remove the stack, but get the pieces of the stack (e.g.
# when putting one stack on top of another), use this function!
# This function exists as a workaround to a bug where the engine crashes when
# you change the collision shape of a rigidbody before removing it from the
# tree.
# See: https://github.com/godotengine/godot/issues/40283
func empty() -> Array:
	var out = []
	
	for piece in _pieces.get_children():
		_pieces.remove_child(piece)
		out.push_back(piece)
	
	return out

func get_pieces() -> Array:
	return _pieces.get_children()

func get_pieces_count() -> int:
	return _pieces.get_child_count()

func is_piece_flipped(piece: StackPieceInstance) -> bool:
	return transform.basis.y.dot(piece.transform.basis.y) < 0

func pop_piece(from: int = STACK_AUTO) -> StackPieceInstance:
	if _pieces.get_child_count() == 0:
		return null
	
	var pos = 0
	
	if from == STACK_AUTO:
		if transform.basis.y.dot(Vector3.UP) > 0:
			pos = _pieces.get_child_count() - 1
		else:
			pos = 0
	elif from == STACK_BOTTOM:
		pos = 0
	elif from == STACK_TOP:
		pos = _pieces.get_child_count() - 1
	else:
		push_error("Invalid from option " + str(from) + "!")
		return null
	
	return _remove_piece_at_pos(pos)

func remove_piece(piece: StackPieceInstance) -> void:
	if _pieces.is_a_parent_of(piece):
		_remove_piece_at_pos(piece.get_index())
	else:
		push_error("Piece " + piece.name + " is not a child of this stack!")
		return

puppet func remove_piece_by_name(name: String) -> void:
	var piece = _pieces.get_node(name)
	
	if not piece:
		push_error("Piece " + name + " is not in the stack!")
		return
	
	remove_piece(piece)

func _add_piece_at_pos(piece: StackPieceInstance, shape: Shape, pos: int, flip: int) -> void:
	_pieces.add_child(piece)
	_pieces.move_child(piece, pos)
	
	if _pieces.get_child_count() == 1:
		piece_entry = piece.piece_entry
		
		if shape is BoxShape:
			var new_shape = BoxShape.new()
			new_shape.extents = shape.extents
			_collision_unit_height = shape.extents.y * 2
			
			_collision_shape.shape = new_shape
		else:
			push_error("Piece " + piece.name + " has an unsupported collision shape!")
	else:
		if _collision_shape.shape is BoxShape:
			_collision_shape.shape.extents.y += (_collision_unit_height / 2)
	
	var n = _pieces.get_child_count()
	var is_flipped = false
	
	if flip == FLIP_AUTO:
		if is_piece_flipped(piece):
			is_flipped = true
		else:
			is_flipped = false
	elif flip == FLIP_NO:
		is_flipped = false
	elif flip == FLIP_YES:
		is_flipped = true
	else:
		push_error("Invalid flip option " + str(flip) + "!")
		return
	
	var basis = Basis.IDENTITY
	if is_flipped:
		basis = basis.rotated(Vector3.BACK, PI)
	
	piece.transform = Transform(basis, Vector3.ZERO)
	_set_piece_heights()
	
	_adjust_collision_shape_translation()

func _adjust_collision_shape_translation() -> void:
	# Adjust the collision shape's translation to match up with the pieces.
	_collision_shape.translation.y = _collision_unit_height * (_pieces.get_child_count() - 1) / 2

func _remove_piece_at_pos(pos: int) -> StackPieceInstance:
	if pos < 0 or pos >= _pieces.get_child_count():
		push_error("Cannot remove " + str(pos) + "th child from the stack!")
		return null
	
	var piece = _pieces.get_child(pos)
	_pieces.remove_child(piece)
	
	# Re-calculate the stacks collision shape.
	if _collision_shape.shape is BoxShape:
		_collision_shape.shape.extents.y -= (_collision_unit_height / 2)
	else:
		push_error("Stack has an unsupported collision shape!")
		return null
	
	_adjust_collision_shape_translation()
	_set_piece_heights()
	
	return piece

func _set_piece_heights() -> void:
	var i = 0
	for piece in _pieces.get_children():
		piece.transform.origin.y = _collision_unit_height * i
		i += 1