import Async
import Bits
import Foundation

public final class FrameParser: Async.Stream {
    public typealias Input = ByteBuffer
    public typealias Output = Frame
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    var settings = HTTP2Settings()
    
    var payloadLength: UInt32 = 0
    var type: Frame.FrameType?
    var flags: UInt8?
    var streamIdentifier: Int32 = 0
    
    var parsed: UInt64 = 0
    var payload = Data()
    
    init() {}
    
    func reset() {
        self.payloadLength = 0
        self.type = nil
        self.flags = nil
        self.streamIdentifier = 0
        self.parsed = 0
        self.payload = Data()
    }
    
    public func inputStream(_ input: ByteBuffer) {
        do {
            try self.process(buffer: input)
        } catch {
            self.errorStream?(error)
        }
    }
    
    func process(buffer input: ByteBuffer) throws {
        guard let pointer = input.baseAddress else {
            errorStream?(Error(.invalidFrameReceived))
            return
        }
        
        var offset = 0
        
        // Returns `true` if you can continue parsing
        func continueNextByte(offset minimum: Int, _ closure: (() throws -> ())) rethrows -> Bool {
            if parsed > minimum {
                return true
            }
            
            guard offset &+ 1 < input.count else {
                return false
            }
            
            try closure()
            
            parsed = parsed &+ 1
            offset = offset &+ 1
            
            return true
        }
        
        while offset < input.count {
            guard (continueNextByte(offset: 0) {
                payloadLength |= numericCast((pointer[offset]) << 16)
            }) else {
                return
            }
            
            guard (continueNextByte(offset: 1) {
                payloadLength |= numericCast((pointer[offset]) << 8)
            }) else {
                return
            }
            
            guard (continueNextByte(offset: 2) {
                payloadLength |= numericCast(pointer[offset])
            }) else {
                return
            }
            
            guard (try continueNextByte(offset: 3) {
                guard let frameType = Frame.FrameType(rawValue: pointer[offset]) else {
                    throw Error(.invalidFrameReceived)
                }
                
                self.type = frameType
                }) else {
                    return
            }
            
            guard (continueNextByte(offset: 4) {
                self.flags = pointer[offset]
            }) else {
                return
            }
            
            guard (try continueNextByte(offset: 5) {
                guard pointer[offset] & 0b10000000 == 0 else {
                    // RESERVED BIT
                    throw Error(.invalidFrameReceived)
                }
                
                streamIdentifier |= numericCast((pointer[offset]) << 24)
            }) else {
                return
            }
            
            guard (continueNextByte(offset: 6) {
                streamIdentifier |= numericCast((pointer[offset]) << 16)
            }) else {
                return
            }
            
            guard (continueNextByte(offset: 7) {
                streamIdentifier |= numericCast((pointer[offset]) << 8)
            }) else {
                return
            }
            
            guard (continueNextByte(offset: 8) {
                streamIdentifier |= numericCast((pointer[offset]))
            }) else {
                return
            }
            
            guard self.payloadLength < settings.maxFrameSize else {
                throw Error(.invalidFrameReceived)
            }
            
            let needed = numericCast(payloadLength) &- payload.count
            let remaining = input.count &- offset
            
            let take = Swift.min(needed, remaining)
            
            let buffer = ByteBuffer(start: pointer.advanced(by: offset), count: take)
            offset = offset &+ take
            
            self.payload.append(contentsOf: Data(buffer))
            
            if payload.count < numericCast(self.payloadLength) {
                return
            }
            
            guard let type = type, let flags = flags else {
                throw Error(.invalidFrameReceived)
            }
            
            let frame = Frame(type: type, payload: Payload(data: payload), streamID: streamIdentifier, flags: flags)
            outputStream?(frame)
            
            reset()
        }
    }
}
