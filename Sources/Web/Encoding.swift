import Foundation

public protocol MultipartContentCoder {
    init(headers: Headers) throws
    
    func encode(_ data: Data) throws -> Data
    func decode(_ data: Data) throws -> Data
}

public enum Encoding {
    public static var registery: [String: MultipartContentCoder.Type] = [
        "binary": BinaryContentCoder.self
    ]
    
    public static let binary = BinaryContentCoder()
}

public final class BinaryContentCoder: MultipartContentCoder {
    public init() {}
    public init(headers: Headers) throws {}
    
    public func encode(_ data: Data) throws -> Data {
        return data
    }
    
    public func decode(_ data: Data) throws -> Data {
        return data
    }
}
