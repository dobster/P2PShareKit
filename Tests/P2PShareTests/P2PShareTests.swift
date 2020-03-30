import XCTest
import Network
import Security
import os

@testable import P2PShare

final class P2PShareTests: XCTestCase {

    var sessionForTim: MultipeerSession?
    var sessionForCraig: MultipeerSession?
    var sessionForEddy: MultipeerSession?
    var sessionForJony: MultipeerSession?
    var sessionForPhilip: MultipeerSession?

    override func setUp() {
        let service = "_test1._tcp"
        let psk = "1234"
        let identity = "IDENTITY"
        
        let peerInfoTim = PeerInfo(["name": "Tim"])
        let configTim = MultipeerSessionConfig(myPeerInfo: peerInfoTim, bonjourService: service, presharedKey: psk, identity: identity)
        sessionForTim = MultipeerSession(config: configTim)

        let peerInfoEddy = PeerInfo(["name": "Eddy"])
        let configEddy = MultipeerSessionConfig(myPeerInfo: peerInfoEddy, bonjourService: service, presharedKey: psk, identity: identity)
        sessionForEddy = MultipeerSession(config: configEddy)
        
        let peerInfoCraig = PeerInfo(["name": "Craig"])
        let configCraig = MultipeerSessionConfig(myPeerInfo: peerInfoCraig, bonjourService: service, presharedKey: psk, identity: identity)
        sessionForCraig = MultipeerSession(config: configCraig)

        let peerInfoJony = PeerInfo(["name": "Jony"])
        let serviceJony = "_jony._tcp"
        let configJony = MultipeerSessionConfig(myPeerInfo: peerInfoJony, bonjourService: serviceJony, presharedKey: psk, identity: identity)
        sessionForJony = MultipeerSession(config: configJony)
        
        let peerInfoPhilip = PeerInfo(["name": "Philip"])
        let pskPhilip = "5566"
        let configPhilip = MultipeerSessionConfig(myPeerInfo: peerInfoPhilip, bonjourService: service, presharedKey: pskPhilip, identity: identity)
        sessionForPhilip = MultipeerSession(config: configPhilip)
    }

    override func tearDown() {
        sessionForTim?.stopSharing()
        sessionForEddy?.stopSharing()
        sessionForJony?.stopSharing()
        sessionForCraig?.stopSharing()
        sessionForPhilip?.stopSharing()
        
        sessionForTim = nil
        sessionForEddy = nil
        sessionForCraig = nil
        sessionForJony = nil
        sessionForPhilip = nil
    }

    func testTwoSessionsCanConnect() {
        var result: [PeerInfo]?
        
        let exp = XCTestExpectation(description: "tim connects to eddy")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count > 0 {
                result = peers
                exp.fulfill()
            }
        }
        
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        wait(for: [exp], timeout: 20.0)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.count, 1)
        XCTAssertEqual(result![0].info["name"], "Eddy")
    }

    func testConnectedSessionsCanShareData() {
        var result: Data?
        
        let exp1 = XCTestExpectation(description: "tim connects to eddy")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count > 0 {
                exp1.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        wait(for: [exp1], timeout: 20.0)
        
        let exp2 = XCTestExpectation(description: "eddy receives message from tim")
        let data = "TEST".data(using: .unicode)!
        sessionForEddy!.messageReceivedHandler = { _, data  in
            result = data
            exp2.fulfill()
        }
        sessionForTim!.sendToAllPeers(data: data)
        wait(for: [exp2], timeout: 20.0)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(String(data: result!, encoding: .unicode), "TEST")
    }
    
    func testThreeSessionsCanConnect() {
        var result: [PeerInfo]?
        
        let exp = XCTestExpectation(description: "tim connects to eddy and craig")
        sessionForTim?.peersChangeHandler = { peers in
            if peers.count == 2 {
                result = peers
                exp.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        sessionForCraig!.startSharing()
        wait(for: [exp], timeout: 20.0)
        
        XCTAssertNotNil(result)
        let names = result!.map { $0.info["name"]! }
        XCTAssertEqual(names.sorted(by: <), ["Craig", "Eddy"])
    }
    
    func testCanSendMessageToSpecificPeer() {
        var connectedPeers: [PeerInfo]?
        let exp1 = XCTestExpectation(description: "tim connects to eddy and craig")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count == 2 {
                connectedPeers = peers
                exp1.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        sessionForCraig!.startSharing()
        wait(for: [exp1], timeout: 20.0)
        
        let exp2 = XCTestExpectation(description: "craig receives message from tim")
        var result: Data?
        sessionForTim!.messageReceivedHandler = { peerInfo, data in
            XCTFail("tim not expecting a message")
        }
        sessionForEddy!.messageReceivedHandler = { peerInfo, data in
            XCTFail("eddy not expecting a message")
        }
        sessionForCraig!.messageReceivedHandler = { peerInfo, data in
            XCTAssertEqual(peerInfo.info["name"], "Tim")
            result = data
            exp2.fulfill()
        }
        let message = "Hello Craig!".data(using: .unicode)!
        let craig = connectedPeers!.first { $0.info["name"] == "Craig" }!.peerID
        sessionForTim?.send(to: craig, data: message)
        wait(for: [exp2], timeout: 20.0)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(String(data: result!, encoding: .unicode), "Hello Craig!")
    }
    
    func testCanSendMessageToAllPeers() {
        let exp1 = XCTestExpectation(description: "tim connects to eddy and craig")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count == 2 {
                exp1.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        sessionForCraig!.startSharing()
        wait(for: [exp1], timeout: 20.0)
        
        let exp2 = XCTestExpectation(description: "craig receives message from tim")
        let exp3 = XCTestExpectation(description: "eddy receives message from tim")
        sessionForTim!.messageReceivedHandler = { peerInfo, data in
            XCTFail("tim not expecting a message")
        }
        sessionForEddy!.messageReceivedHandler = { peerInfo, data in
            XCTAssertEqual(peerInfo.info["name"], "Tim")
            XCTAssertEqual(String(data: data, encoding: .unicode), "Hello Everybody!")
            exp3.fulfill()
        }
        sessionForCraig!.messageReceivedHandler = { peerInfo, data in
            XCTAssertEqual(peerInfo.info["name"], "Tim")
            XCTAssertEqual(String(data: data, encoding: .unicode), "Hello Everybody!")
            exp2.fulfill()
        }
        let message = "Hello Everybody!".data(using: .unicode)!
        sessionForTim?.sendToAllPeers(data: message)
        wait(for: [exp2, exp3], timeout: 20.0)
    }
    
    func testSessionsAutomaticallyReconnectAfterLosingPeer() {
        let exp1 = XCTestExpectation(description: "tim connects to eddy")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count == 1 {
                XCTAssertEqual(peers[0].info["name"], "Eddy")
                exp1.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForEddy!.startSharing()
        wait(for: [exp1], timeout: 20.0)
        
        let exp2 = XCTestExpectation(description: "tim loses eddy")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count == 0 {
                exp2.fulfill()
            }
        }
        sessionForEddy!.stopSharing()
        wait(for: [exp2], timeout: 20.0)
        
        let exp3 = XCTestExpectation(description: "tim connects with eddy again")
        sessionForTim!.peersChangeHandler = { peers in
            if peers.count == 1 {
                XCTAssertEqual(peers[0].info["name"], "Eddy")
                exp3.fulfill()
            }
        }
        sessionForEddy!.startSharing()
        wait(for: [exp3], timeout: 20.0)
    }
    
    func testWillNotConnectToDifferentService() {
        // Should not connect to Jony because he has his own private bonjour service
        let exp1 = XCTestExpectation(description: "tim should not connect to jony")
        exp1.isInverted = true
        
        let exp2 = XCTestExpectation(description: "tim should connect to craig")
        
        sessionForTim!.peersChangeHandler = { peers in
            if peers.contains(where: { $0.info["name"] == "Jony" }) {
                exp1.fulfill()
            }
            if peers.contains(where: { $0.info["name"] == "Craig" }) {
                exp2.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForJony!.startSharing()
        sessionForCraig!.startSharing()

        wait(for: [exp1, exp2], timeout: 20.0)
    }
    
    func testWillNotConnectToPeerWithoutPresharedKey() {
        // Should not connect to Philip because no one told him the secret password
        let exp1 = XCTestExpectation(description: "tim should not connect to philip")
        exp1.isInverted = true
        
        let exp2 = XCTestExpectation(description: "handshake with philip should fail")
        
        sessionForTim!.peersChangeHandler = { peers in
            if peers.contains(where: { $0.info["name"] == "Philip" }) {
                exp1.fulfill()
            }
        }
        sessionForTim!.errorHandler = { error in
            if case NWError.tls(let osStatus) = error { // }, osStatus == errSSLHandshakeFail {
                os_log("osStatus=%i", osStatus)
                exp2.fulfill()
            }
        }
        sessionForTim!.startSharing()
        sessionForPhilip!.startSharing()
        
        wait(for: [exp1, exp2], timeout: 20.0)
    }
    
    static var allTests = [
        ("testTwoSessionsCanConnect", testTwoSessionsCanConnect),
        ("testTwoSessionsCanExchangeAMessage", testConnectedSessionsCanShareData),
        ("testThreeSessionsCanConnect", testThreeSessionsCanConnect),
        ("testCanSendMessageToSpecificPeer", testCanSendMessageToSpecificPeer),
        ("testCanSendMessageToAllPeers", testCanSendMessageToAllPeers),
        ("testSessionsAutomaticallyReconnectAfterLosingPeer", testSessionsAutomaticallyReconnectAfterLosingPeer),
        ("testWillNotConnectToDifferentService", testWillNotConnectToDifferentService),
        ("testWillNotConnectToPeerWithoutPresharedKey", testWillNotConnectToPeerWithoutPresharedKey)
    ]
}
