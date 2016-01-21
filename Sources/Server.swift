import Foundation

public class Server: SocketServer {
    
    public static let VERSION = "1.0.4"
    
    private let router = Router()

    public override init() {

    }

    func parseRoutes() {
        for route in Route.routes {
            self.router.register(route.method.rawValue, path: route.path) { request in 
                let response = route.closure(request: request)

                if let html = response as? String {
                    return Response(statusCode: 200, html: html)
                } else if let view = response as? View {
                    return view.render()
                } else if let response = response as? Response {
                    return response
                } else {
                    do {
                        return try Response(statusCode: 200, jsonObject: response)    
                    } catch {
                        return Response(error: "JSON serialization error: \(error)")
                    }
                }
            }
        }
    }

    public func run(port: Int = 80) {
        self.parseRoutes()

        do {
            try self.start(port)

            print("Server has started on port \(port)")

            self.loop()
        } catch {
            print("Server start error: \(error)")
        }
    }

    override func dispatch(method: Request.Method, path: String) -> (Request -> Response) {
        //check in routes
        if let result = router.route(method, path: path) {
            return result
        }

        //check in file system
        let filePath = "Public" + path
        let fileManager = NSFileManager.defaultManager()
        var isDir: ObjCBool = false
        if fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) {
            if isDir {
                do {
                    let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                    var response = "<h3>\(filePath)</h3></br><table>"
                    response += files.map({ "<tr><td><a href=\"\(path)/\($0)\">\($0)</a></td></tr>"}).joinWithSeparator("")
                    response += "</table>"

                    return { _ in 
                        return Response(statusCode: 200, html: response)
                    }
                } catch {
                    //continue to not found
                }
            } else {
                if let fileBody = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return { _ in 
                        return Response(statusCode: 200, data: array, contentType: .Text)
                    }
                    
                }
            }
        }

        return super.dispatch(method, path: path)
    }
    
}