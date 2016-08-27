import HTTP
import Middleware

public class FileMiddleware: Middleware {
    public var workDir: String
    public init(workDir: String) {
        self.workDir = workDir
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch Abort.notFound {
            // Check in file system
            let filePath = self.workDir + "Public" + request.uri.path

            guard FileManager.fileAtPath(filePath).exists else {
                throw Abort.notFound
            }

            // File exists
            if let fileBody = try? FileManager.readBytesFromFile(filePath) {
                var headers: [HeaderKey: String] = [:]

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
