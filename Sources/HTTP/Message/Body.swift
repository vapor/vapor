import Foundation

/// Represents an HTTP body.
public struct Body: Codable {
    /// The body's data.
    public var data: Data

    /// Createa new body.
    public init(_ data: Data = Data()) {
        self.data = data
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
