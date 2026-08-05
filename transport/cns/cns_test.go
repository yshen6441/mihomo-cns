package cns

import (
	"bytes"
	"encoding/base64"
	"io"
	"net"
	"net/netip"
	"testing"
)

func TestEncryptHostDecrypt(t *testing.T) {
	password := []byte("666")
	host := "example.com:443"

	enc, err := EncryptHost(host, password)
	if err != nil {
		t.Fatal(err)
	}

	dec, err := base64.StdEncoding.DecodeString(enc)
	if err != nil {
		t.Fatal(err)
	}
	NewXorStream(password).XorCrypt(dec)
	if len(dec) != len(host)+1 || dec[len(dec)-1] != 0 {
		t.Fatalf("trailing zero check failed: %v", dec)
	}
	if string(dec[:len(dec)-1]) != host {
		t.Fatalf("decrypt host mismatch: %q", dec)
	}
}

func TestXorStream(t *testing.T) {
	password := []byte("12345")
	origin := []byte("hello world, this is a test payload with some length")
	data := append([]byte{}, origin...)

	a := NewXorStream(password)
	b := NewXorStream(password)
	a.XorCrypt(data)
	if bytes.Equal(data, origin) {
		t.Fatal("xor crypt did not change data")
	}
	b.XorCrypt(data)
	if !bytes.Equal(data, origin) {
		t.Fatal("xor round trip failed")
	}
}

func TestXorStreamNoPassword(t *testing.T) {
	data := []byte("should not change")
	origin := append([]byte{}, data...)
	NewXorStream(nil).XorCrypt(data)
	if !bytes.Equal(data, origin) {
		t.Fatal("no-password xor should be a no-op")
	}
}

func TestEncodeDecodeIPv4(t *testing.T) {
	dst := netip.MustParseAddrPort("1.2.3.4:8080")
	data := []byte("udp payload data")
	pkt := EncodePacket(dst, data)

	gotDst, gotData, err := DecodePacket(pkt[2:])
	if err != nil {
		t.Fatal(err)
	}
	if gotDst != dst {
		t.Fatalf("addr mismatch: %v != %v", gotDst, dst)
	}
	if !bytes.Equal(gotData, data) {
		t.Fatalf("data mismatch: %v != %v", gotData, data)
	}
}

func TestEncodeDecodeIPv6(t *testing.T) {
	dst := netip.MustParseAddrPort("[2001:db8::1]:53")
	data := []byte("dns query data")
	pkt := EncodePacket(dst, data)

	gotDst, gotData, err := DecodePacket(pkt[2:])
	if err != nil {
		t.Fatal(err)
	}
	if gotDst != dst {
		t.Fatalf("addr mismatch: %v != %v", gotDst, dst)
	}
	if !bytes.Equal(gotData, data) {
		t.Fatalf("data mismatch: %v != %v", gotData, data)
	}
}

func TestTunnelConnRoundTrip(t *testing.T) {
	password := []byte("secret")
	payload := []byte("tcp tunnel data over xor stream")

	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()

	clientConn := NewTunnelConn(client, password)
	serverConn := NewTunnelConn(server, password)

	go func() {
		_, _ = serverConn.Write(payload)
	}()

	buf := make([]byte, len(payload))
	if _, err := io.ReadFull(clientConn, buf); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(buf, payload) {
		t.Fatalf("payload mismatch: %q != %q", buf, payload)
	}
}

func TestPacketConnRoundTrip(t *testing.T) {
	password := []byte("pwd")
	dst := netip.MustParseAddrPort("10.0.0.1:9999")
	payload := []byte("udp over tcp httpUDP payload")

	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()

	clientConn := NewPacketConn(client, password)
	serverConn := NewPacketConn(server, password)

	errCh := make(chan error, 1)
	go func() {
		_, err := serverConn.WriteTo(payload, net.UDPAddrFromAddrPort(dst))
		errCh <- err
	}()

	buf := make([]byte, 2048)
	n, addr, err := clientConn.ReadFrom(buf)
	if err != nil {
		t.Fatal(err)
	}
	if err := <-errCh; err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(buf[:n], payload) {
		t.Fatalf("payload mismatch: %q != %q", buf[:n], payload)
	}
	if got, want := addr.String(), dst.String(); got != want {
		t.Fatalf("addr mismatch: %s != %s", got, want)
	}
}

func TestWriteTunnelHeader(t *testing.T) {
	var buf bytes.Buffer
	if err := WriteTunnelHeader(&buf, "Host", "example.com:443", "", []byte("666")); err != nil {
		t.Fatal(err)
	}
	header := buf.String()
	if !bytes.HasPrefix([]byte(header), []byte("GET / HTTP/1.1\r\nHost: ")) {
		t.Fatalf("unexpected header: %q", header)
	}
	if !bytes.HasSuffix([]byte(header), []byte("\r\n\r\n")) {
		t.Fatalf("unexpected header end: %q", header)
	}
}

func TestReadTunnelResponse(t *testing.T) {
	ok := bytes.NewBufferString("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nServer: CuteBi Network Tunnel\r\n\r\n")
	if err := ReadTunnelResponse(ok); err != nil {
		t.Fatal(err)
	}

	bad := bytes.NewBufferString("HTTP/1.1 404 Not Found\r\n\r\n")
	if err := ReadTunnelResponse(bad); err == nil {
		t.Fatal("expected error on 404")
	}
}
