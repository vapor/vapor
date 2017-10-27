import Foundation
import Dispatch
import Bits

/// Represents an HTTP Message's Body.
///
/// This can contain any data and should match the Message's "Content-Type" header.
///
/// http://localhost:8000/http/body/
public struct Body: Codable {
    /// The internal storage medium.
    ///
    /// NOTE: This is an implementation detail
    enum Storage: Codable {
        case data(Data)
        case dispatchData(DispatchData)
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .data(let data): try data.encode(to: encoder)
            case .dispatchData(let data): try Data(data).encode(to: encoder)
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
            }
        }
        
        /// Accesses the bytes of this data
        func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) rethrows -> Return {
            switch self {
            case .data(let data):
                return try data.withUnsafeBytes(run)
            case .dispatchData(let data):
                return try data.withUnsafeBytes(body: run)
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
    
    public init(string: String) {
        let data = string.data(using: .utf8) ?? Data()
        
        self.storage = .data(data)
    }
    
    /// Decodes a body from from a Decoder
    public init(from decoder: Decoder) throws {
        self.storage = try Storage(from: decoder)
    }
    
    /// Executes a closure with a pointer to the start of the data
    ///
    /// Can be used to read data from this buffer until the `count`.
    public func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) rethrows -> Return {
        return try self.storage.withUnsafeBytes(run)
    }
    
    /// The size of the data buffer
    public var count: Int {
        return self.storage.count
    }
}

/// Can be converted to an HTTP body.
///
/// http://localhost:8000/http/body/#bodyrepresentable
public protocol BodyRepresentable {
    /// Convert to an HTTP body.
    func makeBody() throws -> Body
}

/// String can be represented as an HTTP body.
extension String: BodyRepresentable {
    /// See BodyRepresentable.makeBody()
    public func makeBody() throws -> Body {
        return Body(string: self)
    }
}
