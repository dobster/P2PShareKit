//
//  PeerBrowser.swift
//

import Foundation
import Network
import os

protocol PeerBrowserDelegate: class {
    func peerBrowser(_ browser: PeerBrowser, didUpdateResults results: [NWBrowser.Result])
}

/// PeerBrowser manages an NWBrowser instance that browses for a bonjour service.
class PeerBrowser {
    let bonjourService: String
    weak var delegate: PeerBrowserDelegate?
    
    private var browser: NWBrowser?
    
    init(bonjourService: String, delegate: PeerBrowserDelegate) {
        self.bonjourService = bonjourService
        self.delegate = delegate
    }
    
    func startBrowsing() {
        guard browser == nil else { return }
        
        let params = NWParameters()
        params.includePeerToPeer = true
        params.requiredInterfaceType = .wifi
        let browser = NWBrowser(for: .bonjour(type: bonjourService, domain: nil), using: params)
        self.browser = browser
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            self.delegate?.peerBrowser(self, didUpdateResults: Array(results))
        }
        
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            os_log("[browser] %@", newState.debugDescription)
            
            switch newState {
            case .cancelled:
                break
            case .failed:
                os_log("[browser] restarting")
                self.browser?.cancel()
                self.startBrowsing()
            case .ready:
                break
            case .setup:
                break
            @unknown default:
                break
            }
        }
        
        browser.start(queue: .main)
    }
    
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }
}
