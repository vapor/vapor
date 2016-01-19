//
//  HttpServer2.swift
//  Swifter
//
//  Created by Damian Kolakowski on 17/12/15.
//  Copyright © 2015 Damian Kołakowski. All rights reserved.
//

import Foundation

public class HttpServer: HttpServerIO {
    
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

    override func dispatch(method: String, path: String) -> ([String:String], HttpRequest -> HttpResponse) {
        if let result = router.route(method, path: path) {
            return result
        }
        return super.dispatch(method, path: path)
    }
    
}