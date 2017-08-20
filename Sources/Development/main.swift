import HTTP
import Vapor

let app = Application()

let router = try app.make(Router.self)
router.get("hello") { req, res in
    let user = User(name: "Vapor", age: 3)
    try res.write(user)
}

let hello = try Response(body: "Hello, world!")
router.get("plaintext") { req, res in
    res.write(hello)
}

print("Starting server...")
try app.run()
