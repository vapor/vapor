#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
#warning("Make this internal")
public import NIOCore
import NIOFoundationEssentialsCompat
import HTTPTypes
import NIOPosix

extension Response {
    struct BodyStream {
        let count: Int
        let callback: @Sendable (any ResponseBodyWriter) async throws -> ()
    }

    /// Represents a `Response`'s body.
    ///
    ///     let body = Response.Body(string: "Hello, world!")
    ///
    /// This can contain any data (streaming or static) and should match the message's `"Content-Type"` header.
    public struct Body: CustomStringConvertible, ExpressibleByStringLiteral, Sendable {
        /// The internal HTTP body storage enum. This is an implementation detail.
        internal enum Storage: Sendable {
            /// Cases
            case none
            case buffer(ByteBuffer)
            case data(Data)
            case staticString(StaticString)
            case string(String)
            case stream(BodyStream)
        }

        /// An empty `Response.Body`.
        public static let empty: Body = .init()

        public var string: String? {
            switch self.storage {
            case .buffer(var buffer): return buffer.readString(length: buffer.readableBytes)
            case .data(let data): return String(decoding: data, as: UTF8.self)
            case .staticString(let staticString): return staticString.description
            case .string(let string): return string
            default: return nil
            }
        }

        /// The size of the HTTP body's data.
        /// `-1` is a chunked stream.
        public var count: Int {
            switch self.storage {
            case .data(let data): return data.count
            case .staticString(let staticString): return staticString.utf8CodeUnitCount
            case .string(let string): return string.utf8.count
            case .buffer(let buffer): return buffer.readableBytes
            case .none: return 0
            case .stream(let stream): return stream.count
            }
        }

        /// Returns static data if not streaming.
        public var data: Data? {
            switch self.storage {
            case .buffer(var buffer): return buffer.readData(length: buffer.readableBytes)
            case .data(let data): return data
            case .staticString(let staticString): return unsafe Data(bytes: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
            case .string(let string): return Data(string.utf8)
            case .none: return nil
            case .stream: return nil
            }
        }

        public var buffer: ByteBuffer? {
            switch self.storage {
            case .buffer(let buffer): return buffer
            case .data(let data):
                let buffer = self.byteBufferAllocator.buffer(bytes: data)
                return buffer
            case .staticString(let staticString):
                let buffer = self.byteBufferAllocator.buffer(staticString: staticString)
                return buffer
            case .string(let string):
                let buffer = self.byteBufferAllocator.buffer(string: string)
                return buffer
            case .none: return nil
            case .stream: return nil
            }
        }

        public func collect() async throws -> Data? {
            switch self.storage {
            case .stream(let stream):
                // Reserve the declared length up front when known (`count >= 0`) to avoid repeated
                // grow-and-copy reallocations; `-1` means unknown/chunked, so start empty.
                let initialCapacity = stream.count >= 0 ? stream.count : 0
                let writer = CollectingBodyWriter(buffer: self.byteBufferAllocator.buffer(capacity: initialCapacity))
                try await stream.callback(writer)
                return writer.buffer.readData(length: writer.buffer.readableBytes)
            default:
                return self.buffer?.getData(at: 0, length: self.buffer?.readableBytes ?? 0)
            }
        }

        // See `CustomStringConvertible.description`.
        public var description: String {
            switch storage {
            case .none: return "<no body>"
            case .buffer(let buffer): return buffer.getString(at: 0, length: buffer.readableBytes) ?? "n/a"
            case .data(let data): return String(data: data, encoding: .ascii) ?? "n/a"
            case .staticString(let string): return string.description
            case .string(let string): return string
            case .stream: return "<stream>"
            }
        }

        internal var storage: Storage
        internal let byteBufferAllocator: ByteBufferAllocator

        /// Creates an empty body. Useful for `GET` requests where HTTP bodies are forbidden.
        public init(byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            self.storage = .none
        }

        /// Create a new body wrapping `Data`.
        public init(data: Data, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            storage = .data(data)
        }

        /// Create a new body from the UTF8 representation of a `StaticString`.
        public init(staticString: StaticString, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            storage = .staticString(staticString)
        }

        /// Create a new body from the UTF8 representation of a `String`.
        public init(string: String, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            self.storage = .string(string)
        }

        /// Create a new body from a Swift NIO `ByteBuffer`.
        public init(buffer: ByteBuffer, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            self.storage = .buffer(buffer)
        }

        /// Creates a chunked, streaming HTTP ``Response`` body.
        ///
        /// The closure receives a ``ResponseBodyWriter`` and writes chunks to it with `await`. Writes are
        /// backpressured by the transport, so the closure naturally throttles to the speed of the client.
        /// Throwing from the closure fails the response.
        ///
        /// - Parameters:
        ///   - stream: The closure that writes the body chunks.
        ///   - count: The number of bytes that will be written. The `stream` **MUST** produce exactly `count` bytes.
        ///   - byteBufferAllocator: The allocator that is preferred when writing data to SwiftNIO
        public init(stream: @escaping @Sendable (any ResponseBodyWriter) async throws -> (), count: Int, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.byteBufferAllocator = byteBufferAllocator
            self.storage = .stream(.init(count: count, callback: stream))
        }

        /// Creates a chunked, streaming HTTP ``Response`` body of unknown length.
        ///
        /// See ``init(stream:count:byteBufferAllocator:)`` for the streaming semantics.
        ///
        /// - Parameters:
        ///   - stream: The closure that writes the body chunks.
        ///   - byteBufferAllocator: The allocator that is preferred when writing data to SwiftNIO
        public init(stream: @escaping @Sendable (any ResponseBodyWriter) async throws -> (), byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()) {
            self.init(stream: stream, count: -1, byteBufferAllocator: byteBufferAllocator)
        }

        /// `ExpressibleByStringLiteral` conformance.
        public init(stringLiteral value: String) {
            self.byteBufferAllocator = ByteBufferAllocator()
            self.storage = .string(value)
        }

        /// Internal init.
        internal init(storage: Storage, byteBufferAllocator: ByteBufferAllocator) {
            self.byteBufferAllocator = byteBufferAllocator
            self.storage = storage
        }
    }
}

/// A ``ResponseBodyWriter`` that accumulates everything written into a `ByteBuffer`, used to
/// eagerly collect a streaming body instead of forwarding it to the connection.
private final class CollectingBodyWriter: ResponseBodyWriter {
    var buffer: ByteBuffer

    init(buffer: ByteBuffer) {
        self.buffer = buffer
    }

    func write(_ buffer: ByteBuffer) async throws {
        var buffer = buffer
        self.buffer.writeBuffer(&buffer)
    }

    func write(_ bytes: RawSpan) async throws {
    }
}
