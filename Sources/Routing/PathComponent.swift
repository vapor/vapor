import Foundation
import Bits

/// Components of a router path.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public enum PathComponent: ExpressibleByStringLiteral {
    public enum Parameter {
        case data(Data)
        case bytes([UInt8])
        case byteBuffer(ByteBuffer)
        case string(String)
        case substring(Substring)
        
        public var count: Int {
            switch self {
            case .data(let data): return data.count
            case .byteBuffer(let byteBuffer): return byteBuffer.count
            case .bytes(let bytes): return bytes.count
            case .string(let string): return string.utf8.count
            case .substring(let substring): return substring.utf8.count
            }
        }
        
        func withByteBuffer<T>(do closure: (ByteBuffer) -> (T)) -> T {
            switch self {
            case .data(let data): return data.withByteBuffer(closure)
            case .byteBuffer(let byteBuffer): return closure(byteBuffer)
            case .bytes(let bytes): return bytes.withUnsafeBufferPointer(closure)
            case .string(let string):
                let count = self.count
                
                return string.withCString { pointer in
                    return pointer.withMemoryRebound(to: UInt8.self, capacity: count) { pointer in
                        return closure(ByteBuffer(start: pointer, count: count))
                    }
                }
            case .substring(let substring):
                let count = self.count
                
                return substring.withCString { pointer in
                    return pointer.withMemoryRebound(to: UInt8.self, capacity: count) { pointer in
                        return closure(ByteBuffer(start: pointer, count: count))
                    }
                }
            }
        }
        
        public var string: String {
            switch self {
            case .string(let string): return string
            default:
                return String(bytes: self.bytes, encoding: .utf8) ?? ""
            }
        }
        
        public var bytes: [UInt8] {
            switch self {
            case .data(let data): return Array(data)
            case .byteBuffer(let byteBuffer): return Array(byteBuffer)
            case .bytes(let bytes): return bytes
            case .string(let string): return [UInt8](string.utf8)
            case .substring(let substring): return Array(substring.utf8)
            }
        }
    }
    
    /// Create a path component from a string
    public init(stringLiteral value: String) {
        self = .constants(value.split(separator: "/").map { .substring($0) } )
    }
    
    /// A normal, constant path component.
    case constants([Parameter])

    /// A dynamic parameter component.
    case parameter(Parameter)
}

/// Capable of being represented by a path component.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public protocol PathComponentRepresentable {
    /// Convert to path component.
    func makePathComponent() -> PathComponent
}

extension PathComponent: PathComponentRepresentable {
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponent() -> PathComponent {
        return self
    }
}

// MARK: Array

extension Array where Element == PathComponentRepresentable {
    /// Convert to array of path components.
    public func makePathComponents() -> [PathComponent] {
        return map { $0.makePathComponent() }
    }
}

/// Strings are constant path components.
extension String: PathComponentRepresentable {
    /// Convert string to constant path component.
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponent() -> PathComponent {
        return PathComponent(stringLiteral: self)
    }
}
