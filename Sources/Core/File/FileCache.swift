import Foundation

/// Capable of caching file data asynchronously.
public protocol FileCache {
    /// Fetches the file from the cache
    /// Supply a queue to complete the future on.
    func getFile<H: Hashable>(hash: H, on queue: DispatchQueue) -> Future<Data?>

    /// Sets the file into the cache
    func setFile<H: Hashable>(file: Data?, hash: H)
}

extension FileReader where Self: FileCache {
    /// Checks the cache for the file path or reads
    /// it from the reader.
    public func cachedRead(at path: String, on queue: DispatchQueue) -> Future<Data> {
        let promise = Promise(Data.self)

        getFile(hash: path, on: queue).then { data in
            if let data = data {
                promise.complete(data)
            } else {
                self.read(at: path, on: queue).then { data in
                    self.setFile(file: data, hash: path)
                    promise.complete(data)
                }.catch { error in
                    promise.fail(error)
                }
            }
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}
