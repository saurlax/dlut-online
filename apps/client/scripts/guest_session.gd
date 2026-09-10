extends RefCounted

static var guest_id := ""
static var username := ""

static func valid_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

static func prepare() -> bool:
	if not guest_id.is_empty():
		return true
	var candidate := Crypto.new().generate_random_bytes(16).hex_encode()
	if not valid_id(candidate):
		return false
	guest_id = candidate
	username = "游客%06d" % (candidate.substr(0, 8).hex_to_int() % 1000000)
	return true
