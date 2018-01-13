import Boilerplate
import Vapor

var config = Config.default()
var env = try Environment.detect()
var services = Services.default()

try Boilerplate.configure(&config, &env, &services)

let app = try Application(
    config: config,
    environment: env,
    services: services
)

try Boilerplate.boot(app)

try app.run()

