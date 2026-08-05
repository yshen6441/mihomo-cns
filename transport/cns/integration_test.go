//go:build integration

package cns

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/netip"
	"testing"
	"time"
)

func startEchoTCP(t *testing.T) (string, func()) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
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
	return ln.Addr().String(), func() { _ = ln.Close() }
}

func startEchoUDP(t *testing.T) (*net.UDPAddr, func()) {
	pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		buf := make([]byte, 2048)
		for {
			n, raddr, err := pc.ReadFromUDP(buf)
			if err != nil {
				return
			}
			_, _ = pc.WriteToUDP(buf[:n], raddr)
		}
	}()
	return pc.LocalAddr().(*net.UDPAddr), func() { _ = pc.Close() }
}

func TestIntegrationTCP(t *testing.T) {
	echoAddr, closeEcho := startEchoTCP(t)
	defer closeEcho()

	conn, err := net.Dial("tcp", "127.0.0.1:1254")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	if err := WriteTunnelHeader(conn, "Host", echoAddr, "", []byte("666")); err != nil {
		t.Fatal(err)
	}
	if err := ReadTunnelResponse(conn); err != nil {
		t.Fatal(err)
	}

	tc := NewTunnelConn(conn, []byte("666"))
	payload := []byte("integration tcp payload over cns tunnel")
	if _, err := tc.Write(payload); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, len(payload))
	if _, err := io.ReadFull(tc, buf); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(buf, payload) {
		t.Fatalf("tcp echo mismatch: %q", buf)
	}
}

func TestIntegrationUDP(t *testing.T) {
	echoAddr, closeEcho := startEchoUDP(t)
	defer closeEcho()

	conn, err := net.Dial("tcp", "127.0.0.1:1254")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	if err := WriteTunnelHeader(conn, "Host", "127.0.0.1:1", "httpUDP", []byte("666")); err != nil {
		t.Fatal(err)
	}
	if err := ReadTunnelResponse(conn); err != nil {
		t.Fatal(err)
	}

	pc := NewPacketConn(conn, []byte("666"))
	dst := netip.MustParseAddrPort("127.0.0.1:" + fmt.Sprint(echoAddr.Port))
	payload := []byte("integration udp payload over cns tunnel")

	done := make(chan error, 1)
	go func() {
		_, err := pc.WriteTo(payload, net.UDPAddrFromAddrPort(dst))
		done <- err
	}()
	if err := <-done; err != nil {
		t.Fatal(err)
	}

	if err := pc.SetReadDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 2048)
	n, addr, err := pc.ReadFrom(buf)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(buf[:n], payload) {
		t.Fatalf("udp echo mismatch: %q", buf[:n])
	}
	if addr.String() != dst.String() {
		t.Fatalf("addr mismatch: %s != %s", addr, dst)
	}
}
