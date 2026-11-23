extends SceneTree

const CONTRACT = preload("res://scripts/jet_ski_network_contract.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var valid := CONTRACT.validate_input(1.0, 0.0, -0.5, 1, 0, 1000000, 0, 0)
	if not bool(valid.get("accepted", false)):
		failures.append("Valid bounded jet ski controls should be accepted.")
	if bool(CONTRACT.validate_input(1.1, 0.0, 0.0, 2, 1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Throttle above 1.0 must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 1.01, 2, 1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Steering outside [-1, 1] must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 1, 1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Replayed or stale input sequences must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 0, -1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Zero input sequence numbers must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 20000, 1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Implausibly large sequence jumps must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 2, 1, 900000, 1000000, 0).get("accepted", false)):
		failures.append("Monotonic clock regression must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 2, 1, 1100000, 1000000, -1).get("accepted", false)):
		failures.append("Corrupted rate-window counters must be rejected.")
	if bool(CONTRACT.validate_input(0.0, 0.0, 0.0, 2, 1, 1100000, 1000000, 35).get("accepted", false)):
		failures.append("Input above the per-second rate limit must be rejected.")
	if bool(CONTRACT.validate_input(NAN, 0.0, 0.0, 2, 1, 1100000, 1000000, 0).get("accepted", false)):
		failures.append("Non-finite control values must be rejected.")
	var moved := CONTRACT.step_motion(Vector3.ZERO, 0.0, Vector3.ZERO, 1.0, 0.0, 0.0, 0.05)
	var moved_velocity: Vector3 = moved.get("velocity", Vector3.ZERO)
	if moved_velocity.length() <= 0.0 or moved_velocity.length() > CONTRACT.MAX_FORWARD_SPEED:
		failures.append("Server hydrodynamic step must accelerate within the configured speed bound.")
	var braked := CONTRACT.step_motion(Vector3.ZERO, 0.0, Vector3(5.0, 0.0, 0.0), 1.0, 1.0, 0.0, 0.05)
	var braked_velocity: Vector3 = braked.get("velocity", Vector3.ZERO)
	if braked_velocity.length() >= 5.0:
		failures.append("Brake input must reduce planar speed.")
	var clamped := CONTRACT.step_motion(Vector3.ZERO, 0.0, Vector3.ZERO, 1.0, 0.0, 0.0, 1.0)
	var clamped_position: Vector3 = clamped.get("position", Vector3.ZERO)
	if clamped_position.length() > 0.02:
		failures.append("Simulation delta must be clamped against large client-independent steps.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Jet ski network contract tests passed.")
	quit(0)
