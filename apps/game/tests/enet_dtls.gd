extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var certificate := X509Certificate.new()
	assert(certificate.load(OS.get_environment("DO_GAME_TLS_CA")) == OK)
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1)
	var port := arguments[0].to_int()
	assert(port > 0)
	for hostname in ["localhost", "wrong.example"]:
		var host := ENetConnection.new()
		assert(host.create_host(1,2) == OK)
		# First case has no trust anchor; second trusts the CA but has the wrong name.
		var options := TLSOptions.client() if hostname == "localhost" else TLSOptions.client(certificate)
		assert(host.dtls_client_setup(hostname,options) == OK)
		assert(host.connect_to_host("127.0.0.1",port,2) != null)
		var deadline := Time.get_ticks_msec()+3000
		while Time.get_ticks_msec() < deadline:
			var event := host.service(0)
			assert(event[0] != ENetConnection.EVENT_CONNECT, "DTLS verification must reject untrusted certificate or wrong hostname")
			await process_frame
		host.destroy()
	print("PASS: DTLS rejects untrusted certificate and hostname mismatch")
	quit()
