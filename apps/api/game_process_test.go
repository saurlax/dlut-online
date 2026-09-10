//go:build integration

package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"sync/atomic"
	"testing"
	"time"
)

// Optional two-client smoke check; no capacity or sustained-load scenario.
func TestENetSmoke(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	project, err := filepath.Abs("../game")
	if err != nil {
		t.Fatal(err)
	}
	reserved, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reserved.LocalAddr().String()
	reserved.Close()
	_, port, _ := net.SplitHostPort(address)
	service := randomID()
	api := httptest.NewServer(router(gameConfig{apiKey: service}, "enet://"+address))
	defer api.Close()
	server := exec.CommandContext(ctx, "godot", "--headless", "--path", project, "scenes/server.tscn")
	server.Env = append(os.Environ(), "DO_ENV=development", "DO_GAME_TLS_CERT=", "DO_GAME_TLS_KEY=", "DO_GAME_SERVER_PORT="+port, "DO_API_KEY="+service, "DO_API_SERVER_URL="+api.URL)
	var serverOutput bytes.Buffer
	server.Stdout, server.Stderr = &serverOutput, &serverOutput
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		server.Process.Kill()
		server.Wait()
		if t.Failed() {
			t.Log(serverOutput.String())
		}
	}()
	client := exec.CommandContext(ctx, "godot", "--headless", "--path", project, "--script", "tests/enet_protocol.gd")
	client.Env = append(os.Environ(), "DO_ENV=development", "DO_API_SERVER_URL="+api.URL)
	output, err := client.CombinedOutput()
	if err != nil || bytes.Contains(output, []byte("SCRIPT ERROR")) || !bytes.Contains(output, []byte("PASS: ENet smoke")) {
		t.Fatalf("smoke: %v\n%s", err, output)
	}
	t.Log(string(output))
}

// Runs the real Godot transport through a bounded UDP relay with delay, loss and reordering.
func TestENetClientUnderLoss(t *testing.T) {
	project, _ := filepath.Abs("../game")
	reserved, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reserved.LocalAddr().String()
	reserved.Close()
	upstream, err := net.ResolveUDPAddr("udp", address)
	if err != nil {
		t.Fatal(err)
	}
	relay, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.ParseIP("127.0.0.1")})
	if err != nil {
		t.Fatal(err)
	}
	defer relay.Close()
	service := randomID()
	api := httptest.NewServer(router(gameConfig{apiKey: service}, "enet://"+relay.LocalAddr().String()))
	defer api.Close()
	_, port, _ := net.SplitHostPort(address)
	server := exec.Command("godot", "--headless", "--path", project, "scenes/server.tscn")
	server.Env = append(os.Environ(), "DO_ENV=development", "DO_GAME_TLS_CERT=", "DO_GAME_TLS_KEY=", "DO_GAME_SERVER_PORT="+port, "DO_API_KEY="+service, "DO_API_SERVER_URL="+api.URL)
	var serverOutput bytes.Buffer
	server.Stdout = &serverOutput
	server.Stderr = &serverOutput
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		server.Process.Kill()
		server.Wait()
		if t.Failed() {
			t.Log(serverOutput.String())
		}
	}()
	type packet struct {
		data        []byte
		destination *net.UDPAddr
		due         time.Time
	}
	queue := make(chan packet, 256)
	stopped := make(chan struct{})
	defer close(stopped)
	go func() {
		ticker := time.NewTicker(5 * time.Millisecond)
		defer ticker.Stop()
		pending := make([]packet, 0, 256)
		for {
			select {
			case <-stopped:
				return
			case p := <-queue:
				if len(pending) < 256 {
					pending = append(pending, p)
				}
			case now := <-ticker.C:
				kept := pending[:0]
				for _, p := range pending {
					if !now.Before(p.due) {
						relay.WriteToUDP(p.data, p.destination)
					} else {
						kept = append(kept, p)
					}
				}
				pending = kept
			}
		}
	}()
	go func() {
		var client *net.UDPAddr
		counter := 0
		for {
			buffer := make([]byte, 65536)
			n, from, e := relay.ReadFromUDP(buffer)
			if e != nil {
				return
			}
			var to *net.UDPAddr
			if from.String() == upstream.String() {
				to = client
			} else {
				client = from
				to = upstream
			}
			if to == nil {
				continue
			}
			counter++
			if counter%37 == 0 {
				continue
			} // deterministic ~2.7% datagram loss
			delay := 75 * time.Millisecond
			if counter%11 == 0 {
				delay += 90 * time.Millisecond
			} // reorder selected datagrams
			select {
			case queue <- packet{buffer[:n], to, time.Now().Add(delay)}:
			case <-stopped:
				return
			default:
			}
		}
	}()
	// ENet connection attempts retry while the server starts.
	client := exec.Command("godot", "--headless", "--path", project, "--script", "tests/player_network.gd")
	client.Env = append(os.Environ(), "DO_ENV=development", "DO_API_SERVER_URL="+api.URL)
	output, err := client.CombinedOutput()
	if err != nil || bytes.Contains(output, []byte("SCRIPT ERROR")) || !bytes.Contains(output, []byte("PASS:")) {
		t.Fatalf("client: %v\n%s", err, output)
	}
	t.Log("150ms RTT, 2.7% loss, reordered datagrams; server port " + strconv.Itoa(upstream.Port))
}

func TestENetHTTPRestart(t *testing.T) {
	project, _ := filepath.Abs("../game")
	reserved, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reserved.LocalAddr().String()
	reserved.Close()
	service := randomID()
	config := gameConfig{apiKey: service}
	var current atomic.Value
	current.Store(router(config, "enet://"+address))
	var outage atomic.Bool
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/test/outage" {
			outage.Store(true)
			io.WriteString(w, `{}`)
			return
		}
		if r.URL.Path == "/test/restart" {
			current.Store(router(config, "enet://"+address))
			outage.Store(false)
			io.WriteString(w, `{}`)
			return
		}
		if outage.Load() && (r.URL.Path == "/api/v1/game/tickets/consume" || r.URL.Path == "/api/v1/game/register" || r.URL.Path == "/api/v1/game/presence") {
			http.Error(w, "unavailable", 503)
			return
		}
		current.Load().(http.Handler).ServeHTTP(w, r)
	}))
	defer api.Close()
	_, port, _ := net.SplitHostPort(address)
	server := exec.Command("godot", "--headless", "--path", project, "scenes/server.tscn")
	server.Env = append(os.Environ(), "DO_ENV=development", "DO_GAME_TLS_CERT=", "DO_GAME_TLS_KEY=", "DO_GAME_SERVER_PORT="+port, "DO_API_KEY="+service, "DO_API_SERVER_URL="+api.URL)
	var output bytes.Buffer
	server.Stdout = &output
	server.Stderr = &output
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		server.Process.Kill()
		server.Wait()
		if t.Failed() {
			t.Log(output.String())
		}
	}()
	client := exec.Command("godot", "--headless", "--path", project, "--script", "tests/enet_http_fault.gd")
	client.Env = append(os.Environ(), "DO_ENV=development", "DO_API_SERVER_URL="+api.URL)
	result, err := client.CombinedOutput()
	if err != nil || bytes.Contains(result, []byte("SCRIPT ERROR")) || !bytes.Contains(result, []byte("PASS:")) {
		t.Fatalf("%v\n%s", err, result)
	}
}

func TestENetDTLS(t *testing.T) {
	project, _ := filepath.Abs("../game")
	reserved, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reserved.LocalAddr().String()
	reserved.Close()
	_, port, _ := net.SplitHostPort(address)
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "localhost"}, DNSNames: []string{"localhost"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	certPath := filepath.Join(dir, "cert.pem")
	keyPath := filepath.Join(dir, "key.pem")
	if err = os.WriteFile(certPath, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0600); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(keyPath, pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)}), 0600); err != nil {
		t.Fatal(err)
	}
	service := randomID()
	api := httptest.NewServer(router(gameConfig{environment: "production", apiKey: service}, "enets://localhost:"+port))
	defer api.Close()
	server := exec.Command("godot", "--headless", "--path", project, "scenes/server.tscn")
	server.Env = append(os.Environ(), "DO_ENV=production", "DO_GAME_TLS_CERT="+certPath, "DO_GAME_TLS_KEY="+keyPath, "DO_GAME_SERVER_PORT="+port, "DO_API_KEY="+service, "DO_API_SERVER_URL="+api.URL)
	var output bytes.Buffer
	server.Stdout = &output
	server.Stderr = &output
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		server.Process.Kill()
		server.Wait()
		if t.Failed() {
			t.Log(output.String())
		}
	}()
	for _, script := range []string{"tests/campus_travel.gd", "tests/enet_dtls.gd"} {
		args := []string{"--headless", "--path", project, "--script", script}
		if script == "tests/enet_dtls.gd" {
			args = append(args, "--", port)
		}
		client := exec.Command("godot", args...)
		client.Env = append(os.Environ(), "DO_ENV=production", "DO_API_SERVER_URL="+api.URL, "DO_GAME_TLS_CA="+certPath)
		result, err := client.CombinedOutput()
		if err != nil || bytes.Contains(result, []byte("SCRIPT ERROR")) || !bytes.Contains(result, []byte("PASS:")) {
			t.Fatalf("%s: %v\n%s", script, err, result)
		}
	}
}
