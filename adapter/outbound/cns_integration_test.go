//go:build integration

package outbound

import (
	"bytes"
	"io"
	"net"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestCNSOutboundTCP(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				_, _ = io.Copy(c, c)
			}(c)
		}
	}()
	_, port, _ := net.SplitHostPort(ln.Addr().String())
	echoPort := atoi(t, port)

	proxy, err := NewCNS(CNSOption{
		Server:   "127.0.0.1",
		Port:     1254,
		Password: "666",
		Name:     "cns-test",
		UDP:      true,
	})
	if err != nil {
		t.Fatal(err)
	}

	metadata := &C.Metadata{Host: "127.0.0.1", DstPort: uint16(echoPort)}
	conn, err := proxy.DialContext(t.Context(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	payload := []byte("outbound tcp payload via cns proxy")
	if _, err := conn.Write(payload); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, len(payload))
	if _, err := io.ReadFull(conn, buf); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(buf, payload) {
		t.Fatalf("echo mismatch: %q", buf)
	}
}

func atoi(t *testing.T, s string) int {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			t.Fatalf("invalid port: %s", s)
		}
		n = n*10 + int(c-'0')
	}
	return n
}
