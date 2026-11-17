extends SceneTree

class RentalStaffFixture extends Node3D:
	@export var ride_price: int = 25

	func get_animal_rental_data() -> Dictionary:
		var animals: Array[String] = []
		for index in range(1, 9):
			animals.append("الحيوان رقم %d" % index)
		return {"title": "موظف اختبار", "description": "اختبار تأجير", "animals": animals, "price": ride_price}


func _initialize() -> void:
	call_deferred("_run_animal_rental_tests")


func _run_animal_rental_tests() -> void:
	await process_frame
	var auth := root.get_node_or_null("AuthManager")
	var account_session := root.get_node_or_null("AccountDataSession")
	var wallet := root.get_node_or_null("WalletManager")
	if auth == null or account_session == null or wallet == null:
		_fail("Required account and wallet autoloads are unavailable.")
		return
	if not wallet.initialized or not wallet.test_storage_enabled:
		_fail("Animal rental tests require the isolated --wallet-test storage fixture.")
		return
	if wallet.profile_path == "user://kings_city_profile.cfg":
		_fail("Animal rental test refused to use the real player profile.")
		return

	# A synthetic UUID activates AccountDataSession without contacting Supabase.
	var test_uid := "00000000-0000-4000-8000-000000000099"
	var generation: int = auth.get_session_generation()
	auth._authenticated_user_id = test_uid
	auth._authenticated_email = "ci-animal-rental@example.invalid"
	auth._access_token = "ci-animal-rental-access"
	auth._refresh_token = "ci-animal-rental-refresh"
	auth.session_changed.emit("", test_uid, generation)
	await process_frame
	if not account_session.is_session_current(test_uid, generation):
		_fail("Isolated synthetic account session did not activate.")
		return

	var mission_script: Script = load("res://scripts/mission_manager.gd")
	var player_script: Script = load("res://scripts/player.gd")
	var mission = mission_script.new()
	var player = player_script.new()
	var staff := RentalStaffFixture.new()
	mission.player = player
	mission.selected_animal_staff = staff
	mission.selected_activity_kind = "animal_rental"
	mission.active_rental_transaction_id = "ci_animal_rental_success"
	mission._profile_session_uid = test_uid
	mission._profile_session_generation = generation
	mission.animal_selector = OptionButton.new()
	for animal in staff.get_animal_rental_data().get("animals", []):
		mission.animal_selector.add_item(str(animal))
	mission.animal_selector.select(0)
	mission.status_label = Label.new()
	mission.description_label = Label.new()
	mission.reward_label = Label.new()
	mission.stats_label = Label.new()
	mission.accept_button = Button.new()
	mission.panel = PanelContainer.new()

	# Insufficient balance: no ride and no wallet mutation.
	mission.money = 0
	mission._rent_selected_animal()
	if player.is_riding_animal() or wallet.get_balance("money") != 0:
		_fail("Insufficient-balance rental started a ride or changed the wallet.")
		return

	# Seed only the isolated wallet fixture.
	if not wallet.credit("ci_animal_rental_seed", "money", 100, "Animal rental test fixture"):
		_fail("Could not seed the isolated wallet fixture.")
		return
	mission.money = wallet.get_balance("money")

	# A player already using a scooter cannot start an animal ride; the
	# production rental flow must leave the wallet untouched on that failure.
	player.set("scooter_riding", true)
	mission._rent_selected_animal()
	if player.is_riding_animal() or wallet.get_balance("money") != 100:
		_fail("Rejected ride start charged the player or left an animal ride active.")
		return
	player.set("scooter_riding", false)

	# Successful payment starts the actual player ride and deducts exactly one fare.
	mission._rent_selected_animal()
	if not player.is_riding_animal():
		_fail("Successful rental did not start the player animal ride.")
		return
	if wallet.get_balance("money") != 75 or mission.money != 75:
		_fail("Successful rental did not deduct exactly one 25-unit fare.")
		return
	if not wallet.has_transaction("spend_ci_animal_rental_success"):
		_fail("Successful rental did not persist its one-time payment receipt.")
		return

	# Reusing the same transaction ID after dismount must roll back the new ride.
	player.end_animal_ride()
	if player.is_riding_animal():
		_fail("Player could not dismount after a successful rental.")
		return
	mission._rent_selected_animal()
	if player.is_riding_animal():
		_fail("Duplicate rental transaction left the player mounted.")
		return
	if wallet.get_balance("money") != 75:
		_fail("Duplicate rental transaction charged the player more than once.")
		return

	player.end_animal_ride()
	if not wallet.default_profile_unchanged_after_test():
		_fail("Animal rental test changed the default player profile.")
		return

	player.free()
	staff.free()
	mission.free()
	auth.clear_session()
	await process_frame
	print("Animal rental payment, duplicate receipt, insufficient balance, ride start, and dismount tests passed using isolated fixture storage.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
