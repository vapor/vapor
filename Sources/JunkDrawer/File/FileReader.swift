import Async
import Bits
import Dispatch
import Foundation

/// Capable of reading files asynchronously.
public protocol FileReader {
    /// Reads the file at the supplied path
    /// Supply a queue to complete the future on.
    func read<S>(at path: String, into stream: S)
        where S: Async.InputStream, S.Input == ByteBuffer

    /// Returns true if the file exists at the supplied path.
    func fileExists(at path: String) -> Bool

    /// Returns true if a directory exists at the supplied path.
    func directoryExists(at path: String) -> Bool
}

extension FileReader {
    /// Reads data at the supplied path and combines into one Data.
    public func read(at path: String) -> Future<Data> {
        let promise = Promise(Data.self)

        var data = Data()
        let stream = ClosureStream<ByteBuffer>(
            onInput: { data.append(contentsOf: $0) },
            onError: { promise.fail($0) },
            onClose: { promise.complete(data) },
            onOutput: { $0.requestOutput(.max) },
            onRequest: { _ in },
            onCancel: { },
            outputTo: { _ in }
        )
        self.read(at: path, into: stream)
        return promise.future
    }
}
