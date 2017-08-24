import Core
import HTTP
import Routing
import Service
import Vapor

var services = Services.default()

services.register { container in
    MiddlewareConfig([])
}

let app = Application(services: services)

let async = try app.make(AsyncRouter.self)
let sync = try app.make(SyncRouter.self)

async.on(.get, to: "hello") { req in
    let promise = Promise(ResponseRepresentable.self)
    let user = User(name: "Vapor", age: 3)
    promise.complete(user)
    return promise.future
}

let hello = try Response(body: "Hello, world!")
let fut = Future(hello as ResponseRepresentable)
sync.on(.get, to: "plaintext") { req in
    return hello
}

print("Starting server...")
try app.run()
