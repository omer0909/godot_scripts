extends Camera3D

@export var panel_path: NodePath
@onready var panel: Control = get_node(panel_path)

var rotating: bool = false
var dragging: bool = false
var modified: Vector2 = Vector2.ZERO
var zoom_speed = 0.2
@onready var pivot_node = Node3D.new()
var hit_point = null

func delta_rotation_vector(vector_a: Vector2, vector_b: Vector2):
	var vector_a_vertical = Vector2(vector_a.y, -vector_a.x)
	return Vector2(vector_b.dot(vector_a), vector_b.dot(vector_a_vertical))

func screen_pos_to_angle(screen_pos):
	var global_dir = project_ray_normal(screen_pos)
	var local_dir = global_transform.basis.inverse() * global_dir

	var horizontal_vector = Vector2(local_dir.x, -local_dir.z).normalized()
	var vertical_vector = Vector2(local_dir.y, -local_dir.z).normalized()
	
	var horizontal_angle =  rad_to_deg(atan2(horizontal_vector.x, horizontal_vector.y))
	var vertical_angle =  rad_to_deg(atan2(vertical_vector.x, vertical_vector.y))
	
	return Vector2(vertical_angle, horizontal_angle)

func calculate_angle(delta: Vector2) -> Vector2:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var old_mouse_pos: Vector2 = mouse_pos - delta
	
	var angle = screen_pos_to_angle(mouse_pos)
	var old_angle = screen_pos_to_angle(old_mouse_pos)
	var delta_angle = angle - old_angle
	return Vector2(-delta_angle.x, delta_angle.y)

func get_hit_pos(screen_pos : Vector2):

	# Kamera üzerinden ekran noktasına karşılık gelen ışının başlangıç noktası ve yönünü alıyoruz.
	var ray_origin: Vector3 = project_ray_origin(screen_pos)
	var ray_dir: Vector3 = project_ray_normal(screen_pos)

	# Işıının son noktasını hesaplıyoruz.
	var ray_end: Vector3 = ray_origin + ray_dir * 1000

	var space_state = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_end
	var result = space_state.intersect_ray(query)
	if result.has("position"):
		return result.position
	return null
	
func get_hit_distance(screen_pos, min_value, default_value):
	var hit_pos = get_hit_pos(screen_pos)
	if hit_pos == null:
		return default_value
	var distance = global_position.distance_to(hit_pos)
	return max(min_value, distance)

func _on_panel_gui_input(event: InputEvent) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not dragging:
			rotating = event.pressed
			if rotating:
				hit_point = get_hit_pos(mouse_pos)
				if hit_point:
					set_as_top_level(true)
					pivot_node.position = hit_point
					set_as_top_level(false)
			if not rotating or hit_point == null:
				set_as_top_level(true)
				pivot_node.global_transform = global_transform
				set_as_top_level(false)
		if event.button_index == MOUSE_BUTTON_RIGHT and not rotating:
			dragging = event.pressed
			if dragging:
				hit_point = get_hit_pos(mouse_pos)

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var distance = get_hit_distance(mouse_pos, 1, 5)
			pivot_node.global_translate(project_ray_normal(mouse_pos) * zoom_speed * distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var distance = get_hit_distance(mouse_pos, 1, 5)
			pivot_node.global_translate(-project_ray_normal(mouse_pos) * zoom_speed * distance)
	elif event is InputEventMouseMotion and rotating:
		var delta_angle = calculate_angle(event.relative - modified)
		modified = Vector2.ZERO
		var invert = 1 if hit_point == null else -1
		pivot_node.rotation_degrees.y += delta_angle.y * invert
		pivot_node.rotation_degrees.x = clamp(pivot_node.rotation_degrees.x + delta_angle.x * invert, -90, 90)

		var panel_rect: Rect2 = panel.get_global_rect()

		if mouse_pos.x > panel_rect.position.x + panel_rect.size.x:
			Input.warp_mouse(Vector2(panel_rect.position.x, mouse_pos.y))
			modified = Vector2(-panel_rect.size.x, 0)
		if mouse_pos.x < panel_rect.position.x:
			Input.warp_mouse(Vector2(panel_rect.position.x + panel_rect.size.x, mouse_pos.y))
			modified = Vector2(panel_rect.size.x, 0)

		if mouse_pos.y > panel_rect.position.y + panel_rect.size.y:
			Input.warp_mouse(Vector2(mouse_pos.x, panel_rect.position.y))
			modified = Vector2(0, -panel_rect.size.y)
		if mouse_pos.y < panel_rect.position.y:
			Input.warp_mouse(Vector2(mouse_pos.x, panel_rect.position.y + panel_rect.size.y))
			modified = Vector2(0, panel_rect.size.y)
	elif event is InputEventMouseMotion and dragging:
		var forward_distance = 5
		if not hit_point == null:
			forward_distance = abs((hit_point - global_position).dot(global_transform.basis.z))
		pivot_node.translate(Vector3(-event.relative.x, event.relative.y, 0) * (tan(deg_to_rad(self.fov / 2)) / get_viewport().size.y) * forward_distance * 2)

func _ready() -> void:
	panel.connect("gui_input", Callable(self, "_on_panel_gui_input"))

	var fix_call = func():
		pivot_node.global_transform = global_transform
		var parent = get_parent()
		var index = parent.get_children().find(self)
		parent.add_child(pivot_node)
		parent.move_child(pivot_node, index)
		parent.remove_child(self)
		pivot_node.add_child(self)

	fix_call.call_deferred()
