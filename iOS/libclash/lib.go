// Package libclash exposes a gomobile-friendly API that embeds the mihomo
// core (including the CNS protocol) for the Clash Mi iOS client.
package libclash

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"time"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
	logrus "github.com/sirupsen/logrus"
)

var (
	mu       sync.Mutex
	platform PlatformInterface
	tunIO    io.Closer
)

// SetupOptions configures the core home directory and log output.
type SetupOptions struct {
	HomeDir   string
	LogFile   string
	ErrorFile string
}

// StartOptions points to the runtime config files.
type StartOptions struct {
	ConfigFile          string
	ConfigFilePatch     string
	ConfigFilePatchFinal string
}

// DNSAddress wraps a DNS server address handed to the tunnel interface.
type DNSAddress struct {
	value string
}

// NewDNSAddress creates a DNSAddress.
func NewDNSAddress(value string) *DNSAddress {
	return &DNSAddress{value: value}
}

// Value returns the wrapped address.
func (d *DNSAddress) Value() string {
	return d.value
}

// IPPrefix wraps an IP network prefix handed to the tunnel interface.
type IPPrefix struct {
	address string
	mask    string
	prefix  int
}

// NewIPPrefix creates an IPPrefix.
func NewIPPrefix(address string, mask string, prefix int) *IPPrefix {
	return &IPPrefix{address: address, mask: mask, prefix: prefix}
}

// Address returns the IP address.
func (p *IPPrefix) Address() string {
	return p.address
}

// Mask returns the IPv4 netmask.
func (p *IPPrefix) Mask() string {
	return p.mask
}

// Prefix returns the IPv6 prefix length.
func (p *IPPrefix) Prefix() int {
	return p.prefix
}

// IPPrefixIterator iterates over a collection of IPPrefix values.
type IPPrefixIterator interface {
	HasNext() bool
	Next() *IPPrefix
}

type ipPrefixIteratorImpl struct {
	items []*IPPrefix
	index int
}

func (it *ipPrefixIteratorImpl) HasNext() bool {
	return it.index < len(it.items)
}

func (it *ipPrefixIteratorImpl) Next() *IPPrefix {
	if it.index >= len(it.items) {
		return nil
	}
	item := it.items[it.index]
	it.index++
	return item
}

// StringIterator iterates over a collection of strings.
type StringIterator interface {
	HasNext() bool
	Next() string
}

type stringIteratorImpl struct {
	items []string
	index int
}

func (it *stringIteratorImpl) HasNext() bool {
	return it.index < len(it.items)
}

func (it *stringIteratorImpl) Next() string {
	if it.index >= len(it.items) {
		return ""
	}
	item := it.items[it.index]
	it.index++
	return item
}

// TunOptions describes the tunnel configuration for the NE extension. It is
// implemented in Go and read from the Swift side.
type TunOptions interface {
	GetAutoRoute() bool
	GetMTU() int
	GetDNSServerAddress() *DNSAddress
	GetInet4Address() IPPrefixIterator
	GetInet4RouteAddress() IPPrefixIterator
	GetInet4RouteExcludeAddress() IPPrefixIterator
	GetInet6Address() IPPrefixIterator
	GetInet6RouteAddress() IPPrefixIterator
	GetInet6RouteExcludeAddress() IPPrefixIterator
	IsHTTPProxyEnabled() bool
	GetHTTPProxyServer() string
	GetHTTPProxyServerPort() int
	GetHTTPProxyBypassDomain() StringIterator
	GetHTTPProxyMatchDomain() StringIterator
}

// PlatformInterface is implemented on the Swift side. The core uses it to
// open the TUN device provided by the NE extension.
type PlatformInterface interface {
	OpenTun(options TunOptions) (int32, error)
	FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (int32, error)
	PackageName(byUid int32) string
	ProtectFd(fd int32)
}

// Setup initializes the core home directory and log output.
func Setup(options *SetupOptions) error {
	if options == nil {
		return fmt.Errorf("setup options is nil")
	}
	if options.HomeDir != "" {
		constant.SetHomeDir(options.HomeDir)
	}
	if options.LogFile != "" {
		if err := redirectLog(options.LogFile); err != nil {
			log.Warnln("[LIBCLASH] open log file failed: %s", err.Error())
		}
	}
	if options.ErrorFile != "" {
		if err := redirectErr(options.ErrorFile); err != nil {
			log.Warnln("[LIBCLASH] open error file failed: %s", err.Error())
		}
	}
	log.Infoln("[LIBCLASH] setup complete, home dir: %s", options.HomeDir)
	return nil
}

// Start parses the config and starts the mihomo core together with the TUN.
func Start(options *StartOptions, tunInterface PlatformInterface) error {
	if options == nil {
		return fmt.Errorf("start options is nil")
	}
	if tunInterface == nil {
		return fmt.Errorf("tun interface is nil")
	}

	mu.Lock()
	defer mu.Unlock()

	platform = tunInterface

	data, err := loadConfigData(options)
	if err != nil {
		return err
	}

	rawCfg, err := config.UnmarshalRawConfig(data)
	if err != nil {
		return fmt.Errorf("parse raw config: %w", err)
	}

	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}

	enableTun := cfg.General.Tun.Enable
	// The core must not auto create a TUN device; the NE extension provides
	// the fd through the platform interface.
	cfg.General.Tun.Enable = false

	hub.ApplyConfig(cfg)

	if enableTun {
		if err := startTun(&cfg.General.Tun, cfg); err != nil {
			return fmt.Errorf("start tun: %w", err)
		}
	}

	log.Infoln("[LIBCLASH] core started")
	return nil
}

// Stop shuts down the TUN and the core.
func Stop() error {
	mu.Lock()
	defer mu.Unlock()

	if tunIO != nil {
		_ = tunIO.Close()
		tunIO = nil
	}
	platform = nil
	executor.Shutdown()
	log.Infoln("[LIBCLASH] core stopped")
	return nil
}

// GetConnections returns the connection snapshot JSON (clash /connections).
func GetConnections(showTraffic bool) string {
	snapshot := statistic.DefaultManager.Snapshot()
	if !showTraffic {
		// Strip per-connection traffic details when not requested.
		for _, c := range snapshot.Connections {
			c.UploadTotal.Store(0)
			c.DownloadTotal.Store(0)
		}
	}
	data, err := json.Marshal(snapshot)
	if err != nil {
		log.Errorln("[LIBCLASH] marshal connections failed: %s", err.Error())
		return "{}"
	}
	return string(data)
}

var (
	lastSnapshot *statistic.Snapshot
	lastTime     time.Time
	trafficMu    sync.Mutex
)

// GetTraffic returns the current traffic rate JSON (clash /traffic shape).
func GetTraffic() string {
	trafficMu.Lock()
	defer trafficMu.Unlock()

	snap := statistic.DefaultManager.Snapshot()
	now := time.Now()
	var up, down int64
	if lastSnapshot != nil && !lastTime.IsZero() {
		elapsed := now.Sub(lastTime).Seconds()
		if elapsed > 0 {
			up = int64(float64(snap.UploadTotal-lastSnapshot.UploadTotal) / elapsed)
			down = int64(float64(snap.DownloadTotal-lastSnapshot.DownloadTotal) / elapsed)
		}
	}
	lastSnapshot = snap
	lastTime = now

	resp := struct {
		Up   int64 `json:"up"`
		Down int64 `json:"down"`
	}{Up: up, Down: down}
	data, _ := json.Marshal(resp)
	return string(data)
}

func redirectLog(path string) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	logrus.SetOutput(f)
	return nil
}

func redirectErr(path string) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	logrus.SetOutput(f)
	return nil
}
