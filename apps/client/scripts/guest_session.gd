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
	var candidate := ""
	if OS.has_feature("web"):
		var stored: Variant = JavaScriptBridge.eval("(function(){try{return sessionStorage.getItem('do_guest_id') || '';}catch(e){return null;}})()")
		if not stored is String:
			return false
		candidate = stored
	if not valid_id(candidate):
		candidate = Crypto.new().generate_random_bytes(16).hex_encode()
	if not valid_id(candidate):
		return false
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval("(function(){try{sessionStorage.setItem('do_guest_id','%s');return sessionStorage.getItem('do_guest_id');}catch(e){return null;}})()" % candidate)
		if not saved is String or saved != candidate:
			return false
	guest_id = candidate
	username = "游客%06d" % (candidate.substr(0, 8).hex_to_int() % 1000000)
	return true
