import Async
import Bits
import Foundation

extension HTTPBody {
    /// Serialized a body to an outputstream
    func serialize<S: Serializer>(into outputStream: S) {
        switch self.storage {
        case .dispatchData(let data):
            Data(data).withByteBuffer(outputStream.write)
        case .data(let data):
            data.withByteBuffer(outputStream.write)
        case .staticString(let string):
            let buffer = UnsafeBufferPointer(start: string.utf8Start, count: string.utf8CodeUnitCount)
            
            outputStream.write(buffer)
        case .string(let string):
            let size = string.utf8.count
            
            string.withCString { pointer in
                pointer.withMemoryRebound(to: UInt8.self, capacity: size) { pointer in
                    outputStream.write(ByteBuffer(start: pointer, count: size))
                }
            }
        case .stream(let bodyStream):
            bodyStream.stream(to: ChunkEncoder()).drain(onInput: outputStream.write).catch(onError: outputStream.onError)
        }
    }
}
