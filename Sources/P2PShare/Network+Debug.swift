//
//  Network+Debug.swift
//

import Foundation
import Network

extension NWEndpoint {
    var debugDescription: String {
        switch self {
        case .service(let name, let type, let domain, let interface):
            return "service(\(name), \(type), \(domain), \(String(describing: interface)))"
        case .hostPort(let host, let port):
            return "host(\(host):\(port))"
        case .unix(let path):
            return "path(\(path))"
        case .url(let url):
            return "url(\(url.absoluteString))"
        @unknown default:
            return "unknown"
        }
    }
}

extension NWBrowser.State {
    var debugDescription: String {
        switch self {
        case .cancelled:
            return "Cancelled"
        case .failed(let error):
            return "Failed: \(error)"
        case .ready:
            return "Ready"
        case .setup:
            return "Setup"
        @unknown default:
            return "Unknown"
        }
    }
}

extension NWBrowser.Result.Change.Flags {
    var debugDescription: String {
        switch self {
        case .identical:
            return "Identical"
        case .interfaceAdded:
            return "Interface Added"
        case .interfaceRemoved:
            return "Interface Removed"
        case .metadataChanged:
            return "Metadata Changed"
        default:
            return "Unknown"
        }
    }
}

extension NWListener.State {
    var debugDescription: String {
        switch self {
        case .cancelled:
            return "Cancelled"
        case .failed(let error):
            return "Error: \(error)"
        case .ready:
            return "Ready"
        case .setup:
            return "Setup"
        case .waiting(let error):
            return "Waiting: \(error)"
        @unknown default:
            return "Unknown"
        }
    }
}

extension NWConnection.State {
    var debugDescription: String {
        switch self {
        case .cancelled:
            return "Cancelled"
        case .failed(let error):
            return "Failed: \(error)"
        case .preparing:
            return "Preparing"
        case .ready:
            return "Ready"
        case .setup:
            return "Setup"
        case .waiting(let error):
            return "Waiting: \(error)"
        @unknown default:
            return "Unknown"
        }
    }
}
