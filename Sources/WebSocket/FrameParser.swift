import Async
import Bits

public final class FrameParser: ProtocolStream {
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
    
    /// Serialized requests
    var remainingDownstreamRequests: UInt
    
    /// Unrequested backlog
    var backlog = [Output]()
    
    /// Upstream bytebuffer output stream
    private var upstream: ConnectionContext?
    
    /// Downstream frame input stream
    private var downstream: AnyInputStream<Output>?
    
    public init(maximumPayloadSize: Int = 100_000) {
        self.maximumPayloadSize = maximumPayloadSize
        // 2 for the header, 9 for the length, 4 for the mask
        self.bufferBuilder = MutableBytesPointer.allocate(capacity: maximumPayloadSize + 15)
    }
    
    public func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            if let promise = responseQueue.popLast() {
                promise.complete(input)
            } else {
                update()
            }
        case .error(let error): downstream?.error(error)
        case .close: downstream?.close()
        }
    }
    
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            let isSuspended = remainingDownstreamRequests == 0
            remainingDownstreamRequests += count
            if isSuspended { update() }
        case .cancel:
            /// FIXME: better cancel support
            remainingDownstreamRequests = 0
        }
    }
    
    public func output<S>(to inputStream: S) where S : InputStream, FrameParser.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    /// See OutputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        guard var pointer = input.baseAddress, input.count > 0 else {
            // ignore
            return
        }
        
        // Processed the data in a buffer
        //
        // Returns whether the header was successfully parsed into a frame and the amount of consumed bytes to do so
        func process(pointer: BytesPointer, length: Int) -> (Bool, Int) {
            guard let header = try? FrameParser.decodeFrameHeader(from: pointer, length: length) else {
                self.bufferBuilder.advanced(by: accumulated).assign(from: pointer, count: length)
                self.accumulated += length
                return (false, 0)
            }
            
            // Too big packets are rejected to prevent too much memory usage, causing potential crashes
            guard header.size < UInt64(self.maximumPayloadSize) else {
                self.accumulated = 0
                self.onError(WebSocketError(.invalidBufferSize))
                return (false, 0)
            }
            
            let pointer = pointer.advanced(by: header.consumed)
            let remaining = input.count &- header.consumed
            
            // Not enough bytes for a frame
            guard Int(header.size) <= remaining else {
                // Store the remaining data in the buffer
                bufferBuilder.assign(from: pointer, count: input.count)
                self.processing = header
                self.accumulated += input.count
                return (false, 0)
            }
            
            do {
                let frame = try Frame(op: header.op, payload: ByteBuffer(start: pointer, count: Int(header.size)), mask: header.mask, isMasked: header.mask != nil, isFinal: true)
                
                self.outputStream.onInput(frame)
                return (true, frame.buffer.count)
            } catch {
                onError(error)
                return (false, 0)
            }
        }
        
        // If a header was already processed
        if let header = processing {
            let total = Int(header.size)
            
            // Parse the frame if we have enough bytes
            if accumulated + input.count >= total {
                let consume = total &- accumulated
                
                bufferBuilder.advanced(by: accumulated).assign(from: pointer, count: consume)
                
                do {
                    let frame = try Frame(op: header.op, payload: ByteBuffer(start: bufferBuilder, count: Int(header.size)), mask: header.mask, isMasked: header.mask != nil, isFinal: true)
                    
                    self.outputStream.onInput(frame)
                } catch {
                    onError(error)
                }
                
                self.onInput(ByteBuffer(start: pointer.advanced(by: consume), count: input.count &- consume))
            } else {
                // Store the remaining bytes since there's not enough for a frame
                bufferBuilder.advanced(by: accumulated).assign(from: pointer, count: input.count)
            }
        } else if accumulated > 0 {
            // We accumulated data already
            
            // If we're accumulating too much
            guard accumulated + input.count < UInt64(self.maximumPayloadSize) else {
                // reject
                self.accumulated = 0
                onError(WebSocketError(.invalidBufferSize))
                return
            }
            
            // Add the new data to the accumulated data
            bufferBuilder.advanced(by: accumulated).assign(from: pointer, count: input.count)
            accumulated += input.count
            
            // process the incoming data
            let (successful, byteLength) =  process(pointer: pointer, length: input.count)
            
            // If the processing was successful
            if successful {
                // Add the unconsumed data to a pointer, and process that now
                let unconsumed = accumulated &- byteLength
                let pointer = MutableBytesPointer.allocate(capacity: unconsumed)
                pointer.assign(from: pointer.advanced(by: byteLength), count: unconsumed)
                
                defer { pointer.deallocate(capacity: unconsumed) }
                
                self.onInput(ByteBuffer(start: pointer, count: unconsumed))
            }
        } else {
            var length = input.count
            var successful: Bool
            var byteLength: Int
            
            repeat {
                (successful, byteLength) = process(pointer: pointer, length: length)
                pointer = pointer.advanced(by: byteLength)
                length = length &- byteLength
            } while successful && length > 0
        }
    }
    
    static func decodeFrameHeader(from base: UnsafePointer<UInt8>, length: Int) throws -> Frame.Header {
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
                throw WebSocketError(.invalidFrame)
            }
            
            payloadLength = base.withMemoryRebound(to: UInt16.self, capacity: 1, { UInt64($0.pointee) })
            
            base = base.advanced(by: 2)
            consumed = consumed &+ 2
            
        // payload length byte == 127 means it's followed by a UInt64
        } else if payloadLength == 127 {
            guard length >= 11 else {
                throw WebSocketError(.invalidFrame)
            }
            
            payloadLength = base.withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
            
            base = base.advanced(by: 8)
            consumed = consumed &+ 8
        }
        
        let mask: [UInt8]?
        
        if isMasked {
            // Ensure the minimum length is available
            guard length &- consumed >= payloadLength &+ 4, payloadLength < Int.max else {
                // throw an invalidFrame for incomplete/invalid
                throw WebSocketError(.invalidFrame)
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
                throw WebSocketError(.invalidFrame)
            }
            
            mask = nil
        }
        
        return (final, code, payloadLength, mask, consumed)
    }

    deinit {
        bufferBuilder.deallocate(capacity: maximumPayloadSize + 15)
    }
}
