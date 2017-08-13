import Crypto
import HTTP
import Vapor

// MARK: Config

var config = Config.default()
config.prefer(BCryptHasher.self, for: Hasher.self)

// MARK: Services

var services = Services.default()

let serverConfig = ServerConfig(
    hostname: "localhost",
    port: 8090,
    securityLayer: .none
)
services.register(serverConfig)
services.register(BCryptHasher.self)

let bcryptConfig = BCryptHasherConfig(cost: 6)
services.register(bcryptConfig)

// MARK: Application

let app = try Application(
    config: config,
    services: services
)

// MARK: Routes

app.get("hello") { req in
    return "Hello, world!"
}

app.get("hash") { req in
    let hasher = try app.make(Hasher.self)
    return try hasher.make("vapor").makeString()
}

app.get("user") { req in
    return User(name: "Vapor", age: 2)
}

app.post("user") { req in
    let user = try req.content(User.self)
    return user.name
}

// MARK: Run

try app.run()

