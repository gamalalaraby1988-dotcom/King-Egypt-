extends RefCounted
## Central collision contract for the city.
## Layer 1 remains reserved for static world geometry.

const WORLD_LAYER: int = 1 << 0
const PLAYER_LAYER: int = 1 << 1
const VEHICLE_LAYER: int = 1 << 2
const STAFF_LAYER: int = 1 << 3

const PLAYER_MASK: int = WORLD_LAYER | STAFF_LAYER
const VEHICLE_MASK: int = WORLD_LAYER | STAFF_LAYER
const STAFF_MASK: int = PLAYER_LAYER | VEHICLE_LAYER

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
