import AsyncKit
import NIOCore
import _NIOFileSystem
import NIOPosix

extension Environment {
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
    ///
    /// - Important: Do _not_ use `.wait()` if loading a secret at any time after the app has booted, such as while
    ///   handling a `Request`. Chain the result as you would any other future instead.
    public static func secret(key: String) async throws -> String? {
        guard let filePath = self.get(key) else {
            return nil
        }
        return try await self.secret(path: filePath)
    }
}
