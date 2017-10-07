import Foundation
import Bits

/// Represents an HTTP body.
public enum Body: Codable {
    case data(Data)
    case dispatchData(DispatchData)
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .data(let data): try data.encode(to: encoder)
        case .dispatchData(let data): try Data(data).encode(to: encoder)
        }
    }
    
    public func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) rethrows -> Return {
        switch self {
        case .data(let data):
            return try data.withUnsafeBytes(run)
        case .dispatchData(let data):
            return try data.withUnsafeBytes(body: run)
        }
    }
    
    public var count: Int {
        switch self {
        case .data(let data): return data.count
        case .dispatchData(let data): return data.count
        }
    }
    
    public init(from decoder: Decoder) throws {
        self = .data(try Data(from: decoder))
    }

    public init() {
        self.init(Data())
    }
    
    /// Create a new body.
    public init(_ data: Data) {
        self = .data(data)
    }
    
    /// Create a new body.
    public init(_ data: DispatchData) {
        self = .dispatchData(data)
    }
}

/// Can be converted to an HTTP body.
public protocol BodyRepresentable {
    /// Convert to an HTTP body.
    func makeBody() throws -> Body
}

/// String can be represented as an HTTP body.
extension String: BodyRepresentable {
    /// See BodyRepresentable.makeBody()
    public func makeBody() throws -> Body {
        let data = self.data(using: .utf8) ?? Data()
        return Body(data)
    }
}
