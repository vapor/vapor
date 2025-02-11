import NIOCore
import NIOPosix
import AsyncKit
import _NIOFileSystem

extension Environment {
    /// Reads a file's content for a secret. The secret key is the name of the environment variable that is expected to
    /// specify the path of the file containing the secret.
    ///
    /// - Parameters:
    ///   - key: The environment variable name
    ///   - fileIO: `NonBlockingFileIO` handler provided by NIO
    ///   - eventLoop: `EventLoop` for NIO to use for working with the file
    ///
    /// Example usage:
    ///
    /// ````
    /// func configure(_ app: Application) {
    ///     // ...
    ///
    ///     let databasePassword = try Environment.secret(
    ///         key: "DATABASE_PASSWORD_FILE",
    ///         fileIO: app.fileio,
    ///         on: app.eventLoopGroup.next()
    ///     ).wait()
    ///
    /// ````
    ///
    /// - Important: Do _not_ use `.wait()` if loading a secret at any time after the app has booted, such as while
    ///   handling a `Request`. Chain the result as you would any other future instead.
    @available(*, deprecated, message: "Use an async version of secret instead")
    public static func secret(key: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) -> EventLoopFuture<String?> {
        guard let filePath = self.get(key) else {
            return eventLoop.future(nil)
        }
        return self.secret(path: filePath, fileIO: fileIO, on: eventLoop)
    }


    /// Load the content of a file at a given path as a secret.
    ///
    /// - Parameters:
    ///   - path: Path to the file containing the secret
    ///   - fileIO: `NonBlockingFileIO` handler provided by NIO
    ///   - eventLoop: `EventLoop` for NIO to use for working with the file
    ///
    /// - Returns:
    ///   - On success, a succeeded future with the loaded content of the file.
    ///   - On any kind of error, a succeeded future with a value of `nil`. It is not currently possible to get error details.
    @available(*, deprecated, message: "Use an async version of secret instead")
    public static func secret(path: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) -> EventLoopFuture<String?> {
        return fileIO
            .openFile(path: path, eventLoop: eventLoop)
            .flatMap { handle, region in
                let handleWrapper = NIOLoopBound(handle, eventLoop: eventLoop)
                return fileIO
                    .read(fileRegion: region, allocator: .init(), eventLoop: eventLoop)
                    .always { _ in try? handleWrapper.value.close() }
            }
            .map { buffer -> String in
                return buffer
                    .getString(at: buffer.readerIndex, length: buffer.readableBytes)!
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .recover { _ -> String? in
                nil
            }
    }

    /// Load the content of a file at a given path as a secret.
    ///
    /// - Parameters:
    ///   - path: Path to the file containing the secret
    ///
    /// - Returns:
    ///   - On success, the loaded content of the file.
    ///   - On any kind of error `nil`. It is not currently possible to get error details.
    public static func secret(path: String) async throws -> String? {
        do {
            return try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
                let buffer = try await handle.readToEnd(maximumSizeAllowed: .megabytes(32))
                return buffer
                    .getString(at: buffer.readerIndex, length: buffer.readableBytes)!
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            return nil
        }
    }

    /// Reads a file's content for a secret. The secret key is the name of the environment variable that is expected to
    /// specify the path of the file containing the secret.
    ///
    /// - Parameters:
    ///   - key: The environment variable name
    ///
    /// Example usage:
    ///
    /// ````
    /// func configure(_ app: Application) async throws {
    ///     // ...
    ///
    ///     let databasePassword = try await Environment.secret(key: "DATABASE_PASSWORD_FILE")
    ///
    /// ````
    public static func secret(key: String) async throws -> String? {
        guard let filePath = self.get(key) else {
            return nil
        }
        return try await self.secret(path: filePath)
    }
}
