extends Control
## Runtime minimap for the playable night levels. Coordinates share the painted ground bounds.

var controller: Node
var source_map: Texture2D
var world_bounds_px := Vector2.ONE


func _draw() -> void:
	var map_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	draw_rect(map_rect, Color("#11171b"), true)
	if source_map != null:
		draw_texture_rect(source_map, map_rect, false)
	draw_rect(map_rect, Color(0.78, 0.83, 0.81, 0.88), false, 1.0)
	if controller == null or not is_instance_valid(controller) or world_bounds_px.x <= 0.0 or world_bounds_px.y <= 0.0:
		return
	var inventory: Variant = controller.get("pack")
	var prize_id := String(controller.get("prize"))
	var objective_position: Vector2 = controller.get("objective_px")
	var exit_position: Vector2 = controller.get("exit_px")
	var has_prize := inventory is Array and (inventory as Array).has(prize_id)
	if not has_prize and objective_position.distance_to(exit_position) > 8.0:
		_draw_marker(_map_point(objective_position, map_rect), Color("#ffbd5a"), 4.0)
	_draw_marker(_map_point(exit_position, map_rect), Color("#7db6ff"), 4.0)
	var player_node := controller.get("player") as Node2D
	if is_instance_valid(player_node):
		var player_point := _map_point(player_node.global_position, map_rect)
		draw_circle(player_point, 7.0, Color(0.025, 0.04, 0.045, 0.95))
		draw_circle(player_point, 4.5, Color("#f4ead2"))
		draw_circle(player_point, 2.7, Color("#76e2b5"))


func _map_point(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		clampf(world_position.x / world_bounds_px.x, 0.0, 1.0),
		clampf(world_position.y / world_bounds_px.y, 0.0, 1.0))
	return map_rect.position + normalized * map_rect.size


func _draw_marker(point: Vector2, color: Color, radius: float) -> void:
	draw_circle(point, radius + 2.0, Color(0.025, 0.035, 0.04, 0.94))
	draw_circle(point, radius, color)
	draw_arc(point, radius + 2.0, 0.0, TAU, 18, Color(0.95, 0.92, 0.83, 0.85), 1.0)
