extends SceneTree

const Rules = preload("res://scripts/shared/chat_rules.gd")
const Account = preload("res://scripts/client/account_session.gd")
class ChatServer extends "res://scripts/server/game_server.gd":
	var delivered: Array[Dictionary] = []
	func send(c: Dictionary, value: Dictionary) -> void:
		delivered.append({"recipient":c.identity.id, "message":value.duplicate()})

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert(Rules.remaining(100, 1099) == 1)
	assert(Rules.remaining(100, 1100) == 0)
	assert(Rules.remaining(999, 1001) == 998, "Natural second boundaries do not reset cooldown")
	assert(Rules.text("  世界  ") == "世界")
	assert(Rules.text("[color=red]text[/color]") == "[color=red]text[/color]")
	for invalid in [null, " ", "a\nb", "a\r", "a\u0085", "a\u2028b", "x".repeat(201)]:
		assert(Rules.text(invalid).is_empty())
	assert(Rules.text("😀".repeat(200)).to_utf8_buffer().size() == 800)
	assert(Rules.player_name("A\nB") == "A B")
	var server := ChatServer.new()
	var first := {"identity":{"id":"aaaaaaaaaaaaaaa", "username":"Player"}, "chat_request":0,
		"campus":"lingshui", "announced":true, "body":null}
	var second := {"identity":{"id":"bbbbbbbbbbbbbbb", "username":"Other"}, "chat_request":0,
		"campus":"eda", "announced":true, "body":null}
	server.players = {first.identity.id:first, second.identity.id:second}
	server.receive_chat(first, {"type":"chat_send", "request_id":1, "text":"123123"})
	server.flush_chat_events()
	assert(server.delivered.size() == 2, "Broadcast includes sender and other campus")
	assert(Rules.line(server.delivered[0].message) == "[世界] Player: 123123")
	var accepted: int = server.chat_last_accepted[first.identity.id]
	server.receive_chat(first, {"type":"chat_send", "request_id":2, "text":"too soon"})
	assert(server.delivered[-1].message.error == "rate_limited")
	assert(server.chat_last_accepted[first.identity.id] == accepted)
	server.receive_chat(first, {"type":"chat_send", "request_id":3, "text":"valid", "username":"forged"})
	assert(server.delivered[-1].message.error == "invalid_text")
	assert(server.chat_last_accepted[first.identity.id] == accepted)
	var count := server.delivered.size()
	server.receive_chat(first, {"type":"chat_send", "request_id":3, "text":"duplicate"})
	assert(server.delivered.size() == count)
	# Replacing a connection preserves the account's timestamp, but old callbacks
	# cannot remove the new online identity or generate a spurious departure.
	var replacement := first.duplicate(true)
	replacement.chat_request = 0
	server.players[first.identity.id] = replacement
	server.remove_player(first)
	assert(server.players.has(first.identity.id) and server.chat_events.is_empty())
	server.receive_chat(replacement, {"type":"chat_send", "request_id":1, "text":"reconnect"})
	assert(server.delivered[-1].message.error == "rate_limited")
	server.chat_last_accepted[first.identity.id] = Time.get_ticks_msec() - 1000
	server.receive_chat(replacement, {"type":"chat_send", "request_id":2, "text":"after cooldown"})
	assert(server.chat_events.size() == 1)
	server.flush_chat_events()
	server.remove_player(replacement)
	server.remove_player(replacement)
	assert(server.chat_events.size() == 1)
	assert(Rules.line(server.chat_events[0]) == "Player 离开了服务器")
	server.flush_chat_events()
	assert(server.delivered[-1].recipient == second.identity.id)
	server.free()
	var network := root.get_node("GameNetwork")
	Account.player_id = "aaaaaaaaaaaaaaa"
	network.welcomed = true
	network.chat_pending = 1
	network.chat_draft = "123123"
	var event := {"event_id":1, "kind":"message", "username":"Player", "id":Account.player_id,
		"text":"123123", "request_id":1}
	network._receive_chat(event)
	network._receive_chat(event)
	assert(network.chat_events.size() == 1 and network.chat_pending == 0 and network.chat_draft == "")
	network.transfer_phase = "loading"
	for i in range(2, 105):
		event.event_id = i
		network._receive_chat(event)
	assert(network.chat_events.size() == 100 and network.chat_events[0].event_id == 5)
	network._reset_chat()
	assert(network.chat_events.is_empty() and network.chat_draft.is_empty())
	print("PASS: chat boundaries, authority, cooldown, replacement, departure, deduplication and bounded cross-map cache")
	quit()
