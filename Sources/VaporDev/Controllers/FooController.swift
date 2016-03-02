//
//  FooController.swift
//  Vapor
//
//  Created by James Richard on 3/1/16.
//

import Vapor

class FooController: Controller {
    required init() { }

    func foo(request: Request) throws -> ResponseConvertible {
        return "foo"
    }

    static var middleware: [Middleware.Type] {
        return [BarMiddleware.self]
    }
}

class BarMiddleware: Middleware {
    static func handle(handler: Request.Handler) -> Request.Handler {
        return { request in
            let originalResponse = try handler(request: request)
            let response = Response(status: originalResponse.status, data: originalResponse.data + " bar".utf8.map({ $0 as UInt8 }), contentType: originalResponse.contentType)
            return response
        }
    }
}
