import Async
import Bits
import COperatingSystem
//import HTTP
import Dispatch
import Foundation

/// Services files from the public folder.
public final class FileMiddleware: Middleware, Service {
    /// The public directory.
    /// note: does _not_ end with a slash
    let publicDirectory: String

    public var webTypes = [MediaType]()

    /// Creates a new filemiddleware.
    public init(publicDirectory: String) {
        self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
    }

    /// See Middleware.respond.
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        var path = req.http.url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        guard !path.contains("../") else {
            throw Abort(.forbidden)
        }

        let filePath = self.publicDirectory + path

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir) else {
            return try next.respond(to: req)
        }

        guard !isDir.boolValue else {
            return try next.respond(to: req)
        }

        return try req.streamFile(at: filePath)
    }
}
