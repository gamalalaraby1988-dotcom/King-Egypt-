extends SceneTree

func _initialize() -> void:
	call_deferred("_run_wallet_tests")

func _run_wallet_tests() -> void:
	await process_frame
	var wallet := root.get_node_or_null("WalletManager")
	if wallet == null or not wallet.initialized:
		push_error("WalletManager autoload did not initialize.")
		quit(1)
		return

	var transaction_id := "ci_wallet_test_%s" % str(Time.get_ticks_usec())
	var before: int = wallet.get_balance("gems")
	if not wallet.credit(transaction_id, "gems", 25, "CI test credit"):
		push_error("Wallet credit failed.")
		quit(1)
		return
	if wallet.get_balance("gems") != before + 25:
		push_error("Wallet credit balance mismatch.")
		quit(1)
		return
	if wallet.credit(transaction_id, "gems", 25, "duplicate test"):
		push_error("Duplicate transaction was accepted.")
		quit(1)
		return
	if not wallet.debit(transaction_id + "_debit", "gems", 10, "CI test debit"):
		push_error("Wallet debit failed.")
		quit(1)
		return
	if wallet.get_balance("gems") != before + 15:
		push_error("Wallet debit balance mismatch.")
		quit(1)
		return
	if wallet.debit(transaction_id + "_insufficient", "gems", before + 16, "insufficient test"):
		push_error("Insufficient-balance debit was accepted.")
		quit(1)
		return
	if wallet.credit(transaction_id + "_negative", "gems", -1, "invalid test"):
		push_error("Negative credit was accepted.")
		quit(1)
		return
	if wallet.credit(transaction_id + "_overflow", "gems", 2000000001, "overflow test"):
		push_error("Overflow credit was accepted.")
		quit(1)
		return

	var money_before: int = wallet.get_balance("money")
	var chips_before: int = wallet.get_balance("chips")
	if not wallet.sync_legacy_balances(money_before + 7, chips_before + 2):
		push_error("Legacy balance synchronization failed.")
		quit(1)
		return
	if wallet.get_balance("money") != money_before + 7 or wallet.get_balance("chips") != chips_before + 2:
		push_error("Legacy balance synchronization mismatch.")
		quit(1)
		return

	print("Wallet transaction tests passed.")
	quit(0)
