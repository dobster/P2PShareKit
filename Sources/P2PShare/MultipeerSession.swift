//
//  MultipeerSession.swift
//

import Foundation
import Network

/// PeerInfo contains identification information about a peer.
public struct PeerInfo: Codable, Equatable {
    // Unique identifier within the peer network
    public let peerID: String
    
    // User-defined key-value attributes to share on new connection
    public let info: [String: String]
    
    public init(_ info: [String: String]) {
        self.peerID = UUID().uuidString
        self.info = info
    }
}

/// Configuration for a MultipeerSession
public struct MultipeerSessionConfig {
    /// Information about the user on this device.
    public let myPeerInfo: PeerInfo
    
    /// The agreed bonjour service name to identify each other.
    public let bonjourService: String
    
    /// The secrety key used to encrypt all communications over TLS 1.2
    public let presharedKey: String
    
    /// Identity associated with PSK
    public let identity: String
    
    /// Seconds between pings to connected devices.
    public let connectivityCheckInterval: TimeInterval
    
    /// Seconds after which to terminate connections if no ping received.
    public let failedConnectionTimeout: TimeInterval
    
    public init(myPeerInfo: PeerInfo, bonjourService: String, presharedKey: String, identity: String, connectivityCheckInterval: TimeInterval = 5, failedConnectionTimeout: TimeInterval = 10) {
        self.myPeerInfo = myPeerInfo
        self.bonjourService = bonjourService
        self.presharedKey = presharedKey
        self.identity = identity
        self.connectivityCheckInterval = connectivityCheckInterval
        self.failedConnectionTimeout = failedConnectionTimeout
    }
}

/// A MultipeerSession object automatically initiates peer-to-peer wifi connections with one or more nearby peers and allows sharing of data.
/// Peers are discovered using a specified Bonjour service name.
/// Once connections are established, all communication over TCP is secured with TLS 1.2 using a pre-shared key.
/// All connections are terminated when the app is backgrounded. Connections are restored once the app is active again.
open class MultipeerSession: PeerBrowserDelegate, PeerListenerDelegate, PeerConnectionDelegate {
    
    /// Callback when new peers are found or known peers are lost.
    public var peersChangeHandler: (_ peers: [PeerInfo]) -> Void = { _ in }
    
    /// Callback when a new peer is found.
    public var newPeerHandler: (_ peer: PeerInfo) -> Void = { _ in }
    
    /// Callback when a message is received from a peer.
    public var messageReceivedHandler: (_ peer: PeerInfo, _ data: Data) -> Void = { _, _ in }
    
    /// Callback when an error occurs.
    public var errorHandler: (_ error: Error) -> Void = { _ in }
    
    private let config: MultipeerSessionConfig
    private let queue: DispatchQueue
        
    private var browser: PeerBrowser?
    private var listener: PeerListener?
    
    private var timer: Timer?
    private var browserResults: [NWBrowser.Result] = []
    private var connections: [PeerConnection] = []
    private var activePeers: [PeerInfo] = []

    private enum MessageType {
        static let ping: UInt32 = 0
        static let peerInfo: UInt32 = 1
        static let other: UInt32 = 2
    }
    
    /// Create a new MultipeerSession
    /// - Parameters:
    ///   - config: Configuration
    ///   - queue: Optional callback queue. Defaults to the main queue.
    public init(config: MultipeerSessionConfig, queue: DispatchQueue = .main) {
        self.config = config
        self.queue = queue
    }
    
    /// Start advertising and listening for new connections.
    public func startSharing() {
        self.browser = PeerBrowser(bonjourService: config.bonjourService, delegate: self)
        self.listener = PeerListener(bonjourService: config.bonjourService, presharedKey: config.presharedKey, identity: config.identity, myPeerID: config.myPeerInfo.peerID, delegate: self)
        
        self.listener?.startListening()
        self.browser?.startBrowsing()
        
        startReconnectionTimer()
    }
    
    /// Cancel any active connections and stop listening.
    public func stopSharing() {
        browser?.stopBrowsing()
        listener?.stopListening()
        
        stopReconnectionTimer()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        updatePeerList()
    }
    
    // MARK: - PeerBrowserDelegate
      
    func peerBrowser(_ browser: PeerBrowser, didUpdateResults results: [NWBrowser.Result]) {
        browserResults = results
        connections.removeAll(where: { $0.connection?.state == .cancelled || $0.connection == nil })
        updatePeerList()
    }
    
    // MARK: - PeerListenerDelegate
    
    func peerListener(_ listener: PeerListener, didFindNewConnection connection: NWConnection) {
        guard !connections.contains(where: { $0.connection?.endpoint == connection.endpoint }) else {
            connection.cancel()
            return
        }
        let newConnection = PeerConnection(connection: connection, delegate: self)
        connections.append(newConnection)
        updatePeerList()
    }
    
    // MARK: - PeerConnectionDelegate
    
    func peerConnection(_ connection: PeerConnection, didChangeState state: NWConnection.State) {
        if case .failed(let error) = state {
            errorHandler(error)
        }
        
        connections.removeAll(where: { $0.connection?.state == .cancelled || $0.connection == nil })
        updatePeerList()
        
        // Share user identification info to new connections.
        if state == .ready,
            let data = try? JSONEncoder().encode(config.myPeerInfo) {
            connection.sendMessage(type: MessageType.peerInfo, content: data)
        }
    }
    
    func peerConnection(_ connection: PeerConnection, didReceiveMessageType type: UInt32, data: Data) {
        guard let endpoint = connection.connection?.endpoint else { return }
        
        switch type {
        case MessageType.ping:
            connection.lastPing = Date()
            
        case MessageType.peerInfo:
            if let peerInfo = try? JSONDecoder().decode(PeerInfo.self, from: data),
                let connection = connections.first(where: { $0.connection?.endpoint == endpoint }) {
                connection.peerInfo = peerInfo
                newPeerHandler(peerInfo)
            }
            updatePeerList()
        
        default:
            if let peerInfo = connection.peerInfo {
                queue.async {
                    self.messageReceivedHandler(peerInfo, data)
                }
            }
        }
    }
    
    // MARK: - Periodic Connectivity Checks
       
    private func startReconnectionTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: config.connectivityCheckInterval, repeats: true, block: { [weak self] _ in
           guard let self = self else { return }
           self.pingExistingConnections()
           self.killFailingConnections()
           self.attemptNewConnections()
           self.updatePeerList()
       })
    }

    private func stopReconnectionTimer() {
       timer?.invalidate()
    }
       
    private func attemptNewConnections() {
        browserResults.forEach { result in
            if shouldConnectTo(result) {
                let networkConnection = NWConnection(to: result.endpoint, using: NWParameters(secret: config.presharedKey, identity: config.identity))
                let peerConnection = PeerConnection(connection: networkConnection, delegate: self)
                connections.append(peerConnection)
                updatePeerList()
            }
        }
    }
    
    private func pingExistingConnections() {
        connections.forEach {
            $0.sendMessage(type: MessageType.ping, content: Data())
        }
    }
    
    private func killFailingConnections() {
        connections.filter {
            $0.connection?.state == .preparing
            && Date().timeIntervalSince($0.created) > config.failedConnectionTimeout
        }.forEach {
            $0.cancel()
        }
        
        connections.filter {
            $0.connection?.state == .ready
            && Date().timeIntervalSince($0.lastPing) > config.failedConnectionTimeout
        }.forEach {
            $0.cancel()
        }
    }
    
    /// Should connect to a discovered service?
    private func shouldConnectTo(_ result: NWBrowser.Result) -> Bool {
        guard !connections.contains(where: { $0.connection?.endpoint == result.endpoint }) else {
            // already have an active connection
            return false
        }
        
        switch result.endpoint {
        case .service(let name, let type, _, _):
            // Only initiate a connection if our peerID > their peerID
            // This prevents race conditions creating two connections between the same peers.
            return type == config.bonjourService && name < config.myPeerInfo.peerID
        default:
            return false
        }
    }
    
    // MARK: - Send Messages
    
    /// Send data to another peer.
    public func send(to peerID: String, data: Data) {
        connections.filter({ $0.peerInfo?.peerID == peerID }).forEach { connection in
            connection.sendMessage(type: MessageType.other, content: data)
        }
    }
    
    /// Send data to all connected peers.
    public func sendToAllPeers(data: Data) {
        connections.forEach { connection in
            connection.sendMessage(type: MessageType.other, content: data)
        }
    }
    
    // MARK: - Update Peer List
    
    /// Inform the delegate if the connected peers list has changed.
    private func updatePeerList() {
        let activePeers = connections.filter {
            $0.connection?.state == .ready
            && $0.peerInfo != nil
        }.compactMap {
            $0.peerInfo
        }
        
        if activePeers != self.activePeers {
            self.activePeers = activePeers
            queue.async {
                self.peersChangeHandler(activePeers)
            }
        }
    }
}
