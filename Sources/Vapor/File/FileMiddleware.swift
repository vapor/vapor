import Foundation
import HTTP

/// Servers files from the supplied public directory
/// on not found errors.
public final class FileMiddleware: Middleware {
    
    private var publicDir: String
    private let loader = DataFile()

    public init(publicDir: String) {
        // Remove last "/" from the publicDir if present, so we can directly append uri path from the request.
        self.publicDir = publicDir.finished(with: "/")
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch let error as AbortError where error.status == .notFound {
            // Check in file system
            var path = request.uri.path
            guard !path.contains("../") else { throw HTTP.Status.forbidden }
            if path.hasPrefix("/") {
                path = String(path.characters.dropFirst())
            }
            let filePath = publicDir + path

            guard
                let attributes = try? Foundation.FileManager.default.attributesOfItem(atPath: filePath),
                let modifiedAt = attributes[.modificationDate] as? Date,
                let fileSize = attributes[.size] as? NSNumber
            else {
                throw Abort.notFound
            }

            var headers: [HeaderKey: String] = [:]
            
            // Generate ETag value, "HEX value of last modified date" + "-" + "file size"
            let fileETag = "\(modifiedAt.timeIntervalSince1970)-\(fileSize.intValue)"
            headers["ETag"] = fileETag

            // Check if file has been cached already and return NotModified response if the etags match
            if fileETag == request.headers["If-None-Match"] {
                return Response(status: .notModified, headers: headers, body: .data([]))
            }

            // Set Content-Type header based on the media type
            // Only set Content-Type if file not modified and returned above.
            if
                let fileExtension = filePath.components(separatedBy: ".").last,
                let type = Request.mediaTypes[fileExtension]
            {
                headers["Content-Type"] = type
            }

            // File exists and was not cached, returning content of file.
            if let fileBody = try? loader.read(at:filePath) {
                return Response(status: .ok, headers: headers, body: .data(fileBody))
            } else {
                print("unable to load path")
                throw Abort.notFound
            }
        }
    }
}
