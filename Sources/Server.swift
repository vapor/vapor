import Foundation

#if os(Linux)
    import Glibc
#endif

public class Server: HttpServerIO {
    
    public static let VERSION = "1.0.0"
    
    private let router = HttpRouter()

    public override init() {

    }

    func parseRoutes() {
        for route in Route.routes {
            self.router.register(route.method.rawValue, path: route.path) { request in 
                let response = route.closure(request: request)

                if let response = response as? String {
                    return .OK(.Html(response))
                } else if let view = response as? View {
                    return view.render()
                } else {
                    return .OK(.Json(response))
                }
            }
        }
    }

    public func run(port raw_port: Int = 80) {
        self.parseRoutes()

        do {
            let port: in_port_t = UInt16(raw_port)
            try self.start(port)
            print("Server has started on port \(port)")

            #if os(Linux)
                while true {
                    sleep(1)
                }
            #else
                NSRunLoop.mainRunLoop().run()
            #endif
            
        } catch {
            print("Server start error: \(error)")
        }
    }

    override func dispatch(method: Method, path: String) -> ([String:String], Request -> HttpResponse) {
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

                    return ([:], { _ in 
                        return HttpResponse.OK(.Html(response))
                    })
                } catch {
                    //continue to not found
                }
            } else {
                if let fileBody = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return ([:], { _ in 
                        return HttpResponse.RAW(200, "OK", nil, { $0.write(array) })
                    })
                    
                }
            }
        }

        return super.dispatch(method, path: path)
    }
    
}