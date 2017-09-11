import Bits
import Dispatch
import Foundation
import Async

/// Internal Swift HTTP serializer protocol.
internal protocol Serializer: Async.Stream { }

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
        let bytes = string.withCString { pointer in
            return UnsafeRawBufferPointer(
                start: pointer,
                count: string.utf8.count
            )
        }
        self.init(bytes: bytes)
    }
}
