import Flutter
import UIKit
import NetworkExtension

class StateStreamHandler: NSObject, FlutterStreamHandler {
    static var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        StateStreamHandler.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        StateStreamHandler.eventSink = nil
        return nil
    }

    static func push(name: String) {
        guard let sink = eventSink else { return }
        sink(["state": name, "params": [:]])
    }
}

class NativeVpnServiceManager {
    static let shared = NativeVpnServiceManager()

    private var configFilePath: String = ""
    private var bundleIdentifier: String = ""
    private var uiServerAddress: String = ""
    private var uiLocalizedDescription: String = ""
    private var cachedManager: NETunnelProviderManager?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            StateStreamHandler.push(name: self?.stateName ?? "disconnected")
        }
    }

    var stateName: String {
        guard let manager = cachedManager,
              let session = manager.connection as? NETunnelProviderSession else {
            return "disconnected"
        }
        return Self.name(of: session.status)
    }

    static func name(of status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnecting: return "disconnecting"
        case .reasserting: return "reasserting"
        case .invalid: return "invalid"
        default: return "disconnected"
        }
    }

    func getAppGroupDirectory(_ groupId: String) -> String? {
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupId)?
            .path
    }

    func prepareConfig(args: [String: Any]) {
        configFilePath = args["configFilePath"] as? String ?? ""
        bundleIdentifier = args["bundleIdentifier"] as? String ?? ""
        uiServerAddress = args["uiServerAddress"] as? String ?? ""
        uiLocalizedDescription = args["uiLocalizedDescription"] as? String ?? ""
        cachedManager = nil
    }

    func installService() -> [String: Any]? {
        return nil
    }

    func uninstallService() async -> [String: Any]? {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        for m in managers {
            guard let proto = m.protocolConfiguration as? NETunnelProviderProtocol,
                  proto.providerBundleIdentifier == bundleIdentifier else { continue }
            m.isEnabled = false
            try? await m.saveToPreferences()
            try? await m.removeFromPreferences()
        }
        cachedManager = nil
        return nil
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        if let cached = cachedManager, cached.isEnabled {
            return cached
        }
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        if let found = managers.first(where: { m in
            (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleIdentifier
        }) {
            cachedManager = found
            return found
        }
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleIdentifier
        proto.serverAddress = uiServerAddress
        proto.providerConfiguration = ["configFilePath": configFilePath]
        manager.protocolConfiguration = proto
        manager.localizedDescription = uiLocalizedDescription
        manager.isEnabled = true
        cachedManager = manager
        return manager
    }

    private func currentSession() -> NETunnelProviderSession? {
        return cachedManager?.connection as? NETunnelProviderSession
    }

    private func runningSession() async -> NETunnelProviderSession? {
        if let session = currentSession(), session.status == .connected || session.status == .connecting {
            return session
        }
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        for m in managers where m.isEnabled {
            if let session = m.connection as? NETunnelProviderSession,
               session.status == .connected || session.status == .connecting {
                return session
            }
        }
        return nil
    }

    func start(timeout: Int) async -> [String: Any] {
        do {
            let manager = try await loadOrCreateManager()
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            cachedManager = manager
            let session = try (manager.connection as? NETunnelProviderSession).orThrow()
            try session.startVPNTunnel()
            return await waitForStatus(.connected, timeoutMs: timeout)
        } catch {
            return Self.errorResult(error)
        }
    }

    func restart(timeout: Int) async -> [String: Any] {
        await stop()
        return await start(timeout: timeout)
    }

    func stop() async {
        if let session = currentSession() {
            session.stopVPNTunnel()
            cachedManager = nil
            return
        }
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        for m in managers {
            (m.connection as? NETunnelProviderSession)?.stopVPNTunnel()
        }
        cachedManager = nil
    }

    func waitForStatus(_ target: NEVPNStatus, timeoutMs: Int) async -> [String: Any] {
        let deadline = DispatchTime.now() + .milliseconds(timeoutMs)
        while DispatchTime.now() < deadline {
            if let session = currentSession() {
                let status = session.status
                if status == target {
                    return ["type": "done"]
                }
                if status == .invalid {
                    return Self.errorResult(NSError(domain: "vpn", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "invalid vpn status"
                    ]))
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return ["type": "timeout"]
    }

    func clashiApiConnections(showTraffic: Bool) async -> String {
        guard let session = await runningSession() else { return "{}" }
        let message: [String: Any] = [
            "messageId": "clashiApiConnections",
            "messageParams": showTraffic ? "true" : "false",
        ]
        return await sendProviderMessage(session, message) ?? "{}"
    }

    func clashiApiTraffic() async -> String {
        guard let session = await runningSession() else { return "{\"up\":0,\"down\":0}" }
        let message: [String: Any] = [
            "messageId": "clashiApiTraffic",
            "messageParams": "",
        ]
        return await sendProviderMessage(session, message) ?? "{\"up\":0,\"down\":0}"
    }

    private func sendProviderMessage(_ session: NETunnelProviderSession, _ message: [String: Any]) async -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                do {
                    try session.sendProviderMessage(data) { response in
                        guard let response else {
                            cont.resume(throwing: NSError(domain: "no response", code: 0))
                            return
                        }
                        cont.resume(returning: String(data: response, encoding: .utf8) ?? "")
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
            return result
        } catch {
            return nil
        }
    }

    static func errorResult(_ error: Error) -> [String: Any] {
        let nsError = error as NSError
        return [
            "type": "error",
            "err": [
                "code": nsError.code,
                "message": nsError.localizedDescription,
            ],
        ]
    }
}

private extension Optional {
    func orThrow() throws -> Wrapped {
        guard let value = self else {
            throw NSError(domain: "nil value", code: 0)
        }
        return value
    }
}

public class LibclashVpnServicePlugin: NSObject, FlutterPlugin {
    private let manager = NativeVpnServiceManager.shared

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LibclashVpnServicePlugin()
        let channel = FlutterMethodChannel(
            name: "libclash_vpn_service",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)

        let stateChannel = FlutterEventChannel(
            name: "libclash_vpn_service/state",
            binaryMessenger: registrar.messenger()
        )
        stateChannel.setStreamHandler(StateStreamHandler())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "getAppGroupDirectory":
            let groupId = args["groupId"] as? String ?? ""
            result(manager.getAppGroupDirectory(groupId))
        case "getSystemVersion":
            result(UIDevice.current.systemVersion)
        case "getState":
            result(manager.stateName)
        case "clashiApiConnections":
            let showTraffic = args["showTraffic"] as? Bool ?? false
            Task { result(await manager.clashiApiConnections(showTraffic: showTraffic)) }
        case "clashiApiTraffic":
            Task { result(await manager.clashiApiTraffic()) }
        case "prepareConfig":
            manager.prepareConfig(args: args)
            result(nil)
        case "installService":
            result(manager.installService())
        case "uninstallService":
            Task { result(await manager.uninstallService()) }
        case "start":
            let timeout = args["timeout"] as? Int ?? 60000
            Task { result(await manager.start(timeout: timeout)) }
        case "restart":
            let timeout = args["timeout"] as? Int ?? 60000
            Task { result(await manager.restart(timeout: timeout)) }
        case "stop":
            Task { await manager.stop(); result(nil) }
        case "setAlwaysOn":
            result(nil)
        case "setExcludeFromRecents", "hideDockIcon", "firewallAddApp",
             "firewallAddPorts", "setSystemProxy", "cleanSystemProxy",
             "autoStartCreate", "autoStartDelete":
            result(nil)
        case "getABIs":
            result("[]")
        case "isRunAsAdmin", "getSystemProxyEnable", "autoStartIsActive",
             "isServiceAuthorized":
            result(false)
        case "authorizeService":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
