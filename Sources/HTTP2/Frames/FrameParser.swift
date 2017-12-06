import Async
import Bits
import Foundation

/// Transforms an input bytes stream into a stream of frames
final class FrameParser: Async.Stream {
    /// See `InputStream.Input`
    typealias Input = ByteBuffer
    
    /// See `OutputStream.Output`
    typealias Output = Frame
    
    /// The maximum size of a frame
    var maxFrameSize: UInt32
    
    /// Stores the HTTP2 remote server's settings
    var settings = HTTP2Settings()
    
    /// The payload length of the currently parsing packet
    var payloadLength: UInt32 = 0
    
    /// The payload type of the currently parsing packet
    var type: Frame.FrameType?
    
    /// The flags of the currently parsing packet
    var flags: UInt8?
    
    /// The stream id of the currently parsing packet
    var streamIdentifier: Int32 = 0
    
    /// The currently parsed length
    var parsed: UInt64 = 0
    
    /// The in-progress parsing payload
    var payload = Data()
    
    let stream = BasicStream<Output>()
    
    /// Creates a new frame parser
    init(maxFrameSize: UInt32) {
        self.maxFrameSize = maxFrameSize
        self.payload.reserveCapacity(numericCast(self.maxFrameSize))
    }
    
    /// Resets all variables used for parsing to their defaults
    func reset() {
        self.payloadLength = 0
        self.type = nil
        self.flags = nil
        self.streamIdentifier = 0
        self.parsed = 0
        self.payload = Data()
        self.payload.reserveCapacity(numericCast(self.maxFrameSize))
    }
    
    /// Process the next buffer
    func onInput(_ input: ByteBuffer) {
        do {
            try self.process(buffer: input)
        } catch {
            self.onError(error)
        }
    }
    
    /// Processthe input buffer and tries to emit a frame
    ///
    /// throws an error on invalid frames
    func process(buffer input: ByteBuffer) throws {
        // Empty buffers are invalid
        guard let pointer = input.baseAddress else {
            throw HTTP2Error(.invalidFrameReceived)
        }
        
        var offset = 0
        
        // Returns `true` if you can continue parsing after processing the next byte
        func continueNextByte(offset minimum: Int, _ closure: (() throws -> ())) rethrows -> Bool {
            if parsed > minimum {
                return true
            }
            
            guard offset < input.count else {
                return false
            }
            
            try closure()
            
            parsed = parsed &+ 1
            offset = offset &+ 1
            
            return true
        }
        
        // Continue for all data
        while offset < input.count {
            // Process the first byte (payload length high byte)
            guard (continueNextByte(offset: 0) {
                payloadLength |= numericCast(pointer[offset]) << 16
            }) else {
                return
            }
            
            // Process the second byte (payload length middle byte)
            guard (continueNextByte(offset: 1) {
                payloadLength |= numericCast(pointer[offset]) << 8
            }) else {
                return
            }
            
            // Process the third byte (payload length low byte)
            guard (continueNextByte(offset: 2) {
                payloadLength |= numericCast(pointer[offset])
            }) else {
                return
            }
            
            // Process the frame type byte
            guard (try continueNextByte(offset: 3) {
                guard let frameType = Frame.FrameType(rawValue: pointer[offset]) else {
                    throw HTTP2Error(.invalidFrameReceived)
                }
                
                self.type = frameType
            }) else {
                return
            }
            
            // Process the frame flags byte
            guard (continueNextByte(offset: 4) {
                self.flags = pointer[offset]
            }) else {
                return
            }
            
            // Process the stream identifier first (high) byte
            guard (try continueNextByte(offset: 5) {
                // Reserved bit must not be set
                guard pointer[offset] & 0b10000000 == 0 else {
                    // RESERVED BIT
                    throw HTTP2Error(.invalidFrameReceived)
                }
                
                streamIdentifier |= numericCast((pointer[offset]) << 24)
            }) else {
                return
            }
            
            // Process the stream identifier second byte
            guard (continueNextByte(offset: 6) {
                streamIdentifier |= numericCast((pointer[offset]) << 16)
            }) else {
                return
            }
            
            // Process the stream identifier third byte
            guard (continueNextByte(offset: 7) {
                streamIdentifier |= numericCast((pointer[offset]) << 8)
            }) else {
                return
            }
            
            // Process the stream identifier last low byte
            guard (continueNextByte(offset: 8) {
                streamIdentifier |= numericCast((pointer[offset]))
            }) else {
                return
            }
            
            // Assert that the payload length is within this client's maximum
            guard self.payloadLength < self.maxFrameSize else {
                throw HTTP2Error(.invalidFrameReceived)
            }
            
            // Take the next bytes to fill up the payload
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
                throw HTTP2Error(.invalidFrameReceived)
            }
            
            let frame = Frame(type: type, payload: Payload(data: payload), streamID: streamIdentifier, flags: flags)
            stream.onInput(frame)
            
            reset()
        }
    }
    
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    func onOutput<I>(_ input: I) where I : Async.InputStream, FrameParser.Output == I.Input {
        stream.onOutput(input)
    }
    
    func close() {
        stream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
}
