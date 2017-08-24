import Core
import Dispatch
import Foundation

/// Internal Swift HTTP serializer protocol.
internal protocol Serializer: Core.Stream { }

extension Serializer {
    internal func serialize(header name: Headers.Name, value: String) -> DispatchData {
        return DispatchData("\(name): \(value)\r\n")
    }

    internal func serialize(_ body: Body) -> DispatchData {
        let pointer: BytesPointer = body.data.withUnsafeBytes { $0 }
        let bodyRaw = UnsafeRawBufferPointer(
            start: UnsafeRawPointer(pointer),
            count: body.data.count
        )
        return DispatchData(bytes: bodyRaw)
    }

    public var eol: DispatchData {
        return _eol
    }
}

fileprivate let _eol = DispatchData("\r\n")

extension DispatchData {
    init(_ string: String) {
        self.init(bytes: string.unsafeRawBufferPointer)
    }
}

extension String {
    var unsafeRawBufferPointer: UnsafeRawBufferPointer {
        let data = self.data(using: .utf8) ?? Data()
        return data.withUnsafeBytes { pointer in
            return UnsafeRawBufferPointer(start: pointer, count: data.count)
        }
    }
}
