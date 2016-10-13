import Foundation
import HTTP

public final class FileMiddleware: Middleware {
    
    private var publicDir: String
    private let loader = DataFile()

    @available(*, deprecated: 1.2, message: "This has been renamed to publicDir: and now represents the absolute path. Use `workDir.finished(\"/\") + \"Public/\"` to reproduce existing behavior.")
    public init(workDir: String) {
        self.publicDir = workDir.finished(with: "/") + "Public/"
    }

    public init(publicDir: String) {
        // Remove last "/" from the publicDir if present, so we can directly append uri path from the request.
        self.publicDir = publicDir.finished(with: "/")
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch Abort.notFound {
            // Check in file system
            var path = request.uri.path
            if path.hasPrefix("/") {
                path = String(path.characters.dropFirst())
            }
            let filePath = publicDir + path

            guard let attributes = try? Foundation.FileManager.default.attributesOfItem(atPath: filePath) else {
                print("Missing attributes")
                throw Abort.notFound
            }
            print("Got attributes")
            print("Attributes: \(attributes)")

            guard let _modifiedAt = attributes[.modificationDate] as? Date else {
                print("Missing modifiedAt")
                throw Abort.notFound
            }
            print("Got modified at")
            print("ModifiedAtType: \(type(of: _modifiedAt))")
            print("Will print date")
            print("ModifiedAt: \(_modifiedAt.timeIntervalSince1970)")
            print("Did print date")

            guard let _fileSize = attributes[.size] else {
                print("No file size")
                throw Abort.notFound
            }
            print("FileSize: \(_fileSize) Type: \(type(of: _fileSize))")
//
//            guard let attributes = _attributes,
//                let modifiedAt = attributes[.modificationDate] as? NSDate,
//                let fileSize = attributes[.size] as? Int
//                else {
//                    throw Abort.notFound
//                }

            let modifiedAt = _modifiedAt // as? Date
            guard
                let fileSize = _fileSize as? NSNumber
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

            // File exists and was not cached, returning content of file.
            if let fileBody = try? loader.load(path:filePath) {
                
                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaTypes[fileExtension]
                {
                    headers["Content-Type"] = type
                }

                return Response(status: .ok, headers: headers, body: .data(fileBody))
            } else {
                print("unable to load path")
                throw Abort.notFound
            }
        }
    }
}
