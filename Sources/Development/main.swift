import Core
import Dispatch
import Fluent
import Foundation
import HTTP
import Leaf
import Routing
import Service
import Vapor

extension View: ContentEncodable, ResponseRepresentable {
    public func encodeContent(to message: Message) throws {
        message.mediaType = .html
        message.body = Body(data)
    }
}


var services = Services.default()
try services.register(Leaf.Provider())

services.register { container in
    MiddlewareConfig([
        ErrorMiddleware.self
    ])
}

let app = Application(services: services)

let async = try app.make(AsyncRouter.self)
let sync = try app.make(SyncRouter.self)

let user = User(name: "Vapor", age: 3);
async.on(.get, to: "hello") { req in
    return Future<User>(user)
}

let hello = try Response(body: "Hello, world!")
sync.on(.get, to: "plaintext") { req in
    return hello
}

let view = try app.make(ViewRenderer.self)
async.on(.get, to: "leaf") { req -> Future<View> in
    user.child = User(name: "Leaf", age: 1)
    let promise = Promise(User.self)
    user.futureChild = promise.future

    try req.requireWorker().queue.asyncAfter(deadline: .now() + 2) {
        let user = User(name: "unborn", age: -1)
        promise.complete(user)
    }
    
    return try view.make("/Users/tanner/Desktop/hello", context: user, for: req)
}

extension String: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        let data = self.data(using: .utf8)!
        return Response(status: .ok, headers: ["Content-Type": "text/plain"], body: Body(data))
    }
}

import SQLite

extension Worker {
    func connectionPool(for database: Database) -> ConnectionPool {
        if let existing = extend["vapor:connection-pool"] as? ConnectionPool {
            return existing
        } else {
            let new = database.makeConnectionPool(max: 2, on: queue)
            extend["vapor:connection-pool"] = new
            return new
        }
    }
}

let database = SQLite.Database(path: "/tmp/db.sqlite")

async.on(.get, to: "sqlite") { req -> Future<String> in
    let promise = Promise(String.self)
    
    let pool = try req.requireWorker()
        .connectionPool(for: database)

    pool.requestConnection().then { connection in
        do {
            try connection.query("select sqlite_version();").all().then { row in
                let version = row[0]["sqlite_version()"]?.text ?? "no version"
                promise.complete(version)
                pool.releaseConnection(connection)
            }.catch { error in
                promise.fail(error)
                pool.releaseConnection(connection)
            }
        } catch {
            promise.fail(error)
            pool.releaseConnection(connection)
        }
    }.catch { error in
        promise.fail(error)
    }

    return promise.future
}

print("Starting server...")
try app.run()

