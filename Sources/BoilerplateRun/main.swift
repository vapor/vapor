import Boilerplate
import Service
import Vapor

let config = Config.default()
let env = Environment.detect()
let services = Services.default()

Boilerplate.configure(config, env, services)

let app = try Application(
    config: config,
    environment: env,
    services: services
)

Boilerplate.boot(app)

try app.run()

