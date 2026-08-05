package adapter

import (
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestParseCNSProxy(t *testing.T) {
	proxy, err := ParseProxy(map[string]any{
		"type":     "cns",
		"name":     "cns1",
		"server":   "127.0.0.1",
		"port":     1254,
		"password": "666",
		"key":      "Meng",
		"flag":     "httpUDP",
		"udp":      true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if proxy.Type() != C.CNS {
		t.Fatalf("unexpected type: %v", proxy.Type())
	}
	if proxy.Addr() != "127.0.0.1:1254" {
		t.Fatalf("unexpected addr: %s", proxy.Addr())
	}
	if !proxy.SupportUDP() {
		t.Fatal("expected udp support")
	}

	if _, err := ParseProxy(map[string]any{
		"type": "cns",
		"name": "bad",
	}); err == nil {
		t.Fatal("expected error for missing server/port")
	}
}
