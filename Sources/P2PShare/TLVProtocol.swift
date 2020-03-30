//
//  TLVProtocol.swift
//

import Foundation
import Network
import os

/// TLVMessageProtocol implements a simple Type-Length-Message protocol
class TLVMessageProtocol: NWProtocolFramerImplementation {
    static let label = "TLVMessageProtocol"
    
    static let definition = NWProtocolFramer.Definition(implementation: TLVMessageProtocol.self)
    
    required init(framer: NWProtocolFramer.Instance) { }
    
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }
    
    func wakeup(framer: NWProtocolFramer.Instance) { }
    
    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        return true
    }
    
    func cleanup(framer: NWProtocolFramer.Instance) { }
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
       // Create a header using the type and length.
        let header = TLVMessageProtocolHeader(type: message.messageType, length: UInt32(messageLength))

       // Write the header.
       framer.writeOutput(data: header.encodedData)

       // Ask the connection to insert the content of the application message after your header.
       do {
           try framer.writeOutputNoCopy(length: messageLength)
       } catch let error {
        os_log("Hit error writing: %@", error.localizedDescription)
       }
   }
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
           // Try to read out a single header.
           var tempHeader: TLVMessageProtocolHeader?
           let headerSize = TLVMessageProtocolHeader.encodedSize
           let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                          maximumLength: headerSize) { (buffer, _) -> Int in
               guard let buffer = buffer else {
                   return 0
               }
               if buffer.count < headerSize {
                   return 0
               }
               tempHeader = TLVMessageProtocolHeader(buffer)
               return headerSize
           }

           // If you can't parse out a complete header, stop parsing and ask for headerSize more bytes.
           guard parsed, let header = tempHeader else {
               return headerSize
           }
  
           let message = NWProtocolFramer.Message(messageType: header.type)

           // Deliver the body of the message, along with the message object.
           if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
               return 0
           }
       }
    }
}

struct TLVMessageProtocolHeader: Codable {
    let type: UInt32
    let length: UInt32

    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }

    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                              count: MemoryLayout<UInt32>.size))
        }
        type = tempType
        length = tempLength
    }

    var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }

    static var encodedSize: Int {
        return MemoryLayout<UInt32>.size * 2
    }
}

extension NWProtocolFramer.Message {
    convenience init(messageType: UInt32) {
        self.init(definition: TLVMessageProtocol.definition)
        self.messageType = messageType
    }

    var messageType: UInt32 {
        get {
            if let messageType = self["MessageType"] as? UInt32 {
                return messageType
            } else {
                return 0
            }
        }
        set {
            self["MessageType"] = newValue
        }
    }

}
