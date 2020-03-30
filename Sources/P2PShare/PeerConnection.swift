//
//  PeerConnection.swift
//

import Foundation
import Network
import os

protocol PeerConnectionDelegate: class {
    func peerConnection(_ connection: PeerConnection, didChangeState state: NWConnection.State)
    func peerConnection(_ connection: PeerConnection, didReceiveMessageType type: UInt32, data: Data)
}

/// PeerConnection manages an NWConnection instance to an NWEndpoint.
class PeerConnection {
    
    var peerInfo: PeerInfo?
    
    weak var delegate: PeerConnectionDelegate?
    
    var connection: NWConnection?
    
    let created = Date()
    var lastPing = Date()
    
    /// Create a peer connection from a connection request.
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.connection = connection
        self.delegate = delegate
        startConnection()
    }
        
    func startConnection() {
        guard let connection = connection else { return }
        
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            self.delegate?.peerConnection(self, didChangeState: newState)
            os_log("[connection] %@", newState.debugDescription)
            
            switch newState {
            case .ready:
                self.receiveNextMessage()
                
            case .failed:
                connection.cancel()
                
            case .cancelled:
                break
                
            case .preparing:
                break
                
            case .setup:
                break
                
            case .waiting:
                // ignore waiting for connectivity - we'll try again in a few seconds
                connection.cancel()
                
            @unknown default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    func cancel() {
        connection?.cancel()
        connection = nil
    }

    func sendMessage(type: UInt32, content: Data) {
        guard connection?.state == .ready else {
            return
        }
        
        let framerMessage = NWProtocolFramer.Message(messageType: type)
        let context = NWConnection.ContentContext(identifier: "Message", metadata: [framerMessage])
        
        connection?.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func receiveNextMessage() {
        connection?.receiveMessage { (data, context, _, error) in
            if let message = context?.protocolMetadata(definition: TLVMessageProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.peerConnection(self, didReceiveMessageType: message.messageType, data: data ?? Data())
            }

            if let error = error {
                os_log("[connection] receiveMessage error: %@", error.localizedDescription)
                self.cancel()
            } else {
                self.receiveNextMessage()
            }
        }
    }
}
