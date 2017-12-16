import Async
import Bits
import Dispatch
import Foundation

/// Capable of reading files asynchronously.
public protocol FileReader {
    /// Reads the file at the supplied path
    /// Supply a queue to complete the future on.
    func read<S>(at path: String, into stream: S, chunkSize: Int)
        where S: Async.InputStream, S.Input == ByteBuffer

    /// Returns true if the file exists at the supplied path.
    func fileExists(at path: String) -> Bool

    /// Returns true if a directory exists at the supplied path.
    func directoryExists(at path: String) -> Bool
}

extension FileReader {
    /// Reads data at the supplied path and combines into one Data.
    public func read(at path: String, chunkSize: Int) -> Future<Data> {
        let promise = Promise(Data.self)

        var data = Data()
        let stream = ClosureStream<ByteBuffer>.init(
            onInput: { event in
                switch event {
                case .next(let input): data.append(contentsOf: input)
                case .error(let e): promise.fail(e)
                case .connect(let upstream): upstream.request(count: .max)
                case .close: promise.complete(data)
                }
            },
            onOutput: { _ in }, // not used as an output stream
            onConnection: { _ in } // not used as a connection context
        )
        self.read(at: path, into: stream, chunkSize: chunkSize)
        return promise.future
    }

    /// Reads data at the supplied path into a FileOutputStream.
    public func read(at path: String, chunkSize: Int) -> FileOutputStream {
        let stream = ConnectingStream<ByteBuffer>()
        defer { read(at: path, into: stream, chunkSize: chunkSize) }
        return .init(stream)
    }
}

public typealias FileOutputStream = AnyOutputStream<ByteBuffer>
