const List<String> ProxyBypassDoaminsDefault = [
  "localhost",
  "127.0.0.1",
  "*.local",
  "*.lan",
  "192.168.0.0/16",
  "10.0.0.0/8",
  "172.16.0.0/12",
  "*.apple.com",
];

class ProxyOption {
  final String host;
  final int port;
  final List<String> bypassDomain;

  ProxyOption(this.host, this.port, this.bypassDomain);

  Map<String, dynamic> toJson() {
    return {
      "host": host,
      "port": port,
      "bypassDomain": bypassDomain,
    };
  }
}

class ProxyManager {
  void setExcludeDevices(Set<String> devices) {
    // Only used on macOS for the system extension; no-op elsewhere.
  }
}
