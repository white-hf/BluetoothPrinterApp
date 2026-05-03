import Foundation
import os.log

@MainActor
final class ServerDiscoveryManager: NSObject, ObservableObject {
    static let shared = ServerDiscoveryManager()
    private let logger = Logger(subsystem: "com.whitetang.swiftprintble", category: "Discovery")
    
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isSearching = false
    @Published var lastStatus: String = "Idle"
    
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    
    struct DiscoveredServer: Identifiable, Equatable {
        let id: String
        let name: String
        let hostName: String?
        let port: Int
        let url: URL
    }
    
    override init() {
        super.init()
        logger.info("Discovery Manager Initialized")
    }
    
    func startDiscovery() {
        stopDiscovery()
        discoveredServers.removeAll()
        services.removeAll()
        
        lastStatus = "Starting search..."
        logger.info("Starting search for _labelprint._tcp")
        
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: "_labelprint._tcp", inDomain: "local.")
        isSearching = true
        logger.info("🔍 Started searching for _labelprint._tcp. in default domains")
    }
    
    func stopDiscovery() {
        browser?.stop()
        browser = nil
        isSearching = false
        lastStatus = "Stopped"
        logger.info("🛑 Discovery stopped")
    }
}

extension ServerDiscoveryManager: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        lastStatus = "Browser searching..."
        logger.info("🛰️ Browser started searching")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        lastStatus = "Search stopped"
        logger.info("🛑 Browser stopped")
        isSearching = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        let err = "\(errorDict)"
        lastStatus = "Failed: \(err)"
        logger.error("❌ Search failed: \(err)")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        lastStatus = "Found: \(service.name)"
        logger.info("✨ Found service: \(service.name)")
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.info("🗑️ Removed service: \(service.name)")
        services.removeAll { $0 == service }
        discoveredServers.removeAll { $0.id == service.name }
    }
}

extension ServerDiscoveryManager: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        let host = sender.hostName ?? "\(sender.name).local"
        let port = sender.port
        let urlString = "http://\(host):\(port)"
        
        if let url = URL(string: urlString) {
            let server = DiscoveredServer(
                id: sender.name,
                name: sender.name,
                hostName: sender.hostName,
                port: port,
                url: url
            )
            
            if !discoveredServers.contains(where: { $0.id == server.id }) {
                discoveredServers.append(server)
                lastStatus = "Resolved: \(server.name)"
                logger.info("✅ Resolved server: \(server.name) at \(url.absoluteString)")
                ToastHaptics.shared.show(L10n.autoConnectedToServer(server.name), style: .success, position: .center)
            }
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        logger.error("❌ Failed to resolve \(sender.name): \(errorDict)")
        lastStatus = "Resolve Error"
    }
}