extends Node

var base_url := ""
var api_key := ""
var epoch := ""
var boot_id := ""
var instance_id := "main"
var sequence := 0
var busy := false
var next_report := 0.0
var retry_delay := 1.0

func configure() -> bool:
	base_url = OS.get_environment("DO_API_SERVER_URL").trim_suffix("/")
	if base_url.is_empty(): base_url = "http://127.0.0.1:8415"
	api_key = OS.get_environment("DO_API_KEY")
	boot_id = Crypto.new().generate_random_bytes(24).hex_encode()
	return api_key.length() >= 32 and (base_url.begins_with("http://") or base_url.begins_with("https://"))

func post(path: String, payload: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 3.0
	request.body_size_limit = 32768
	add_child(request)
	var error := request.request(base_url + path, ["Content-Type: application/json", "Authorization: Bearer " + api_key], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {}
	var value: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	return {"status":response[1], "body":value if value is Dictionary else {}}

func report(delta: float, players: Array) -> void:
	next_report -= delta
	if busy or next_report > 0: return
	busy = true
	if epoch.is_empty():
		var registered := await post("/api/v1/game/register", {"instance_id":instance_id, "boot_id":boot_id})
		if registered.get("status") == 200:
			epoch = registered.body.get("epoch", "")
			sequence = 0
	var result := {}
	if not epoch.is_empty():
		sequence += 1
		result = await post("/api/v1/game/presence", {"instance_id":instance_id, "epoch":epoch, "seq":sequence, "players":players})
	if result.get("status") == 409:
		epoch = ""
	if result.get("status") == 200:
		retry_delay = 1.0
		next_report = 5.0
	else:
		next_report = retry_delay
		retry_delay = minf(10.0, retry_delay * 2)
	busy = false
