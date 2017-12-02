import Async
import Bits
import Dispatch
import Foundation
import libc

public final class File: FileReader, FileCache {
    /// Cached data.
    private var cache: [Int: Data]

    /// This file's queue. Must be sync.
    /// all calls to this File reader must be made
    /// from this queue.
    let queue: DispatchQueue

    /// Create a new CFile
    /// FIXME: add cache maximum
    public init(queue: DispatchQueue) {
        self.cache = [:]
        self.queue = queue
    }

    /// See FileReader.read
    public func read<S>(at path: String, into stream: S, chunkSize: Int = 2048)
        where S: Async.InputStream, S.Input == ByteBuffer
    {
        func onError(_ error: Error) {
            stream.onError(error)
            stream.close()
        }

        let file = DispatchIO(
            type: .stream,
            path: path,
            oflag: O_RDONLY,
            mode: 0,
            queue: queue
        ) { error in
            if error == 0 {
                // success
            } else {
                let error = FileError(.readError(error, path: path))
                onError(error)
            }
        }

        if let file = file {
            file.setLimit(highWater: chunkSize)
            file.read(offset: 0, length: size_t.max - 1, queue: queue) { done, data, error in
                if done {
                    if error == 0 {
                        stream.close()
                    } else {
                        onError(FileError(.readError(error, path: path)))
                    }
                } else {
                    if let data = data {
                        Data(data).withByteBuffer(stream.onInput)
                    } else {
                        onError(FileError(.readError(error, path: path)))
                    }
                }
            }
        } else {
            onError(FileError(.invalidDescriptor))
        }
    }

    /// See FileReader.fileExists
    public func fileExists(at path: String) -> Bool {
        return access(path, F_OK) != -1
    }

    /// See FileCache.getFile
    public func getCachedFile(at path: String) -> Data? {
        return cache[path.hashValue]
    }

    /// See FileCache.setFile
    public func setCachedFile(file: Data?, at path: String) {
        cache[path.hashValue] = file
    }
}
