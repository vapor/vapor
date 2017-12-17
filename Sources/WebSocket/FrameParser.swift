import Async
import Foundation
import COperatingSystem
import Bits

final class FrameParser: ProtocolTransformationStream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer
    
    /// See OutputStream.Output
    public typealias Output = Frame

    /// The currently accumulated payload data
    var accumulated = 0
    
    /// The buffer in which Frames are stored
    let bufferBuilder: MutableBytesPointer
    
    /// The maximum accepted payload size (to prevent memory attacks)
    let maximumPayloadSize: Int
    
    /// The remainder buffer that couldn't yet be parsed (such as 2 bytes of an UInt32)
    var partialBuffer = [UInt8]()
    
    /// The currently processing frame
    var processing: Frame.Header?
    
    /// An array, for when a single TCP message has > 1 entity
    var backlog: [Output]
    
    /// Keeps track of the backlog that is already drained but not removed
    var consumedBacklog: Int
    
    /// The upstream providing byte buffers
    var upstream: ConnectionContext?
    
    /// Use a basic output stream to implement server output stream.
    var downstream: AnyInputStream<Output>?
    
    /// Remaining downstream demand
    var downstreamDemand: UInt
    
    /// Current state
    var state: ProtocolParserState
    
    public init(maximumPayloadSize: Int = 100_000) {
        self.maximumPayloadSize = maximumPayloadSize
        // 2 for the header, 9 for the length, 4 for the mask
        self.bufferBuilder = MutableBytesPointer.allocate(capacity: maximumPayloadSize + 15)
    }
    
    /// See OutputStream.onInput
    public func transform(_ input: ByteBuffer) throws {
        guard let pointer = input.baseAddress, input.count > 0 else {
            // ignore
            return
        }
        
        var offset = 0
        
        while offset < input.count {
            let remaining = input.count &- offset
            
            let consumed = try process(pointer: pointer.advanced(by: offset), length: remaining)
            
            offset = offset &+ consumed
        }
    }
    
    private func process(pointer: BytesPointer, length: Int) throws -> Int {
        let header: Frame.Header
        var offset: Int
        
        // If a header was already processed
        if let processing = processing {
            header = processing
            offset = 0
        } else {
            if accumulated > 0 {
                guard accumulated < 15 else {
                    // internal inconsistency, header data present but not parsed
                    throw WebSocketError(.parserError)
                }
                
                // Partial header available, copy _all_ data and move back
                memcpy(bufferBuilder.advanced(by: accumulated), pointer, min(length, maximumPayloadSize + 15 - accumulated))
                
                guard let parsedHeader = try FrameParser.parseFrameHeader(from: pointer, length: length) else {
                    // Not enough data for a header
                    memcpy(bufferBuilder.advanced(by: accumulated), pointer, length)
                    accumulated = accumulated &+ length
                    return length
                }
                
                header = parsedHeader
                offset = header.consumed &- accumulated
                accumulated = header.consumed
            } else {
                guard let parsedHeader = try FrameParser.parseFrameHeader(from: pointer, length: length) else {
                    // Not enough data for a header
                    memcpy(bufferBuilder.advanced(by: accumulated), pointer, length)
                    accumulated = accumulated &+ length
                    return length
                }
                
                header = parsedHeader
                offset = header.consumed
                accumulated = header.consumed
            }
        }
        
        guard numericCast(header.size) < maximumPayloadSize else {
            throw WebSocketError(.invalidBufferSize)
        }
        
        let parsed = min(numericCast(length &- offset), maximumPayloadSize &- numericCast(accumulated))
        
        memcpy(bufferBuilder.advanced(by: accumulated), pointer.advanced(by: offset), parsed)
        accumulated = accumulated &+ parsed
        
        offset = offset &+ parsed
        
        let frameSize = header.consumed &+ numericCast(header.size)
        
        if frameSize == accumulated {
            let payload = ByteBuffer(start: bufferBuilder.advanced(by: header.consumed), count: accumulated &- header.consumed)
            let frame = try Frame(op: header.op, payload: payload, mask: header.mask, isMasked: header.mask != nil, isFinal: header.final)
            accumulated = 0
            flush(frame)
        }
        
        if frameSize > accumulated {
            throw WebSocketError(.parserError)
        }
        
        return offset
    }
    
    static func parseFrameHeader(from base: UnsafePointer<UInt8>, length: Int) throws -> Frame.Header? {
        guard
            length > 3,
            let code = Frame.OpCode(rawValue: base[0] & 0b00001111)
        else {
            throw WebSocketError(.invalidFrame)
        }
        
        // If the FIN bit is set
        let final = base[0] & 0b10000000 == 0b10000000
        
        // Extract the payload bits
        var payloadLength = UInt64(base[1] & 0b01111111)
        let isMasked = base[1] & 0b10000000 == 0b10000000
        var consumed = 2
        var base = base.advanced(by: 2)
        
        // Binary and continuation frames don't need to be final
        if !final {
            guard code == .continuation || code == .binary || code == .close else {
                throw WebSocketError(.invalidFrameParameters)
            }
        }
        
        // Ping and pong cannot have a bigger payload than tihs
        if code == .ping || code == .pong {
            guard payloadLength < 126 else {
                throw WebSocketError(.invalidFrame)
            }
        }
        
        // Parse the payload length as UInt16 following the 126
        if payloadLength == 126 {
            guard length >= 5 else {
                return nil
            }
            
            payloadLength = base.withMemoryRebound(to: UInt16.self, capacity: 1, { UInt64($0.pointee) })
            
            base = base.advanced(by: 2)
            consumed = consumed &+ 2
            
        // payload length byte == 127 means it's followed by a UInt64
        } else if payloadLength == 127 {
            guard length >= 11 else {
                return nil
            }
            
            payloadLength = base.withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
            
            base = base.advanced(by: 8)
            consumed = consumed &+ 8
        } else {
            // Technically impossible, but good to have
            throw WebSocketError(.invalidFrame)
        }
        
        let mask: [UInt8]?
        
        if isMasked {
            // Ensure the minimum length is available
            guard length &- consumed >= payloadLength &+ 4, payloadLength < Int.max else {
                // throw an invalidFrame for incomplete/invalid
                return nil
            }
            
            guard consumed &+ 4 < length else {
                // throw an invalidFrame for a missing mask buffer
                throw WebSocketError(.invalidMask)
            }
            
            mask = [base[0], base[1], base[2], base[3]]
            base = base.advanced(by: 4)
            consumed = consumed &+ 4
        } else {
            // throw an invalidFrame for incomplete/invalid
            guard length &- consumed >= payloadLength, payloadLength < Int.max else {
                return nil
            }
            
            mask = nil
        }
        
        return (final, code, payloadLength, mask, consumed)
    }

    deinit {
        bufferBuilder.deallocate(capacity: maximumPayloadSize + 15)
    }
}
