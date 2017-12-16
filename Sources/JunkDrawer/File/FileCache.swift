import Async
import Foundation

/// Capable of caching file data asynchronously.
public protocol FileCache {
    /// Fetches the file from the cache
    /// Supply a queue to complete the future on.
    func getCachedFile(at path: String) -> Data?

    /// Sets the file into the cache
    func setCachedFile(file: Data?, at path: String)
}

extension FileReader where Self: FileCache {
    /// Checks the cache for the file path or reads
    /// it from the reader.
    public func cachedRead(at path: String, chunkSize: Int) -> Future<Data> {
        if let data = getCachedFile(at: path) {
            return Future(data)
        } else {
            return read(at: path, chunkSize: chunkSize).map(to: Data.self) { data in
                self.setCachedFile(file: data, at: path)
                return data
            }
        }
    }
}
