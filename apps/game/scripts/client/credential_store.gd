extends RefCounted

const SERVICE := "com.saurlax.dlutonline.account"
const WINDOWS_HELPER := "res://scripts/client/credential_store.ps1"
static var queue: Array[Dictionary] = []
static var running := false
static var revisions := {}

# Serialize vault operations so logout cannot race an earlier token write.
static func request(operation: String, origin: String, value := "") -> Dictionary:
	if OS.get_name() not in ["macOS", "Windows"]: return {"ok": false, "unsupported": true}
	origin = origin.trim_suffix("/")
	if operation in ["write", "delete"]:
		revisions[origin] = int(revisions.get(origin, 0)) + 1
		var marker := FileAccess.open(_marker(origin), FileAccess.WRITE)
		if marker != null:
			marker.store_string("disabled")
			marker.close()
	var item := {"operation": operation, "origin": origin, "value": value, "revision": revisions.get(origin, 0), "done": false, "result": {}}
	queue.append(item)
	if not running: _drain()
	while not item.done:
		await Engine.get_main_loop().process_frame
	return item.result

static func _drain() -> void:
	running = true
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		item.result = await _execute(item.operation, item.origin, item.value)
		if item.operation == "write" and item.result.ok and item.revision == revisions.get(item.origin):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_marker(item.origin)))
		item.value = ""
		item.done = true
	running = false

static func _marker(origin: String) -> String:
	return "user://session_disabled_" + origin.sha256_text()

static func _execute(operation: String, origin: String, value: String) -> Dictionary:
	if operation not in ["read", "write", "delete"] or origin.is_empty(): return {"ok": false}
	if operation == "write" and (value.length() > 2500 or RegEx.create_from_string("^[A-Za-z0-9._-]+$").search(value) == null):
		return {"ok": false}
	if operation == "read" and FileAccess.file_exists(_marker(origin)):
		return {"ok": false, "missing": true}
	var key := origin.sha256_text()
	var executable := ""
	var arguments := PackedStringArray()
	var input := ""
	if OS.get_name() == "macOS":
		executable = "/usr/bin/security"
		if operation == "write":
			# The token is sent over stdin, never in process arguments or a file.
			executable = "/bin/sh"
			arguments = ["-c", "IFS= read -r command; printf '%s\\n' \"$command\" | /usr/bin/security -iq"]
			input = "add-generic-password -U -s %s -a %s -w %s" % [SERVICE, key, value]
		elif operation == "read":
			arguments = ["find-generic-password", "-s", SERVICE, "-a", key, "-w"]
		else:
			arguments = ["delete-generic-password", "-s", SERVICE, "-a", key]
	elif OS.get_name() == "Windows":
		var helper := FileAccess.get_file_as_string(WINDOWS_HELPER)
		if helper.is_empty(): return {"ok": false}
		var command := "& {\n%s\n} '%s' '%s'" % [helper, operation, key]
		executable = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		arguments = ["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", Marshalls.raw_to_base64(command.to_utf16_buffer())]
		input = value
	else:
		return {"ok": false, "unsupported": true}
	var process := OS.execute_with_pipe(executable, arguments, false)
	if process.is_empty(): return {"ok": false}
	if operation == "write":
		process.stdio.store_line(input)
		process.stdio.flush()
	input = ""
	value = ""
	var output := PackedByteArray()
	var deadline := Time.get_ticks_msec() + 30000
	while OS.is_process_running(process.pid):
		output.append_array(process.stdio.get_buffer(4096))
		process.stderr.get_buffer(4096) # Never print vault output or credentials.
		if Time.get_ticks_msec() > deadline or output.size() > 4096:
			OS.kill(process.pid)
			process.stdio.close()
			process.stderr.close()
			return {"ok": false}
		await Engine.get_main_loop().process_frame
	output.append_array(process.stdio.get_buffer(4096))
	var code := OS.get_process_exit_code(process.pid)
	process.stdio.close()
	process.stderr.close()
	var missing: bool = code == (44 if OS.get_name() == "macOS" else 3)
	return {"ok": code == 0 or (operation == "delete" and missing), "missing": missing, "value": output.get_string_from_utf8().strip_edges() if code == 0 and operation == "read" else ""}
