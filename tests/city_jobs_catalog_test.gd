extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var ids := CityJobsCatalog.get_job_ids()
	if ids.size() != 7:
		failures.append("Expected exactly seven approved delivery jobs.")
	var required_ids := [
		"parcel_shipping",
		"postal_mail",
		"pizza_delivery",
		"pharmacy_orders",
		"flowers_gifts",
		"home_orders",
		"luggage_delivery"
	]
	for required_id in required_ids:
		if not ids.has(required_id):
			failures.append("Missing approved job: " + required_id)
	for job_id in ids:
		var definition := CityJobsCatalog.get_job(job_id)
		var stops: Array = definition.get("stops", [])
		if stops.size() < 3 or stops.size() > 4:
			failures.append("%s must have three or four delivery stops." % job_id)
		for stop in stops:
			if not (stop is Vector3):
				failures.append("%s contains a non-Vector3 stop." % job_id)
			elif absf(stop.x) > 280.0 or stop.z < -400.0 or stop.z > 245.0:
				failures.append("%s contains a stop outside the playable city." % job_id)
	if CityJobsCatalog.FUEL_STATION != Vector3(-150.0, 0.15, 57.0):
		failures.append("Fuel return target does not match the approved open fuel station.")
	if failures.is_empty():
		print("City delivery jobs tests passed: 7 jobs, 3-4 stops each, and valid fuel return.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
