//
//  PeerListener.swift
//

import Foundation
import Network
import os

protocol PeerListenerDelegate: class {
    func peerListener(_ listener: PeerListener, didFindNewConnection connection: NWConnection)
}

/// PeerListener manages an NWListener instance to listen for incoming connections from a bonjour service.
class PeerListener {
    let bonjourService: String
    let presharedKey: String
    let identity: String
    let myPeerID: String
    weak var delegate: PeerListenerDelegate?
    
    private var listener: NWListener?
    
    init(bonjourService: String, presharedKey: String, identity: String, myPeerID: String, delegate: PeerListenerDelegate) {
        self.bonjourService = bonjourService
        self.presharedKey = presharedKey
        self.identity = identity
        self.myPeerID = myPeerID
        self.delegate = delegate
    }
    
    func startListening() {
        guard let listener = try? NWListener(using: NWParameters(secret: presharedKey, identity: identity)) else {
            os_log("[listener] failed to create NWListener")
            return
        }
        self.listener = listener
        
        listener.service = NWListener.Service(name: myPeerID, type: bonjourService, domain: nil, txtRecord: nil)
               
        listener.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            os_log("[listener] %@", newState.debugDescription)
            
            switch newState {
            case .setup:
                break
            case .waiting:
                break
            case .ready:
                break
            case .failed:
                os_log("[listener] restarting")
                self.listener?.cancel()
                self.startListening()
            case .cancelled:
                break
            @unknown default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] newConnection in
            guard let self = self else { return }
            self.delegate?.peerListener(self, didFindNewConnection: newConnection)
        }
        
        listener.start(queue: .main)
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
    }
}
