import Foundation
import Dispatch
import Bits

/// Represents an HTTP Message's Body.
///
/// This can contain any data and should match the Message's "Content-Type" header.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
public struct HTTPBody: Codable {
    /// The internal storage medium.
    ///
    /// NOTE: This is an implementation detail
    enum Storage: Codable {
        case data(Data)
        case staticString(StaticString)
        case dispatchData(DispatchData)
        case stream(BodyStream)
        case string(String)
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .data(let data):
                try data.encode(to: encoder)
            case .dispatchData(let data):
                try Data(data).encode(to: encoder)
            case .staticString(let string):
                try Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount).encode(to: encoder)
            case .string(let string):
                try string.encode(to: encoder)
            case .stream(_): return
            }
        }
        
        init(from decoder: Decoder) throws {
            self = .data(try Data(from: decoder))
        }
        
        /// The size of this buffer
        var count: Int {
            switch self {
            case .data(let data): return data.count
            case .dispatchData(let data): return data.count
            case .staticString(let staticString): return staticString.utf8CodeUnitCount
            case .string(let string): return string.utf8.count
            case .stream(_): return 0
            }
        }
        
        /// Accesses the bytes of this data
        func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) throws -> Return {
            switch self {
            case .data(let data):
                return try data.withUnsafeBytes(run)
            case .dispatchData(let data):
                return try data.withUnsafeBytes(body: run)
            case .staticString(let staticString):
                return try run(staticString.utf8Start)
            case .string(let string):
                return try string.withCString { pointer in
                    return try pointer.withMemoryRebound(to: UInt8.self, capacity: self.count, run)
                }
            case .stream(_):
                throw HTTPError(identifier: "invalid-stream-acccess", reason: "A BodyStream was being accessed as a sequential byte buffer, which is impossible.")
            }
        }
    }
    
    /// The underlying storage type
    var storage: Storage
    
    /// Creates an empty body
    public init() {
        self.init(Data())
    }
    
    /// Create a new body wrapping `Data`.
    public init(_ data: Data) {
        storage = .data(data)
    }
    
    /// Create a new body wrapping `DispatchData`.
    public init(_ data: DispatchData) {
        storage = .dispatchData(data)
    }
    
    /// Create a new body from the UTF-8 representation of a StaticString
    public init(staticString: StaticString) {
        storage = .staticString(staticString)
    }
    
    /// Create a new body from the UTF-8 representation of a string
    public init(string: String) {
        let data = string.data(using: .utf8) ?? Data()
        
        self.storage = .data(data)
    }
    
    public init(chunked stream: BodyStream) {
        self.storage = .stream(stream)
    }
    
    /// Decodes a body from from a Decoder
    public init(from decoder: Decoder) throws {
        self.storage = try Storage(from: decoder)
    }
    
    /// Executes a closure with a pointer to the start of the data
    ///
    /// Can be used to read data from this buffer until the `count`.
    public func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) throws -> Return {
        return try self.storage.withUnsafeBytes(run)
    }

    /// Get body data.
    public var data: Data? {
        switch storage {
        case .data(let data):
            return data
        case .dispatchData(let dispatch):
            return Data(dispatch)
        case .staticString(_):
            return nil
        case .string(let string):
            return Data(string.utf8)
        case .stream(_):
            return nil
        }
    }
    
    /// The size of the data buffer
    public var count: Int {
        return self.storage.count
    }
}

/// Can be converted to an HTTP body.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/body/#bodyrepresentable)
public protocol HTTPBodyRepresentable {
    /// Convert to an HTTP body.
    func makeBody() throws -> HTTPBody
}

/// String can be represented as an HTTP body.
extension String: HTTPBodyRepresentable {
    /// See BodyRepresentable.makeBody()
    public func makeBody() throws -> HTTPBody {
        return HTTPBody(string: self)
    }
}
