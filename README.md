# P2PShareKit

Peer-to-peer sharing using Network.framework, all wrapped up in a handy Swift package!

Securely share data between iOS devices using peer wifi networking (no wifi routers or any established network required)

Builds upon sample code provided as part of [WWDC2019 - Advances in Networking Part 2][wwdc-2019-advanced-networking]

This implementation is currently limited to:
- iOS 13
- exclusively uses peer-to-peer wifi

## Sample app

Checkout the example folder for a demo.

## Usage

```swift

// Each device needs to identify itself to others.
// Build your own id dictionary based on what makes sense for your app.
let peerInfo = PeerInfo(info: ["name": "Fred"])

// Create a configuration around your security credentials.
let config = MultipeerSessionConfig(myPeerInfo: peerInfo, bonjourService: "_demo._tcp", presharedKey: "1234", identity: "Demo")

// Create a session.
let session = MultipeerSession(config: config)

// Set the session callbacks.

session.peersChangeHandler = { peerInfos in 
     // update any UI that shows connected peers
 }

session.newPeerHandler = { peerInfo in 
    // a good time to sync anything necessary 
}

session.messageReceivedHandler = { peerInfo, data in 
    // Decode data and process
}

session.startSharing()

// To send a message, use the peerID from the list of peers returned in peersChangeHandler.
let peerID = peerInfo.peerID
session.send(to: peerID, data: data)
```

The framework isn't opinionated about how you handle the generic `data` payload. You can progressively try to decode against expected Codable structs, or use a Codable enum.

Refer to the following blog post for more information and the example `PeerShareData` that uses a Codable enum: 
[Adopting Network.framework for iOS peer-to-peer connectivity][blog-post]

## Integrating

Add the depedency in your Swift package file:

```swift
    dependencies: [
        .package(url: "https://github.com/dobster/P2PShareKit", from: "0.1.0")
    ],
```


[multipeer-connectivity]: https://developer.apple.com/documentation/multipeerconnectivity
[wwdc-2019-advanced-networking]: https://developer.apple.com/videos/play/wwdc2019/713/
[network-framework]: https://developer.apple.com/documentation/network
[blog-post]: http://127.0.0.1:4000/ios/ipados/ipad/network.framework/2020/02/08/peer-to-peer-sharing-ios.html