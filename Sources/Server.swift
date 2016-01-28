//
// Based on HttpServer from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

import Foundation

public class Server: SocketServer {
    
    public static let VERSION = "0.1.4"
    
    private let router = Router()
    public var bootstrap = Bootstrap()

    public override init() {

    }

    func parseRoutes() {
        for route in Route.routes {
            self.router.register(route.method.rawValue, path: route.path) { request in 

                //grab request params
                let routePaths = route.path.split("?")[0].split("/")
                for (index, path) in routePaths.enumerate() {
                    if path.hasPrefix(":") {
                        let requestPaths = request.path.split("/")
                        if requestPaths.count > index {
                            var trimPath = path
                            trimPath.removeAtIndex(path.startIndex)
                            request.parameters[trimPath] = requestPaths[index]
                        }
                    }
                }

                self.bootstrap.request(request)

                let response: Response
                do {
                    response = try route.closure(request: request).response()
                } catch View.Error.InvalidPath {
                    response = Response(status: .NotFound, text: "View not found")
                } catch {
                    response = Response(error: "Server Error: \(error)")
                }
                self.bootstrap.respond(request, response: response)

                return response
            }
        }
    }

    public func run(port inPort: Int = 80) {
        self.parseRoutes()

        var port = inPort

        if Process.arguments.count >= 2 {
            let secondArg = Process.arguments[1]
            if secondArg.hasPrefix("--port=") {
                let portString = secondArg.split("=")[1]
                if let portInt = Int(portString) {
                    port = portInt
                }
            }
        }

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