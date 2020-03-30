//
//  ViewController.swift
//  p2pShareKitDemo
//
//  Created by Stu Dobbie on 30/3/20.
//  Copyright © 2020 Stu Dobbie. All rights reserved.
//

import UIKit
import P2PShare

class ViewController: UIViewController {

    @IBOutlet private var messagesTableView: UITableView!
    @IBOutlet private var peersTableView: UITableView!
    @IBOutlet private var messageTextField: UITextField!
    
    @IBAction func send(_ sender: UITextField) {
        messageTextField.resignFirstResponder()
        guard let message = messageTextField.text,
            !message.isEmpty,
            let data = message.data(using: .unicode)
            else { return }
        session.sendToAllPeers(data: data)
    }
    
    private let myPeerInfo = PeerInfo(["name": UIDevice.current.name]) 
    
    private var peers: [PeerInfo] = []
    private var messages: [Message] = []
    
    private var session: MultipeerSession!
    
    private lazy var messagesDataSource = makeMessagesDataSource()
    private lazy var peersDataSource = makePeersDataSource()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesTableView.dataSource = messagesDataSource
        peersTableView.dataSource = peersDataSource
        
        let config = MultipeerSessionConfig(myPeerInfo: myPeerInfo,
                                            bonjourService: "_demo._tcp",
                                            presharedKey: "12345",
                                            identity: "DEMO_IDENTITY")
        session = MultipeerSession(config: config, queue: .main)
        
        session.peersChangeHandler = { [weak self] peers in
            self?.updatePeers(peers)
        }
        
        session.messageReceivedHandler = { [weak self] peerInfo, data in
            guard let message = String(data: data, encoding: .unicode),
                let from = peerInfo.info["name"] else { return }
            self?.addMessage("\(from): \(message)")
        }
        
        session.startSharing()
    }
}

private extension ViewController {
    
    enum Section: CaseIterable {
        case main
    }
    
    func makeMessagesDataSource() -> UITableViewDiffableDataSource<Section, Message> {
        return UITableViewDiffableDataSource(tableView: messagesTableView) { (tableView, indexPath, message) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Message Cell", for: indexPath)
            cell.textLabel?.text = message.text
            return cell
        }
    }
    
    func makePeersDataSource() -> UITableViewDiffableDataSource<Section, PeerInfo> {
        return UITableViewDiffableDataSource(tableView: peersTableView) { (tableView, indexPath, peer) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Peer Cell", for: indexPath)
            cell.textLabel?.text = peer.info["name"]
            return cell
        }
    }
    
    func addMessage(_ text: String) {
        messages.append(Message(text: text))
        var snapshot = NSDiffableDataSourceSnapshot<Section, Message>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(messages)
        messagesDataSource.apply(snapshot)
    }
    
    func updatePeers(_ peers: [PeerInfo]) {
        self.peers = peers
        var snapshot = NSDiffableDataSourceSnapshot<Section, PeerInfo>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(peers)
        peersDataSource.apply(snapshot)
    }
}

extension PeerInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(peerID)
    }
}

struct Message: Hashable {
    let id = UUID()
    let text: String
}
