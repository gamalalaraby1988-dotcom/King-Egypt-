extends RefCounted
## Pure server-side jet ski input contract and hydrodynamic step.
## This module never accepts client positions or awards race progress.

const MAX_INPUT_RATE := 35
const INPUT_WINDOW_USEC := 1000000
const MAX_SEQUENCE_GAP := 10000
const MAX_FORWARD_SPEED := 15.5
const ACCELERATION := 5.2
const BRAKING_DECELERATION := 8.5
const WATER_RESISTANCE := 1.15
const LATERAL_WATER_RESISTANCE := 4.8
const MAX_YAW_RATE := 1.25
const MIN_STEERING_AUTHORITY := 0.12


static func validate_input(throttle: Variant, brake: Variant, steering: Variant, sequence: int, last_sequence: int, now_usec: int, window_start_usec: int, window_count: int) -> Dictionary:
	if not _is_finite_number(throttle) or not _is_finite_number(brake) or not _is_finite_number(steering):
		return {"accepted": false, "reason": "non_finite"}
	var safe_throttle := float(throttle)
	var safe_brake := float(brake)
	var safe_steering := float(steering)
	if safe_throttle < 0.0 or safe_throttle > 1.0 or safe_brake < 0.0 or safe_brake > 1.0 or absf(safe_steering) > 1.0:
		return {"accepted": false, "reason": "out_of_bounds"}
	if sequence <= last_sequence or sequence - last_sequence > MAX_SEQUENCE_GAP:
		return {"accepted": false, "reason": "invalid_sequence"}
	var safe_window_start := window_start_usec
	var safe_count := window_count
	if now_usec < safe_window_start or now_usec - safe_window_start >= INPUT_WINDOW_USEC:
		safe_window_start = now_usec
		safe_count = 0
	if safe_count >= MAX_INPUT_RATE:
		return {"accepted": false, "reason": "rate_limited", "window_start_usec": safe_window_start, "window_count": safe_count}
	return {
		"accepted": true,
		"throttle": safe_throttle,
		"brake": safe_brake,
		"steering": safe_steering,
		"sequence": sequence,
		"window_start_usec": safe_window_start,
		"window_count": safe_count + 1
	}


static func step_motion(position: Vector3, rotation_y: float, planar_velocity: Vector3, throttle: float, brake: float, steering: float, delta: float) -> Dictionary:
	var safe_delta := clampf(delta, 0.0, 0.05)
	var safe_throttle := clampf(throttle, 0.0, 1.0)
	var safe_brake := clampf(brake, 0.0, 1.0)
	var safe_steering := clampf(steering, -1.0, 1.0)
	var velocity := Vector3(planar_velocity.x, 0.0, planar_velocity.z)
	var forward := Vector3(-sin(rotation_y), 0.0, -cos(rotation_y))
	var right := Vector3(cos(rotation_y), 0.0, -sin(rotation_y))
	if safe_brake > 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, BRAKING_DECELERATION * safe_brake * safe_delta)
	elif safe_throttle > 0.0:
		velocity += forward * ACCELERATION * safe_throttle * safe_delta
	velocity = velocity.move_toward(Vector3.ZERO, WATER_RESISTANCE * safe_delta)
	var lateral_speed := velocity.dot(right)
	velocity -= right * lateral_speed * minf(1.0, LATERAL_WATER_RESISTANCE * safe_delta)
	var forward_speed := velocity.dot(forward)
	if absf(forward_speed) > MAX_FORWARD_SPEED:
		velocity -= forward * (forward_speed - signf(forward_speed) * MAX_FORWARD_SPEED)
	var next_rotation := rotation_y
	if absf(forward_speed) > 0.35 and absf(safe_steering) > 0.01:
		var authority := lerpf(MIN_STEERING_AUTHORITY, 1.0, clampf(absf(forward_speed) / MAX_FORWARD_SPEED, 0.0, 1.0))
		var reverse_sign := -1.0 if forward_speed < 0.0 else 1.0
		next_rotation -= safe_steering * MAX_YAW_RATE * authority * reverse_sign * safe_delta
	var next_position := position + velocity * safe_delta
	return {
		"position": next_position,
		"rotation_y": next_rotation,
		"velocity": velocity
	}


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
