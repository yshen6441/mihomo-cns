package cns

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"sync"

	"github.com/metacubex/mihomo/common/pool"
)

const (
	IPv4HeaderLen = 12
	IPv6HeaderLen = 24
)

// XorStream implements the CuteBi stream XOR cipher used by CNS.
type XorStream struct {
	password []byte
	sub      int
}

func NewXorStream(password []byte) *XorStream {
	return &XorStream{password: password}
}

func (x *XorStream) XorCrypt(data []byte) {
	if len(x.password) == 0 {
		return
	}
	for i := range data {
		data[i] ^= x.password[x.sub] | byte(x.sub)
		x.sub++
		if x.sub == len(x.password) {
			x.sub = 0
		}
	}
}

// EncryptHost encrypts a host with Base64(XOR(host + 0x00)).
func EncryptHost(host string, password []byte) (string, error) {
	buf := make([]byte, len(host)+1)
	copy(buf, host)
	buf[len(host)] = 0
	NewXorStream(password).XorCrypt(buf)
	return base64.StdEncoding.EncodeToString(buf), nil
}

// EncodePacket encodes a UDP packet into the httpUDP protocol (without XOR).
func EncodePacket(dst netip.AddrPort, data []byte) []byte {
	if dst.Addr().Is4() {
		buf := make([]byte, IPv4HeaderLen+len(data))
		binary.LittleEndian.PutUint16(buf[:2], uint16(IPv4HeaderLen+len(data)-2))
		buf[2], buf[3], buf[4], buf[5] = 0, 0, 0, 1
		ip4 := dst.Addr().As4()
		copy(buf[6:10], ip4[:])
		binary.BigEndian.PutUint16(buf[10:12], dst.Port())
		copy(buf[12:], data)
		return buf
	}
	buf := make([]byte, IPv6HeaderLen+len(data))
	binary.LittleEndian.PutUint16(buf[:2], uint16(IPv6HeaderLen+len(data)-2))
	buf[2], buf[3], buf[4], buf[5] = 0, 0, 0, 3
	ip16 := dst.Addr().As16()
	copy(buf[6:22], ip16[:])
	binary.BigEndian.PutUint16(buf[22:24], dst.Port())
	copy(buf[24:], data)
	return buf
}

// DecodePacket parses an httpUDP protocol packet (already decrypted).
// buf must be the packet body without the 2-byte length prefix.
func DecodePacket(buf []byte) (netip.AddrPort, []byte, error) {
	if len(buf) < 8 {
		return netip.AddrPort{}, nil, errors.New("cns: packet too short")
	}
	switch {
	case buf[0] == 0 && buf[1] == 0 && buf[2] == 0 && buf[3] == 1:
		if len(buf) < IPv4HeaderLen-2 {
			return netip.AddrPort{}, nil, errors.New("cns: ipv4 packet too short")
		}
		var ip4 [4]byte
		copy(ip4[:], buf[4:8])
		port := binary.BigEndian.Uint16(buf[8:10])
		return netip.AddrPortFrom(netip.AddrFrom4(ip4), port), buf[10:], nil
	case buf[0] == 0 && buf[1] == 0 && buf[2] == 0 && buf[3] == 3:
		if len(buf) < IPv6HeaderLen-2 {
			return netip.AddrPort{}, nil, errors.New("cns: ipv6 packet too short")
		}
		var ip16 [16]byte
		copy(ip16[:], buf[4:20])
		port := binary.BigEndian.Uint16(buf[20:22])
		return netip.AddrPortFrom(netip.AddrFrom16(ip16), port), buf[22:], nil
	default:
		return netip.AddrPort{}, nil, errors.New("cns: unknown packet type")
	}
}

// WriteTunnelHeader writes the HTTP tunnel request header to the server.
// proxyKey must match the server's proxy_key (default "Host").
// When password is set, host is encrypted as Base64(XOR(host + 0x00)).
func WriteTunnelHeader(w io.Writer, proxyKey, host, udpFlag string, password []byte) error {
	var buf bytes.Buffer
	hostValue := host
	if len(password) != 0 {
		encHost, err := EncryptHost(host, password)
		if err != nil {
			return err
		}
		hostValue = encHost
	}
	buf.WriteString("GET / HTTP/1.1\r\n")
	buf.WriteString(proxyKey)
	buf.WriteString(": ")
	buf.WriteString(hostValue)
	buf.WriteString("\r\n")
	if udpFlag != "" {
		buf.WriteString("X-UDP: ")
		buf.WriteString(udpFlag)
		buf.WriteString("\r\n")
	}
	buf.WriteString("\r\n")
	_, err := w.Write(buf.Bytes())
	return err
}

// ReadTunnelResponse reads and validates the server HTTP tunnel response.
func ReadTunnelResponse(r io.Reader) error {
	buf := make([]byte, 0, 1024)
	tmp := make([]byte, 512)
	for {
		n, err := r.Read(tmp)
		if err != nil {
			return err
		}
		buf = append(buf, tmp[:n]...)
		if bytes.Contains(buf, []byte("\r\n\r\n")) {
			break
		}
		if len(buf) > 65536 {
			return errors.New("cns: tunnel response header too large")
		}
	}
	if !bytes.HasPrefix(buf, []byte("HTTP/1.1 200")) && !bytes.Contains(buf, []byte(" 200 ")) {
		return fmt.Errorf("cns: unexpected tunnel response: %q", buf)
	}
	return nil
}

// TunnelConn is a TCP tunnel connection with CuteBi stream XOR.
type TunnelConn struct {
	net.Conn
	rs *XorStream
	ws *XorStream
}

func NewTunnelConn(conn net.Conn, password []byte) net.Conn {
	return &TunnelConn{Conn: conn, rs: NewXorStream(password), ws: NewXorStream(password)}
}

func (c *TunnelConn) Read(b []byte) (int, error) {
	n, err := c.Conn.Read(b)
	if n > 0 {
		c.rs.XorCrypt(b[:n])
	}
	return n, err
}

func (c *TunnelConn) Write(b []byte) (int, error) {
	if len(c.ws.password) == 0 {
		return c.Conn.Write(b)
	}
	buf := pool.GetBuffer()
	defer pool.PutBuffer(buf)
	buf.Write(b)
	c.ws.XorCrypt(buf.Bytes())
	return c.Conn.Write(buf.Bytes())
}

// PacketConn is a UDP session carried over a TCP connection using httpUDP.
type PacketConn struct {
	net.Conn
	rs    *XorStream
	ws    *XorStream
	rlock sync.Mutex
	wlock sync.Mutex
}

func NewPacketConn(conn net.Conn, password []byte) *PacketConn {
	return &PacketConn{Conn: conn, rs: NewXorStream(password), ws: NewXorStream(password)}
}

func (pc *PacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	pc.wlock.Lock()
	defer pc.wlock.Unlock()

	dst, err := netip.ParseAddrPort(addr.String())
	if err != nil {
		return 0, err
	}
	pkt := EncodePacket(dst, b)
	pc.ws.XorCrypt(pkt)
	if _, err := pc.Conn.Write(pkt); err != nil {
		return 0, err
	}
	return len(b), nil
}

func (pc *PacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	pc.rlock.Lock()
	defer pc.rlock.Unlock()

	head := make([]byte, 2)
	if _, err := io.ReadFull(pc.Conn, head); err != nil {
		return 0, nil, err
	}
	pc.rs.XorCrypt(head)
	pkgLen := int(binary.LittleEndian.Uint16(head))
	if pkgLen < IPv4HeaderLen-2 || pkgLen > 65535 {
		return 0, nil, errors.New("cns: invalid packet length")
	}
	pkt := make([]byte, pkgLen)
	if _, err := io.ReadFull(pc.Conn, pkt); err != nil {
		return 0, nil, err
	}
	pc.rs.XorCrypt(pkt)
	dst, data, err := DecodePacket(pkt)
	if err != nil {
		return 0, nil, err
	}
	if len(b) < len(data) {
		data = data[:len(b)]
	}
	n := copy(b, data)
	return n, net.UDPAddrFromAddrPort(dst), nil
}
