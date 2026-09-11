extends RefCounted

const INTERVAL_MS := 1000
const MAX_EVENTS := 100

static func is_control(code: int) -> bool:
	return code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029]

static func text(value: Variant) -> String:
	if not value is String: return ""
	# Check before trimming so embedded or trailing newlines cannot slip through.
	for i in value.length():
		if is_control(value.unicode_at(i)): return ""
	var clean: String = value.strip_edges()
	if clean.is_empty() or clean.length() > 200 or clean.to_utf8_buffer().size() > 800: return ""
	return clean

static func player_name(value: String) -> String:
	var clean := ""
	for i in value.length():
		clean += " " if is_control(value.unicode_at(i)) else value[i]
	return clean

static func remaining(last: int, now: int) -> int:
	return maxi(0, INTERVAL_MS - (now - last))

static func line(event: Dictionary) -> String:
	match event.kind:
		"joined": return event.username + " 加入了服务器"
		"left": return event.username + " 离开了服务器"
		_: return "[世界] %s: %s" % [event.username, event.text]
