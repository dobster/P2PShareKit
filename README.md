# P2PShareKit

![Swift Version](https://img.shields.io/badge/Swift-5.1-orange.svg?logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS-yellow.svg?logo=apple)

Peer-to-peer sharing using the modern Network.framework, all wrapped up in a handy Swift package.

Securely share data between iOS devices using peer wifi networking (no wifi routers or any established network required)

- Automatically connect to trusted peers
- Comms via TLS 1.2
- Simple `Data` sharing
- Automatically re-establish connections to lost peers

Builds upon sample code provided during [WWDC2019 - Advances in Networking Part 2][wwdc-2019-advanced-networking]

This implementation is currently limited to:
- iOS 13
- exclusively uses peer-to-peer wifi

## Demo

Refer to the Example project

![Sample](Example/demo.gif?raw=true)

## Usage

Each device needs to identify itself to others. Build your own identify dictionary based on what makes sense for your app. The `PeerInfo` record is exchanged before the framework reports a new connection.

```swift
let peerInfo = PeerInfo(info: ["name": "Fred"])
```

Configure a session with your security credentials. Connections are only made with other devices with the same security credentials. 
```swift
let config = MultipeerSessionConfig(myPeerInfo: peerInfo, 
                                    bonjourService: "_demo._tcp", 
                                    presharedKey: "1234", 
                                    identity: "Demo")

let session = MultipeerSession(config: config)
```

Finally, set the session callbacks and start the session.

```swift
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
```

To send a message, use the peerID from the list of peers returned in `peersChangeHandler`.

```swift
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
        .package(url: "https://github.com/dobster/P2PShareKit", from: "0.2.0")
    ],
```

## Contributing

Feel free to open [issues on GitHub](https://github.com/dobster/P2PShareKit/issues) or to open [pull requests](https://github.com/dobster/P2PShareKit/pulls).

## License

This project is licensed unter the terms of the MIT license. See [LICENSE](./LICENSE) for more information.


[multipeer-connectivity]: https://developer.apple.com/documentation/multipeerconnectivity
[wwdc-2019-advanced-networking]: https://developer.apple.com/videos/play/wwdc2019/713/
[network-framework]: https://developer.apple.com/documentation/network
[blog-post]: https://dobster.github.io/ios/ipados/ipad/network.framework/2020/02/08/peer-to-peer-sharing-ios.html
