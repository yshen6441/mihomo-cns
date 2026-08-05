package outbound

import (
	"context"
	"fmt"
	"net"
	"strconv"

	N "github.com/metacubex/mihomo/common/net"
	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/transport/cns"

	"github.com/metacubex/tls"
)

type CNS struct {
	*Base
	dialer    C.Dialer
	option    *CNSOption
	password  []byte
	proxyKey  string
	udpFlag   string
	tlsConfig *tls.Config
}

type CNSOption struct {
	BasicOption
	Name            string `proxy:"name"`
	Server          string `proxy:"server"`
	Port            int    `proxy:"port"`
	Password        string `proxy:"password,omitempty"`
	ProxyKey        string `proxy:"key,omitempty"`
	UDPFlag         string `proxy:"flag,omitempty"`
	UDP             bool   `proxy:"udp,omitempty"`
	TLS             bool   `proxy:"tls,omitempty"`
	SNI             string `proxy:"sni,omitempty"`
	SkipCertVerify  bool   `proxy:"skip-cert-verify,omitempty"`
	NameCertVerify  string `proxy:"name-cert-verify,omitempty"`
	Fingerprint     string `proxy:"fingerprint,omitempty"`
	Certificate     string `proxy:"certificate,omitempty"`
	PrivateKey      string `proxy:"private-key,omitempty"`
}

func (c *CNS) dialServer(ctx context.Context) (net.Conn, error) {
	conn, err := c.dialer.DialContext(ctx, "tcp", c.addr)
	if err != nil {
		return nil, fmt.Errorf("%s connect error: %w", c.addr, err)
	}
	if c.tlsConfig != nil {
		conn = tls.Client(conn, c.tlsConfig)
	}
	return conn, nil
}

func (c *CNS) tunnelHandshake(ctx context.Context, conn net.Conn, host string, udp bool) (err error) {
	if ctx.Done() != nil {
		done := N.SetupContextForConn(ctx, conn)
		defer done(&err)
	}
	udpFlag := ""
	if udp {
		udpFlag = c.udpFlag
	}
	if err := cns.WriteTunnelHeader(conn, c.proxyKey, host, udpFlag, c.password); err != nil {
		return err
	}
	return cns.ReadTunnelResponse(conn)
}

// DialContext implements C.ProxyAdapter
func (c *CNS) DialContext(ctx context.Context, metadata *C.Metadata) (_ C.Conn, err error) {
	conn, err := c.dialServer(ctx)
	if err != nil {
		return nil, err
	}
	defer func(conn net.Conn) {
		safeConnClose(conn, err)
	}(conn)

	host := c.targetHost(metadata)
	if err = c.tunnelHandshake(ctx, conn, host, false); err != nil {
		return nil, err
	}

	return NewConn(cns.NewTunnelConn(conn, c.password), c), nil
}

// ListenPacketContext implements C.ProxyAdapter
func (c *CNS) ListenPacketContext(ctx context.Context, metadata *C.Metadata) (_ C.PacketConn, err error) {
	conn, err := c.dialServer(ctx)
	if err != nil {
		return nil, err
	}
	defer func(conn net.Conn) {
		safeConnClose(conn, err)
	}(conn)

	if err = c.tunnelHandshake(ctx, conn, "127.0.0.1:1", true); err != nil {
		return nil, err
	}

	pc := cns.NewPacketConn(conn, c.password)
	return NewPacketConn(pc, c), nil
}

func (c *CNS) targetHost(metadata *C.Metadata) string {
	host := metadata.Host
	if host == "" {
		host = metadata.DstIP.String()
	}
	return net.JoinHostPort(host, strconv.Itoa(int(metadata.DstPort)))
}

// ProxyInfo implements C.ProxyAdapter
func (c *CNS) ProxyInfo() C.ProxyInfo {
	info := c.Base.ProxyInfo()
	info.DialerProxy = c.option.DialerProxy
	return info
}

func NewCNS(option CNSOption) (*CNS, error) {
	if option.Server == "" || option.Port <= 0 || option.Port > 0xffff {
		return nil, fmt.Errorf("cns %s requires a valid server and port", option.Name)
	}
	if option.ProxyKey == "" {
		option.ProxyKey = "Meng"
	}
	if option.UDPFlag == "" {
		option.UDPFlag = "httpUDP"
	}
	if option.SNI == "" {
		option.SNI = option.Server
	}

	addr := net.JoinHostPort(option.Server, strconv.Itoa(option.Port))
	c := &CNS{
		Base: NewBase(BaseOption{
			Name:         option.Name,
			Addr:         addr,
			Type:         C.CNS,
			ProviderName: option.ProviderName,
			UDP:          option.UDP,
			TFO:          option.TFO,
			MPTCP:        option.MPTCP,
			Interface:    option.Interface,
			RoutingMark:  option.RoutingMark,
			Prefer:       option.IPVersion,
		}),
		option:   &option,
		password: []byte(option.Password),
		proxyKey: option.ProxyKey,
		udpFlag:  option.UDPFlag,
	}
	c.dialer = option.NewDialer(c.DialOptions())

	if option.TLS {
		tlsConfig, err := ca.GetTLSConfig(ca.Option{
			TLSConfig: &tls.Config{
				ServerName:         option.SNI,
				MinVersion:         tls.VersionTLS12,
				InsecureSkipVerify: option.SkipCertVerify,
				NextProtos:         []string{"http/1.1"},
			},
			NameCertVerify: option.NameCertVerify,
			Fingerprint:    option.Fingerprint,
			Certificate:    option.Certificate,
			PrivateKey:     option.PrivateKey,
		})
		if err != nil {
			return nil, err
		}
		c.tlsConfig = tlsConfig
	}

	return c, nil
}
