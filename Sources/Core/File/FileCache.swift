import Async
import Foundation

/// Capable of caching file data asynchronously.
public protocol FileCache {
    /// Fetches the file from the cache
    /// Supply a queue to complete the future on.
    func getFile<H: Hashable>(hash: H) -> Future<Data?>

    /// Sets the file into the cache
    func setFile<H: Hashable>(file: Data?, hash: H)
}

extension FileReader where Self: FileCache {
    /// Checks the cache for the file path or reads
    /// it from the reader.
    public func cachedRead(at path: String) -> Future<Data> {
        return getFile(hash: path).then { data in
            if let data = data {
                return Future(data)
            } else {
                return self.read(at: path).map { data in
                    self.setFile(file: data, hash: path)
                    return data
                }
            }
        }
    }
}
