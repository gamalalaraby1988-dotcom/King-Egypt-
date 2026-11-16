extends RefCounted
## Central collision contract for the city.
## Layer 1 remains reserved for static world geometry.

const WORLD_LAYER: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1
const VEHICLE_LAYER: int = 1 << 2
const STAFF_LAYER: int = 1 << 3

const WORLD_MASK: int = WORLD_LAYER | PLAYER_LAYER | VEHICLE_LAYER
const PLAYER_MASK: int = WORLD_LAYER | STAFF_LAYER
const VEHICLE_MASK: int = WORLD_LAYER | STAFF_LAYER
const STAFF_MASK: int = PLAYER_LAYER | VEHICLE_LAYER

static func apply_world_collision(body: CollisionObject3D) -> void:
	if not is_instance_valid(body):
		return
	body.collision_layer = WORLD_LAYER
	body.collision_mask = WORLD_MASK

static func add_staff_collider(parent: Node3D, radius: float = 0.34, height: float = 1.8) -> StaticBody3D:
	if not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null("StaffCollisionBody") as StaticBody3D
	if is_instance_valid(existing):
		return existing
	var body := StaticBody3D.new()
	body.name = "StaffCollisionBody"
	body.collision_layer = STAFF_LAYER
	body.collision_mask = STAFF_MASK
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "StaffCollisionShape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(0.1, radius)
	capsule.height = maxf(capsule.radius * 2.0, height)
	collision_shape.shape = capsule
	collision_shape.position.y = capsule.height * 0.5
	body.add_child(collision_shape)
	parent.add_child(body)
	return body

static func add_world_box_collider(parent: Node3D, size: Vector3, position: Vector3, body_name: String = "WorldCollisionBody") -> StaticBody3D:
	if not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null(body_name) as StaticBody3D
	if is_instance_valid(existing):
		return existing
	var body := StaticBody3D.new()
	body.name = body_name
	apply_world_collision(body)
	body.add_to_group("city_world_geometry")
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	collision_shape.position = position
	body.add_child(collision_shape)
	parent.add_child(body)
	return body
