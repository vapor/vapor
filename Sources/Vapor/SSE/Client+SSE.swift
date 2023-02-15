import AsyncHTTPClient
import Algorithms

extension HTTPClientResponse {
    public func getServerSentEvents(allocator: ByteBufferAllocator) -> AsyncThrowingStream<SSEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var text = allocator.buffer(capacity: 1024)
                
                for try await var buffer in body {
                    text.writeBuffer(&buffer)
                    
                    do {
                        for event in try SSEParser.process(sse: &text) {
                            continuation.yield(event)
                        }
                        
                        text.discardReadBytes()
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { reason in
                task.cancel()
            }
        }
    }
}

internal enum SSEParser {
    enum ParsingStatus {
        case nextField, nextEvent, haltParsing
    }
    
    static func process(sse text: inout ByteBuffer) throws -> [SSEvent] {
        var events = [SSEvent]()
        var type = "message"
        var data = [String]()
        
        func checkEndOfEventAndStream() -> ParsingStatus {
            guard let nextCharacter: UInt8 = text.getInteger(at: text.readerIndex) else {
                return .haltParsing
            }
            
            // Blank lines must dispatch an event
            if nextCharacter == 0x0a || nextCharacter == 0x0d {
                if nextCharacter == 0x0d, text.getInteger(at: text.readerIndex, as: UInt8.self) == 0x0a {
                    // Skip the 0x0a as well
                    // CRLF, CR and LF are all valid delimiters
                    text.moveReaderIndex(forwardBy: 2)
                } else {
                    text.moveReaderIndex(forwardBy: 1)
                }
                
                var event = SSEvent(data: SSEValue(unchecked: data))
                event.type = type
                events.append(event)
                
                // reset state
                type = "message"
                data.removeAll(keepingCapacity: true)
                
                return text.readableBytes > 0 ? .nextEvent : .haltParsing
            }
            
            return .nextField
        }
        
        var lastEventReaderIndex = text.readerIndex
        
        repeat {
            switch checkEndOfEventAndStream() {
            case .nextEvent:
                lastEventReaderIndex = text.readerIndex
                fallthrough
            case .nextField:
                guard let colonIndex = text.readableBytesView.firstIndex(where: { byte in
                    byte == 0x3a // `:`
                }) else {
                    // Reset to before this event, as we didn't fully process this
                    text.moveReaderIndex(to: lastEventReaderIndex)
                    return events
                }
                
                guard var lineEndingIndex = text.readableBytesView.firstIndex(where: { byte in
                    byte == 0x0a || byte == 0x0d // `\n` or `\r`
                }) else {
                    // Reset to before this event, as we didn't fully process this
                    text.moveReaderIndex(to: lastEventReaderIndex)
                    return events
                }
                
                guard let key = text.readString(length: colonIndex) else {
                    // Reset to before this event, as we didn't fully process this
                    text.moveReaderIndex(to: lastEventReaderIndex)
                    return events
                }
                
                // Skip past colon
                text.moveReaderIndex(forwardBy: 1)
                
                // Reduce the index by `key size + colon character`
                lineEndingIndex -= colonIndex
                lineEndingIndex -= 1
                
                guard var value = text.readString(length: lineEndingIndex) else {
                    // Reset to before this event, as we didn't fully process this
                    text.moveReaderIndex(to: lastEventReaderIndex)
                    return events
                }
                
                guard let byte: UInt8 = text.readInteger() else {
                    // Reset to before this event, as we didn't fully process this
                    text.moveReaderIndex(to: lastEventReaderIndex)
                    return events
                }
                
                if byte == 0x0d, text.readInteger(as: UInt8.self) == 0x0a {
                    // Skip the 0x0a as well
                    // CRLF, CR and LF are all valid delimiters
                    text.moveReaderIndex(forwardBy: 1)
                }
                // TODO: What if we receive an `\r` here, and a `\n` in the next TCP read? Do we pair them up, or regard one as an empty event?
                
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // see https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation
                switch key {
                case "event":
                    type = value
                case "data":
                    data.append(value)
//                case "id":
//                case "retry":
                default:
                    () // Ignore field
                }
            case .haltParsing:
                text.moveReaderIndex(to: lastEventReaderIndex)
                return events
            }
        } while text.readableBytes > 0
        
        text.moveReaderIndex(to: lastEventReaderIndex)
        return events
    }
}
