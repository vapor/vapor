import Async
import Bits
import Dispatch
import Foundation

/// Internal Swift HTTP serializer protocol.
internal protocol Serializer: Async.Stream { }

extension Serializer {
    internal func serialize(_ body: Body) -> Data {
        switch body.storage {
        case .dispatchData(let data):
            return Data(data)
        case .data(let data):
            return data
        }
    }
}

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
