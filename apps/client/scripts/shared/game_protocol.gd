extends RefCounted

const VERSION := 3
const CONTROL := 0
const REALTIME := 1
const MAPS := ["lingshui", "eda", "panjin"]
const RECORD_SIZE := 68
const HEADER_SIZE := 16
const PER_PACKET := 12

static func endpoint(url: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(enet|enets)://(\\[[0-9a-fA-F:]+\\]|[A-Za-z0-9.-]+):([0-9]+)$")
	var match_url := regex.search(url)
	if match_url == null: return {}
	var port := match_url.get_string(3).to_int()
	if port < 1 or port > 65535: return {}
	return {"host":match_url.get_string(2).trim_prefix("[").trim_suffix("]"), "port":port, "secure":match_url.get_string(1) == "enets"}

static func snapshots(campus: String, tick: int, states: Array) -> Array[PackedByteArray]:
	var packets: Array[PackedByteArray] = []
	var parts := maxi(1, ceili(states.size() / float(PER_PACKET)))
	for part in parts:
		var count := mini(PER_PACKET, states.size() - part * PER_PACKET)
		var packet := PackedByteArray()
		packet.resize(HEADER_SIZE + count * RECORD_SIZE)
		packet[0] = VERSION
		packet[1] = MAPS.find(campus)
		packet[2] = part
		packet[3] = parts
		packet.encode_u64(4, tick)
		packet.encode_u32(12, count)
		for i in count:
			var state: Dictionary = states[part * PER_PACKET + i]
			var offset := HEADER_SIZE + i * RECORD_SIZE
			var id: PackedByteArray = state.id.hex_decode()
			for j in 16: packet[offset + j] = id[j]
			for j in 3:
				packet.encode_float(offset + 16 + j * 4, state.position[j])
				packet.encode_float(offset + 28 + j * 4, state.velocity[j])
			packet.encode_float(offset + 40, state.yaw)
			packet.encode_s64(offset + 44, state.seq)
			packet.encode_u64(offset + 52, state.jump)
			packet.encode_u64(offset + 60, state.map_epoch)
		packets.append(packet)
	return packets

static func read_snapshot(packet: PackedByteArray) -> Dictionary:
	if packet.size() < HEADER_SIZE or packet[0] != VERSION or packet[1] >= MAPS.size(): return {}
	var count := packet.decode_u32(12)
	if count > PER_PACKET or packet.size() != HEADER_SIZE + count * RECORD_SIZE or packet[3] < 1 or packet[3] > 5 or packet[2] >= packet[3]: return {}
	var states: Array = []
	for i in count:
		var offset := HEADER_SIZE + i * RECORD_SIZE
		var position: Array = []
		var velocity: Array = []
		for j in 3:
			position.append(packet.decode_float(offset + 16 + j * 4))
			velocity.append(packet.decode_float(offset + 28 + j * 4))
		states.append({"id":packet.slice(offset,offset+16).hex_encode(), "position":position, "velocity":velocity,
			"yaw":packet.decode_float(offset+40), "seq":packet.decode_s64(offset+44),
			"jump":packet.decode_u64(offset+52), "map_epoch":packet.decode_u64(offset+60)})
	return {"campus":MAPS[packet[1]], "tick":packet.decode_u64(4), "part":packet[2], "parts":packet[3], "players":states}
