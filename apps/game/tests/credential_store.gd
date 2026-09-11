extends SceneTree
const Store = preload("res://scripts/client/credential_store.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var origin := "https://vault-test-" + Crypto.new().generate_random_bytes(12).hex_encode() + ".invalid"
	var saved := await Store.request("write", origin, "test.token.only")
	if saved.get("unsupported", false):
		print("SKIP: native credential vault unavailable on this platform")
		quit()
		return
	var read := await Store.request("read", origin)
	var other := await Store.request("read", origin + "/other")
	var updated := await Store.request("write", origin, "updated.test.token")
	var latest := await Store.request("read", origin)
	var removed := await Store.request("delete", origin)
	assert(saved.ok and read.ok and read.value == "test.token.only")
	assert(other.missing and updated.ok and latest.value == "updated.test.token")
	assert(removed.ok and (await Store.request("read", origin)).missing)
	print("PASS: native vault roundtrip, origin isolation and deletion")
	quit()
