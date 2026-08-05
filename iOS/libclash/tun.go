package libclash

import (
	"fmt"
	"net"
	"net/netip"
	"strings"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

const defaultMTU = 9000

type tunOptionsImpl struct {
	autoRoute           bool
	mtu                 int
	dnsServer           string
	inet4               []*IPPrefix
	inet4Route          []*IPPrefix
	inet4RouteExclude   []*IPPrefix
	inet6               []*IPPrefix
	inet6Route          []*IPPrefix
	inet6RouteExclude   []*IPPrefix
	httpProxyEnabled    bool
	httpProxyServer     string
	httpProxyPort       int
	httpProxyBypass     []string
	httpProxyMatch      []string
}

func (o *tunOptionsImpl) GetAutoRoute() bool                   { return o.autoRoute }
func (o *tunOptionsImpl) GetMTU() int                          { return o.mtu }
func (o *tunOptionsImpl) GetDNSServerAddress() *DNSAddress     { return NewDNSAddress(o.dnsServer) }
func (o *tunOptionsImpl) GetInet4Address() IPPrefixIterator     { return &ipPrefixIteratorImpl{items: o.inet4} }
func (o *tunOptionsImpl) GetInet4RouteAddress() IPPrefixIterator {
	return &ipPrefixIteratorImpl{items: o.inet4Route}
}
func (o *tunOptionsImpl) GetInet4RouteExcludeAddress() IPPrefixIterator {
	return &ipPrefixIteratorImpl{items: o.inet4RouteExclude}
}
func (o *tunOptionsImpl) GetInet6Address() IPPrefixIterator { return &ipPrefixIteratorImpl{items: o.inet6} }
func (o *tunOptionsImpl) GetInet6RouteAddress() IPPrefixIterator {
	return &ipPrefixIteratorImpl{items: o.inet6Route}
}
func (o *tunOptionsImpl) GetInet6RouteExcludeAddress() IPPrefixIterator {
	return &ipPrefixIteratorImpl{items: o.inet6RouteExclude}
}
func (o *tunOptionsImpl) IsHTTPProxyEnabled() bool         { return o.httpProxyEnabled }
func (o *tunOptionsImpl) GetHTTPProxyServer() string       { return o.httpProxyServer }
func (o *tunOptionsImpl) GetHTTPProxyServerPort() int      { return o.httpProxyPort }
func (o *tunOptionsImpl) GetHTTPProxyBypassDomain() StringIterator {
	return &stringIteratorImpl{items: o.httpProxyBypass}
}
func (o *tunOptionsImpl) GetHTTPProxyMatchDomain() StringIterator {
	return &stringIteratorImpl{items: o.httpProxyMatch}
}

func prefixToIPPrefix(p netip.Prefix) *IPPrefix {
	addr := p.Masked().Addr()
	if addr.Is4() {
		mask := net.IP(net.CIDRMask(p.Bits(), 32)).String()
		return NewIPPrefix(addr.String(), mask, p.Bits())
	}
	return NewIPPrefix(addr.String(), "", p.Bits())
}

func prefixesToIPPrefixes(prefixes []netip.Prefix) []*IPPrefix {
	result := make([]*IPPrefix, 0, len(prefixes))
	for _, p := range prefixes {
		result = append(result, prefixToIPPrefix(p))
	}
	return result
}

func startTun(tunCfg *LC.Tun, cfg *config.Config) error {
	dnsServer := "0.0.0.0"
	if cfg.DNS.FakeIPRange.IsValid() {
		dnsServer = cfg.DNS.FakeIPRange.Addr().String()
	}

	mtu := int(tunCfg.MTU)
	if mtu <= 0 {
		mtu = defaultMTU
	}

	httpProxyEnabled := cfg.General.MixedPort > 0 || cfg.General.Port > 0
	httpProxyPort := cfg.General.MixedPort
	if httpProxyPort <= 0 {
		httpProxyPort = cfg.General.Port
	}

	opts := &tunOptionsImpl{
		autoRoute:         tunCfg.AutoRoute,
		mtu:               mtu,
		dnsServer:         dnsServer,
		inet4:             prefixesToIPPrefixes(tunCfg.Inet4Address),
		inet4Route:        prefixesToIPPrefixes(tunCfg.Inet4RouteAddress),
		inet4RouteExclude: prefixesToIPPrefixes(tunCfg.Inet4RouteExcludeAddress),
		inet6:             prefixesToIPPrefixes(tunCfg.Inet6Address),
		inet6Route:        prefixesToIPPrefixes(tunCfg.Inet6RouteAddress),
		inet6RouteExclude: prefixesToIPPrefixes(tunCfg.Inet6RouteExcludeAddress),
		httpProxyEnabled:  httpProxyEnabled,
		httpProxyServer:   "127.0.0.1",
		httpProxyPort:     httpProxyPort,
	}

	fd, err := platform.OpenTun(opts)
	if err != nil {
		return fmt.Errorf("open tun: %w", err)
	}
	if fd <= 0 {
		return fmt.Errorf("invalid tun fd %d", fd)
	}

	stack := tunCfg.Stack
	if _, ok := C.StackTypeMapping[strings.ToLower(string(stack))]; !ok {
		stack = C.TunSystem
	}

	tunOptions := LC.Tun{
		Enable:              true,
		Device:              sing_tun.InterfaceName,
		Stack:               stack,
		DNSHijack:           tunCfg.DNSHijack,
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        tunCfg.Inet4Address,
		Inet6Address:        tunCfg.Inet6Address,
		MTU:                 uint32(mtu),
		FileDescriptor:      int(fd),
		UDPTimeout:          tunCfg.UDPTimeout,
		RecvMsgX:            tunCfg.RecvMsgX,
		SendMsgX:            tunCfg.SendMsgX,
	}

	log.Infoln("[LIBCLASH] start tun, fd: %d, mtu: %d, stack: %s", fd, mtu, stack)

	listener, err := sing_tun.New(tunOptions, tunnel.Tunnel)
	if err != nil {
		return fmt.Errorf("sing tun: %w", err)
	}

	tunIO = listener
	return nil
}
