import Async
import Bits
import Dispatch
import Foundation

/// Internal Swift HTTP serializer protocol.
internal protocol Serializer: Async.Stream { }

extension Serializer {
    internal func serialize(_ body: Body) -> DispatchData {
        switch body.storage {
        case .dispatchData(let data):
            return data
        case .data(_):
            return body.withUnsafeBytes { (pointer: BytesPointer) in
                let bodyRaw = UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(pointer),
                    count: body.count
                )
                return DispatchData(bytes: bodyRaw)
            }
        }
    }
    
    internal func serialize(_ headers: Headers) -> DispatchData {
        var data = Data()
        
        // Magic numer `64` is reserves space per header (seems sensible)
        data.reserveCapacity(headers.storage.count * 64)
        
        for (name, value) in headers {
            data.append(contentsOf: name.original.utf8)
            data.append(headerKeyValueSeparator)
            data.append(contentsOf: value.utf8)
            data.append(eol)
        }
        data.append(eol)
        
        return data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = UnsafeRawBufferPointer(
                start: UnsafeRawPointer(pointer),
                count: data.count
            )
            
            return DispatchData(bytes: buffer)
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
