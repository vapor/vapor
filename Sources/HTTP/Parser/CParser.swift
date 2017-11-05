import Async
import Bits
import CHTTP
import Dispatch
import Foundation

/// Possible header states
enum HeaderState {
    case none
    case value(Headers.Index)
    case key(startIndex: Int, endIndex: Int)
}


/// Internal CHTTP parser protocol
internal protocol CParser: class, Async.Stream {
    var parser: http_parser { get set }
    var settings: http_parser_settings { get set }
}

enum CHTTPParserState {
    case ready
    case parsing
}

extension CParser {
    /// Parses a generic CHTTP message, filling the
    /// ParseResults object attached to the C praser.
    internal func executeParser(max: Int, from buffer: ByteBuffer) throws {
        // call the CHTTP parser
        let parsedCount = http_parser_execute(&parser, &settings, buffer.cPointer, max)

        // if the parsed count does not equal the bytes passed
        // to the parser, it is signaling an error
        guard parsedCount == max else {
            throw HTTPError.invalidMessage()
        }
    }

    internal func reset(_ type: http_parser_type) {
        http_parser_init(&parser, type)
        initialize(&settings)
    }
}

extension CParser {
    /// Initializes the http parser settings with appropriate callbacks.
    func initialize(_ settings: inout http_parser_settings) {
        // called when chunks of the url have been read
        settings.on_url = { parser, chunkPointer, length in
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }

            // append the url bytes to the results
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.url.append(chunkPointer, count: length)
            }
            
            return 0
        }

        // called when chunks of a header field have been read
        settings.on_header_field = { parser, chunkPointer, length in
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }
            
            // check current header parsing state
            switch results.headerState {
            case .none:
                // nothing is being parsed, start a new key
                results.headerState = .key(startIndex: results.headersData.count, endIndex: results.headersData.count + length)
            case .value(let index):
                // there was previously a value being parsed.
                // it is now finished.
                
                results.headersIndexes.append(index)
                
                results.headersData.append(.carriageReturn)
                results.headersData.append(.newLine)
                
                // start a new key
                results.headerState = .key(startIndex: results.headersData.count, endIndex: results.headersData.count + length)
            case .key(let start, let end):
                // there is a key currently being parsed.
                results.headerState = .key(startIndex: start, endIndex: end + length)
            }
            
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.headersData.append(chunkPointer, count: length)
            }

            return 0
        }

        // called when chunks of a header value have been read
        settings.on_header_value = { parser, chunkPointer, length in
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }

            // check the current header parsing state
            switch results.headerState {
            case .none:
                // nothing has been parsed, so this
                // value is useless.
                // (this should never be reached)
                results.headerState = .none
            case .value(var index):
                // there was previously a value being parsed.
                // add the new bytes to it.
                index.nameEndIndex += length
                results.headerState = .value(index)
            case .key(let key):
                // there was previously a key being parsed.
                // it is now finished.
                results.headersData.append(contentsOf: headerSeparator)
                
                // Set a dummy hashvalue
                let index = Headers.Index(
                    nameStartIndex: key.startIndex,
                    nameEndIndex: key.endIndex,
                    valueStartIndex: results.headersData.count,
                    valueEndIndex: results.headersData.count + length,
                    endIndex: results.headersData.count + length + 2
                )
                
                results.headerState = .value(index)
            }
            
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.headersData.append(chunkPointer, count: length)
            }

            return 0
        }

        // called when header parsing has completed
        settings.on_headers_complete = { parser in
            guard let results = CParseResults.get(from: parser) else {
                // signal an error
                return 1
            }

            // check the current header parsing state
            switch results.headerState {
            case .value(let index):
                // there was previously a value being parsed.
                // it should be added to the headers dict.
                
                results.headersIndexes.append(index)
                results.headersData.append(.carriageReturn)
                results.headersData.append(.newLine)
            default:
                // no other cases need to be handled.
                break
            }

            return 0
        }

        // called when chunks of the body have been read
        settings.on_body = { parser, chunk, length in
            guard
                let results = CParseResults.get(from: parser),
                let chunk = chunk
            else {
                // signal an error
                return 1
            }

            chunk.withMemoryRebound(to: UInt8.self, capacity: length) { pointer in
                results.body.append(pointer, count: length)
            }
                
            return 0
        }

        // called when the message is finished parsing
        settings.on_message_complete = { parser in
            guard
                let parser = parser,
                let results = CParseResults.get(from: parser)
            else {
                // signal an error
                return 1
            }

            // mark the results as complete
            results.isComplete = true

            // parse version
            let major = Int(parser.pointee.http_major)
            let minor = Int(parser.pointee.http_minor)
            results.version = Version(major: major, minor: minor)

            return 0
        }
    }
}

// MARK: Utilities

extension UnsafeBufferPointer where Element == Byte {
    fileprivate var cPointer: UnsafePointer<CChar> {
        return baseAddress.unsafelyUnwrapped.withMemoryRebound(to: CChar.self, capacity: count) { $0 }
    }
}

fileprivate let headerSeparator = Data([.colon, .space])

extension Data {
    fileprivate var cPointer: UnsafePointer<CChar> {
        return withUnsafeBytes { $0 }
    }
}

extension UnsafePointer where Pointee == CChar {
    /// Creates a Bytes array from a C pointer
    fileprivate func makeBuffer(length: Int) -> UnsafeRawBufferPointer {
        let pointer = UnsafeBufferPointer(start: self, count: length)

        guard let base = pointer.baseAddress else {
            return UnsafeRawBufferPointer(start: nil, count: 0)
        }

        return base.withMemoryRebound(to: UInt8.self, capacity: length) { pointer in
            return UnsafeRawBufferPointer(start: pointer, count: length)
        }
    }
}

