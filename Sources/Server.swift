//
// Based on HttpServer from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

import Foundation

public class Server: SocketServer {
    
    public static let VERSION = "1.0.5"
    
    private let router = Router()
    public var bootstrap = Bootstrap()

    public override init() {

    }

    func parseRoutes() {
        for route in Route.routes {
            self.router.register(route.method.rawValue, path: route.path) { request in 
                self.bootstrap.request(request)

                let closureResult = route.closure(request: request)
                let response: Response

                if let html = closureResult as? String {
                    response = Response(status: .OK, html: html)
                } else if let view = closureResult as? View {
                    response = view.render()
                } else if let result = closureResult as? Response {
                    response = result
                } else if let object = closureResult as? AnyObject {
                    do {
                        response = try Response(status: .OK, jsonObject: object)    
                    } catch {
                        response = Response(error: "JSON serialization error: \(error)")
                    }
                } else {
                    response = Response(status: .OK, text: "")
                }

                self.bootstrap.respond(request, response: response)

                return response
            }
        }
    }

    public func run(port port: Int = 80) {
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
                        return Response(status: .OK, html: response)
                    }
                } catch {
                    //continue to not found
                }
            } else {
                if let fileBody = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return { _ in 
                        return Response(status: .OK, data: array, contentType: .Text)
                    }
                    
                }
            }
        }

        return super.dispatch(method, path: path)
    }
    
}