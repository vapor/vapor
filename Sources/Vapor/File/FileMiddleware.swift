import Foundation
import HTTP

public class FileMiddleware: Middleware {
    
    private var publicDir: String
    
    public init(publicDir: String) {
        // Remove last "/" from the publicDir if present, so we can directly append uri path from the request.
        self.publicDir  = publicDir.hasSuffix("/") ? String(publicDir.characters.dropLast()) : publicDir
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch Abort.notFound {
            // Check in file system
            let filePath = publicDir + request.uri.path

            let fileAttributes = FileManager.fileAtPath(filePath)

            guard fileAttributes.exists else {
                throw Abort.notFound
            }
            
            var headers: [HeaderKey: String] = [:]
            
            // Generate ETag value, "HEX value of last modified date" + "-" + "file size"
            let fileETag = String(format: "%x-%x", fileAttributes.status.st_mtimespec.tv_sec, fileAttributes.status.st_size)
            headers["ETag"] = fileETag
            
            // Check if file has been cached already and return NotModified response if the etags match
            if fileETag == request.headers["If-None-Match"] {
                return Response(status: .notModified, headers: headers, body: .data([]))
            }

            // File exists and was not cached, returning content of file.
            if let fileBody = try? FileManager.readBytesFromFile(filePath) {
                
                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaTypes[fileExtension]
                {
                    headers["Content-Type"] = type
                }

                return Response(status: .ok, headers: headers, body: .data(fileBody))
            } else {
                throw Abort.notFound
            }
        }
    }
}
