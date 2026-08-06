//
//  VpnServiceHandler.swift
//  clashmiWidget
//

import Foundation
import NetworkExtension

class VpnServiceHandler {
    static let shared = VpnServiceHandler()

    var controlKind: String = ""
    var bundleIdentifier: String = ""
    var configFilePath: String = ""
    var uiServerAddress: String = "Clash Mi"
    var uiLocalizedDescription: String = "Clash Mi"

    private var cachedManager: NETunnelProviderManager?

    private init() {}

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        if let cachedManager { return cachedManager }
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let found = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleIdentifier }) {
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

    func getState(result: @escaping ([String: Any]) -> Void) {
        let status = cachedManager?.connection.status ?? .invalid
        result(["status": status.rawValue])
    }

    func getCurrentState() async -> NEVPNStatus {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        for m in managers where m.isEnabled {
            if let s = m.connection as? NETunnelProviderSession {
                return s.status
            }
        }
        return .invalid
    }

    func start(timeoutInSeconds: Int, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let manager = try await loadOrCreateManager()
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
                cachedManager = manager
                guard let session = manager.connection as? NETunnelProviderSession else {
                    completion(NSError(domain: "VpnServiceHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "No tunnel session"]))
                    return
                }
                try session.startVPNTunnel()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func stop(completion: @escaping (Error?) -> Void) {
        Task {
            if let session = cachedManager?.connection as? NETunnelProviderSession {
                session.stopVPNTunnel()
            }
            completion(nil)
        }
    }
}
