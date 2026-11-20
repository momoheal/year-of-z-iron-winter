extends Control
## Runtime minimap for the playable night levels. Coordinates share the painted ground bounds.

const TARGET_COLOR := Color("#ffce7a")
const EXIT_COLOR := Color("#8fccff")
const PLAYER_COLOR := Color("#76e2b5")

var controller: Node
var source_map: Texture2D
var world_bounds_px := Vector2.ONE


func _draw() -> void:
	if world_bounds_px.x <= 0.0 or world_bounds_px.y <= 0.0:
		return
	var available := (size - Vector2(18.0, 18.0)).max(Vector2.ZERO)
	var map_scale := minf(available.x / world_bounds_px.x, available.y / world_bounds_px.y)
	var map_size := world_bounds_px * map_scale
	var map_rect := Rect2((size - map_size) * 0.5, map_size)
	draw_rect(map_rect, Color("#11171b"), true)
	if source_map != null:
		draw_texture_rect(source_map, map_rect, false, Color(0.82, 0.86, 0.88))
	draw_rect(map_rect, Color(0.78, 0.83, 0.81, 0.88), false, 1.0)
	if not is_instance_valid(controller):
		return
	var target: Variant = controller.mission_marker
	if target is Vector2:
		var point := _map_point(target, map_rect)
		var diamond := PackedVector2Array([point + Vector2(0, -7), point + Vector2(7, 0),
			point + Vector2(0, 7), point + Vector2(-7, 0), point + Vector2(0, -7)])
		draw_colored_polygon(diamond.slice(0, 4),
			Color("#101820") if controller.mission_marker_optional else TARGET_COLOR)
		draw_polyline(diamond, Color("#101820"), 4.5, true)
		draw_polyline(diamond, TARGET_COLOR, 1.8, true)
	var exit_point := _map_point(controller.exit_px, map_rect)
	draw_rect(Rect2(exit_point - Vector2(7, 7), Vector2(14, 14)), Color("#101820"))
	draw_rect(Rect2(exit_point - Vector2(5, 5), Vector2(10, 10)), EXIT_COLOR)
	var player_node := controller.player as Node2D
	if is_instance_valid(player_node):
		var player_point := _map_point(player_node.global_position, map_rect)
		draw_circle(player_point, 7.0, Color(0.025, 0.04, 0.045, 0.95))
		draw_circle(player_point, 4.5, Color("#f4ead2"))
		draw_circle(player_point, 2.7, PLAYER_COLOR)


func _map_point(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		clampf(world_position.x / world_bounds_px.x, 0.0, 1.0),
		clampf(world_position.y / world_bounds_px.y, 0.0, 1.0))
	return map_rect.position + normalized * map_rect.size
