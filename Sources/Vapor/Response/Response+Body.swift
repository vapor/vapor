extension Response {
    struct BodyStream {
        let count: Int
        let callback: (BodyStreamWriter) -> ()
    }

    /// Represents an `HTTPMessage`'s body.
    ///
    ///     let body = HTTPBody(string: "Hello, world!")
    ///
    /// This can contain any data (streaming or static) and should match the message's `"Content-Type"` header.
    public struct Body: CustomStringConvertible, ExpressibleByStringLiteral {
        /// The internal HTTP body storage enum. This is an implementation detail.
        internal enum Storage {
            /// Cases
            case none
            case buffer(ByteBuffer)
            case data(Data)
            case dispatchData(DispatchData)
            case staticString(StaticString)
            case string(String)
            case stream(BodyStream)
        }
        
        /// An empty `HTTPBody`.
        public static let empty: Body = .init()
        
        public var string: String? {
            switch self.storage {
            case .buffer(var buffer): return buffer.readString(length: buffer.readableBytes)
            case .data(let data): return String(decoding: data, as: UTF8.self)
            case .dispatchData(let dispatchData): return String(decoding: dispatchData, as: UTF8.self)
            case .staticString(let staticString): return staticString.description
            case .string(let string): return string
            default: return nil
            }
        }
        
        /// The size of the HTTP body's data.
        /// `nil` is a stream.
        public var count: Int {
            switch self.storage {
            case .data(let data): return data.count
            case .dispatchData(let data): return data.count
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
            case .dispatchData(let dispatchData): return Data(dispatchData)
            case .staticString(let staticString): return Data(bytes: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
            case .string(let string): return Data(string.utf8)
            case .none: return nil
            case .stream: return nil
            }
        }
        
        public var buffer: ByteBuffer? {
            switch self.storage {
            case .buffer(let buffer): return buffer
            case .data(let data):
                var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                buffer.writeBytes(data)
                return buffer
            case .dispatchData(let dispatchData):
                var buffer = ByteBufferAllocator().buffer(capacity: dispatchData.count)
                buffer.writeDispatchData(dispatchData)
                return buffer
            case .staticString(let staticString):
                var buffer = ByteBufferAllocator().buffer(capacity: staticString.utf8CodeUnitCount)
                buffer.writeStaticString(staticString)
                return buffer
            case .string(let string):
                var buffer = ByteBufferAllocator().buffer(capacity: string.count)
                buffer.writeString(string)
                return buffer
            case .none: return nil
            case .stream: return nil
            }
        }
        
        /// See `CustomDebugStringConvertible`.
        public var description: String {
            switch storage {
            case .none: return "<no body>"
            case .buffer(let buffer): return buffer.getString(at: 0, length: buffer.readableBytes) ?? "n/a"
            case .data(let data): return String(data: data, encoding: .ascii) ?? "n/a"
            case .dispatchData(let data): return String(data: Data(data), encoding: .ascii) ?? "n/a"
            case .staticString(let string): return string.description
            case .string(let string): return string
            case .stream: return "<stream>"
            }
        }
        
        internal var storage: Storage
        
        /// Creates an empty body. Useful for `GET` requests where HTTP bodies are forbidden.
        public init() {
            self.storage = .none
        }
        
        /// Create a new body wrapping `Data`.
        public init(data: Data) {
            storage = .data(data)
        }
        
        /// Create a new body wrapping `DispatchData`.
        public init(dispatchData: DispatchData) {
            storage = .dispatchData(dispatchData)
        }
        
        /// Create a new body from the UTF8 representation of a `StaticString`.
        public init(staticString: StaticString) {
            storage = .staticString(staticString)
        }
        
        /// Create a new body from the UTF8 representation of a `String`.
        public init(string: String) {
            self.storage = .string(string)
        }
        
        /// Create a new body from a Swift NIO `ByteBuffer`.
        public init(buffer: ByteBuffer) {
            self.storage = .buffer(buffer)
        }
        
        public init(stream: @escaping (BodyStreamWriter) -> (), count: Int) {
            self.storage = .stream(.init(count: count, callback: stream))
        }
        
        /// `ExpressibleByStringLiteral` conformance.
        public init(stringLiteral value: String) {
            self.storage = .string(value)
        }
        
        /// Internal init.
        internal init(storage: Storage) {
            self.storage = storage
        }
    }

}
