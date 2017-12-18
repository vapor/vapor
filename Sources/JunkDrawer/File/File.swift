import Async
import Bits
import COperatingSystem
import Dispatch
import Foundation

public final class File: FileReader, FileCache {
    /// Cached data.
    private var cache: [Int: Data]

    /// This file's queue. Must be sync.
    /// all calls to this File reader must be made
    /// from this queue.
    let eventLoop: EventLoop

    private var source: EventSource?

    /// Create a new CFile
    /// FIXME: add cache maximum
    public init(on worker: Worker) {
        self.cache = [:]
        self.eventLoop = worker.eventLoop
    }

    /// See FileReader.read
    public func read<S>(at path: String, into stream: S, chunkSize: Int)
        where S: Async.InputStream, S.Input == ByteBuffer
    {
        eventLoop.async {
            if let data = FileManager.default.contents(atPath: path) {
                data.withByteBuffer(stream.next)
            } else {
                stream.error(FileError(.readError(0, path: path)))
            }
            stream.close()
        }
//        func onError(_ error: Error) {
//            stream.error(error)
//            stream.close()
//        }
//
//        guard let file = fopen(path, "rb") else {
//            let error = FileError(.readError(0, path: path))
//            onError(error)
//            return
//        }
//
//        let descriptor = fileno(file)
//        let buffer = MutableByteBuffer(start: .allocate(capacity: chunkSize), count: chunkSize)
//        let source = eventLoop.onReadable(descriptor: descriptor) { isCancelled in
//            print("file read callback")
//            if isCancelled {
//                stream.close()
//            } else {
//                let read = fread(buffer.baseAddress, chunkSize, 1, file); // Read in the entire file
//                if read > 0 {
//                    let view = ByteBuffer(start: buffer.baseAddress, count: read)
//                    print(view)
//                    stream.next(view)
//                } else {
//                    fclose(file)
//                    stream.close()
//                }
//            }
//        }
//
//        source.resume()
//        self.source = source
    }

    /// See FileReader.fileExists
    public func fileExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            return false
        }
        return !isDirectory.boolValue
    }

    /// See FileReader.directoryExists
    public func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            return false
        }
        return isDirectory.boolValue
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

#if os(Linux)
    extension Bool {
        fileprivate var boolValue: Bool { return self }
    }
#endif
